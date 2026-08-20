-- ── Shooting Bridge (opaque integration socket) — client ──
-- An opaque extension surface for a companion combat resource. malisling never names it and
-- ships ZERO of its logic: without a registered bridge every hook is inert and malisling runs
-- standalone, so the public source reveals only empty dispatch points.
--
-- Separate resources are separate Lua VMs, so the companion registers itself once via
-- exports.mbt_malisling:RegisterShootingBridge(name) and malisling calls back pcall-guarded.

local bridgeResource          -- resource name registered by the companion (or nil)
local currentWeapon           -- ox_inventory:currentWeapon payload (has .metadata)

AddEventHandler('ox_inventory:currentWeapon', function(data)
    currentWeapon = data
end)

--- Call a hook export on the registered companion resource, guarded so a faulty or missing hook can never break malisling; returns the hook's result, or nil.
---@param hook string
---@return any
local function callBridge(hook, ...)
    if not bridgeResource then return nil end
    if GetResourceState(bridgeResource) ~= 'started' then return nil end
    local proxy = exports[bridgeResource]
    local packed = table.pack(...)
    local ok, ret = pcall(function()
        local fn = proxy[hook]
        if type(fn) ~= 'function' then return nil end
        return fn(proxy, table.unpack(packed, 1, packed.n))
    end)
    if not ok then
        Utils.mbtWarn('ShootingBridge hook errored:', hook, ret)
        return nil
    end
    return ret
end

-- ── Local dispatcher: other malisling modules call these ─────────────────────
MBT.ShootingBridge = {
    --- A round was fired with the held weapon. Fire-and-forget.
    ---@param weaponData table  ox currentWeapon payload (.name, .slot, .metadata)
    OnWeaponFired = function(weaponData)
        callBridge('OnWeaponFired', weaponData)
    end,

    --- Let the companion decide whether the weapon jams on this shot: true → force jam · false → force no jam · nil → no opinion (falls back to malisling's base durability-chance logic).
    ---@param weaponHash number
    ---@param conditionTier integer?  1..5
    ---@return boolean?
    OnJamCheck = function(weaponHash, conditionTier)
        return callBridge('OnJamCheck', weaponHash, conditionTier)
    end,

    --- Ask the companion for a draw-speed multiplier (Quick Draw skill) for the weapon about to be drawn.
    ---@param weaponType string  malisling prop type (side/back/...)
    ---@param weaponHash number
    ---@return number?  <1.0 = faster · nil = no change (companion has no opinion)
    OnDrawSpeedRequest = function(weaponType, weaponHash)
        local raw  = callBridge('OnDrawSpeedRequest', weaponType, weaponHash)
        local mult = raw
        if type(mult) ~= 'number' then mult = nil
        else
            -- Clamped defensively to 0.3-1.0 so a buggy or malicious companion can never warp
            -- draw timing to near-zero or beyond normal.
            if mult < 0.3 then mult = 0.3 end
            if mult > 1.0 then mult = 1.0 end
        end
        Utils.mbtDebugger('ShootingBridge OnDrawSpeedRequest ~ weaponType:', weaponType, '| raw:', raw, '| clamped:', mult)
        return mult
    end,

    ---@param weaponType string  malisling prop type (side/back/...)
    OnHolster = function(weaponType)
        callBridge('OnHolster', weaponType)
    end,

    ---@param weaponType string
    OnUnholster = function(weaponType)
        callBridge('OnUnholster', weaponType)
    end,

    --- Weapon inspect: ask the companion for extra data rows to APPEND to malisling's own inspect card (proficiency/familiarity/heat/jam risk...) — one themed, anchored card renders everything, no separate overlay. nil = no extra rows.
    ---@param baseData table  {name, serial, condition, conditionTone, ammo, custody?}
    ---@return table[]?  {label, value, tone?}[]
    OnInspectRows = function(baseData)
        local rows = callBridge('OnInspectRows', baseData)
        return type(rows) == 'table' and rows or nil
    end,

    --- True when a companion has registered and is running, without exposing its logic.
    ---@return boolean
    IsConnected = function()
        return bridgeResource ~= nil and GetResourceState(bridgeResource) == 'started'
    end,
}

-- Holster / unholster: forward malisling's existing internal events (no edits to
-- core needed). The companion gets the prop type; it can resolve the hash itself.
AddEventHandler('mbt_malisling:onHolster',   function(weaponType) MBT.ShootingBridge.OnHolster(weaponType) end)
AddEventHandler('mbt_malisling:onUnholster', function(weaponType) MBT.ShootingBridge.OnUnholster(weaponType) end)

-- Fired-shot detection. malisling OWNS CEventGunShotWhizzedBy; companion subscribes
-- via the bridge, not the event. Decoupled from jamming so OnWeaponFired fires even
-- when jamming is off. IsPedShooting guards against nearby players' shots.
AddEventHandler('CEventGunShotWhizzedBy', function()
    if not bridgeResource then return end
    if not currentWeapon then return end
    if not IsPedShooting(cache.ped) then return end
    MBT.ShootingBridge.OnWeaponFired(currentWeapon)
end)

-- ── Registration export (the companion calls this once at start) ─────────────
exports('RegisterShootingBridge', function(resourceName)
    if type(resourceName) ~= 'string' or resourceName == '' then return false end
    bridgeResource = resourceName
    Utils.mbtDebugger('Shooting bridge registered by', resourceName)
    return true
end)

-- ── Data exports malisling exposes to the companion ──────────────────────────

--- Companion-driven clearing animation — loops the configured jam-clear anim on the local ped while active. No-op if the Jamming feature block (and its anim) isn't present.
---@param active boolean
local _clearingAnim = false
exports('PlayClearingAnim', function(active)
    if not active then _clearingAnim = false return end
    if _clearingAnim then return end
    -- The companion's malfunction pipeline suppresses malisling's base jam (OnJamCheck=false)
    -- and thus its animation — this export gives the hands-on gesture back. Networked
    -- implicitly: a task anim on the owned player ped replicates to nearby players.
    local a = MBT.Jamming and MBT.Jamming.Animation
    if not a or not a.Dict or not a.Anim then return end
    _clearingAnim = true
    CreateThread(function()
        lib.requestAnimDict(a.Dict)
        while _clearingAnim do
            if not IsEntityPlayingAnim(cache.ped, a.Dict, a.Anim, 3) then
                -- Flag 48 = upper-body + secondary, so the player keeps moving/looking.
                TaskPlayAnim(cache.ped, a.Dict, a.Anim, 2.0, 2.0, 750, 48, 0.0, false, false, false)
            end
            Wait(500)
        end
        ClearPedSecondaryTask(cache.ped)
        RemoveAnimDict(a.Dict)
    end)
end)

--- Serial of the held weapon (from ox_inventory metadata), or nil.
---@return string?
exports('GetWeaponSerial', function()
    return currentWeapon and currentWeapon.metadata and currentWeapon.metadata.serial or nil
end)

--- Condition tier 1-5 (5 = pristine) for a serial; only resolves the HELD weapon (the combat case), so pass no serial or the held weapon's serial. Arbitrary-serial lookup is a server concern.
---@param serial string?
---@return integer?
exports('GetWeaponCondition', function(serial)
    if not currentWeapon or not currentWeapon.metadata then return nil end
    if serial and serial ~= currentWeapon.metadata.serial then return nil end
    return Utils.durabilityToTier(currentWeapon.metadata.durability)
end)
