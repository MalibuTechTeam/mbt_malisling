-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Safety Toggle
--
-- Toggle the safety on the held firearm. With safety ON the weapon cannot fire
-- (DisablePlayerFiring every frame) and a SAFE/FIRE indicator shows the state; a
-- metallic click plays on toggle. State is tracked per weapon (by serial) so each
-- gun remembers its own safety. Purely RP — combat logic lives in a companion combat
-- resource, which reads the state via the 'mbt_weaponSafety' statebag or IsWeaponSafetyOn().
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the feature block exists; Enabled is checked at use time so the admin
-- menu can toggle it live (cfg is the live MBT.Safety table).
if not MBT.Safety then return end

local cfg = MBT.Safety

local currentWeapon          -- ox_inventory:currentWeapon payload
local safetyBySerial = {}    -- [serial] = true (PerWeapon mode)
local globalSafety   = cfg.DefaultOn or false  -- single-flag mode
local hudShown       = false

AddEventHandler('ox_inventory:currentWeapon', function(data)
    currentWeapon = data
end)

--- True for a real firearm in hand (not unarmed, not melee/thrown).
local function heldFirearm()
    local has, hash = GetCurrentPedWeapon(cache.ped, true)
    if not has or hash == `WEAPON_UNARMED` then return false, nil end
    local group = GetWeapontypeGroup(hash)
    if group == `GROUP_MELEE` or group == `GROUP_THROWN` or group == `GROUP_UNARMED` then
        return false, nil
    end
    return true, hash
end

--- Stable key for the held weapon's safety state.
local function weaponKey()
    if cfg.PerWeapon then
        return currentWeapon and currentWeapon.metadata and currentWeapon.metadata.serial
            or (currentWeapon and currentWeapon.name)
    end
    return '__global__'
end

local function isSafetyOn()
    if not cfg.PerWeapon then return globalSafety end
    local key = weaponKey()
    if key == nil then return false end
    if safetyBySerial[key] == nil then return cfg.DefaultOn or false end
    return safetyBySerial[key]
end

local function setSafety(on)
    if cfg.PerWeapon then
        local key = weaponKey()
        if key ~= nil then safetyBySerial[key] = on end
    else
        globalSafety = on
    end
    -- Expose to a companion combat resource / other resources.
    LocalPlayer.state:set('mbt_weaponSafety', on, true)
end

local function playClick()
    local s = cfg.Sound
    if not s or not s.Enabled then return end
    if s.Mode == 'nui' then
        SendNUIMessage({ action = 'playHolsterSound', data = { file = s.Nui.File, volume = s.Nui.Volume or 0.5 } })
    else
        PlaySoundFrontend(-1, s.Native.Name, s.Native.Set, false)
    end
end

-- Combined "weapon status" pill = Safety segment (this module) + Condition pips
-- (MBT.ConditionHUD). One NUI element; each segment is nil when its feature is
-- off. Sent only on change to avoid flooding the NUI from the tight safety loop.
local lastSafetySent, lastCondSent

--- Condition tier (1-5) for the held weapon, or nil when the Condition HUD is off.
local function condTier()
    if not (MBT.ConditionHUD and MBT.ConditionHUD.Enabled) then return nil end
    local md = currentWeapon and currentWeapon.metadata
    return Utils.durabilityToTier(md and md.durability)
end

--- Push the combined pill; `safetyState` = 'safe'|'fire'|nil (nil hides the safety segment), condition segment resolved here from config + durability.
local function sendStatus(safetyState)
    local cond = condTier()
    if safetyState == nil and cond == nil then
        if hudShown then SendNUIMessage({ action = 'hideWeaponStatus', data = {} }); hudShown = false end
        lastSafetySent, lastCondSent = nil, nil
        return
    end
    if hudShown and safetyState == lastSafetySent and cond == lastCondSent then return end
    lastSafetySent, lastCondSent, hudShown = safetyState, cond, true
    SendNUIMessage({ action = 'showWeaponStatus', data = {
        safety = safetyState, condition = cond, locale = buildNuiLocale(),
    } })
end

local function hideStatus()
    if hudShown then SendNUIMessage({ action = 'hideWeaponStatus', data = {} }); hudShown = false end
    lastSafetySent, lastCondSent = nil, nil
end

--- Short "work the safety" gesture: a truncated, slowed pistol-reload partial; TaskPlayAnim only, never touches ammo, cosmetic and fire-and-forget.
local function playToggleAnim()
    local a = cfg.Animation
    if not a or not a.Enabled then return end
    if not DoesAnimDictExist(a.Dict) then return end
    lib.requestAnimDict(a.Dict)
    TaskPlayAnim(cache.ped, a.Dict, a.Anim, 8.0, -8.0, a.Dur or 750, a.Flag or 48, 0.0, false, false, false)
    if a.Speed then SetEntityAnimSpeed(cache.ped, a.Dict, a.Anim, a.Speed) end
end

local function toggle()
    if not cfg.Enabled then return end
    local ok = heldFirearm()
    if not ok then
        MBT.NotifyLabel('safety_no_weapon')
        return
    end
    local newState = not isSafetyOn()
    setSafety(newState)
    playClick()
    playToggleAnim()
    sendStatus(cfg.HudIndicator and (newState and 'safe' or 'fire') or nil)
end

RegisterCommand(cfg.Command, toggle, false)
RegisterKeyMapping(cfg.Command, '[MBT] Toggle weapon safety', 'keyboard', cfg.Key)

-- Enforcement + combined HUD. Enforcement is independent of the HUD toggles; the
-- pill shows whenever a firearm is in hand and Safety.HudIndicator OR ConditionHUD
-- is on. Tight loop (Wait 0) only while the safety is actively blocking fire.
CreateThread(function()
    while true do
        local sleep = 300
        if heldFirearm() then
            local safetyOn = cfg.Enabled and isSafetyOn()
            if safetyOn then
                -- Block firing but still allow aiming (safety on, weapon won't fire).
                DisablePlayerFiring(cache.playerId, true)
                DisableControlAction(0, 24, true)   -- INPUT_ATTACK
                DisableControlAction(0, 257, true)  -- INPUT_ATTACK2
                -- Attentional-blindness cue: pulse the indicator the moment
                -- the player tries to fire on safe, so they don't have to be staring
                -- at the top-centre pill to notice.
                if IsDisabledControlJustPressed(0, 24) then
                    SendNUIMessage({ action = 'weaponStatusPulse', data = {} })
                end
                sleep = 0
            end
            local safetyState = (cfg.Enabled and cfg.HudIndicator)
                and (isSafetyOn() and 'safe' or 'fire') or nil
            sendStatus(safetyState)
        else
            hideStatus()
        end
        Wait(sleep)
    end
end)

exports('IsWeaponSafetyOn', function() return isSafetyOn() end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and hudShown then
        SendNUIMessage({ action = 'hideWeaponStatus', data = {} })
    end
end)
