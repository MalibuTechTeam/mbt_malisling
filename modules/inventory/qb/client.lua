if GetResourceState('qb-inventory') ~= 'started' or GetResourceState('ox_inventory') == 'started' then return end

-- QBCore set up by bridge/qb/client.lua (loads first: bridge/ < inventory/).

---Global inventory interface — drop-in replacement for exports['ox_inventory'] client-side, with ox_inventory events emulated via the polling threads below.
Inventory = {}

-- ── Attachment translation (qb → MBT/ox) ──
-- qb stores info.attachments as { { component = <GTA hash/name> }, ... }; the slung-prop
-- renderer wants metadata.components = { '<ox key>', ... } into MBT.WeaponsInfo.Components.
-- Reverse-map qb's GTA components back to those keys so accessories show on qb too.
local function qbAttachmentsToComponents(attachments)
    if type(attachments) ~= 'table' or not next(attachments) then return nil end
    local comps = MBT.WeaponsInfo and MBT.WeaponsInfo.Components
    if not comps then return nil end
    local out = {}
    for _, att in pairs(attachments) do
        local c = type(att) == 'table' and att.component or att
        if c then
            local hash = type(c) == 'string' and joaat(c) or c
            for key, def in pairs(comps) do
                local list = def.client and def.client.component
                if list then
                    for _, gh in ipairs(list) do
                        if gh == hash then out[#out + 1] = key; break end
                    end
                end
            end
        end
    end
    return out[1] and out or nil
end

-- ── Normalisation helper ──
-- Maps qb-inventory item fields to the ox_inventory-compatible field names.
local function normalizeItem(item)
    if not item then return nil end
    local info = item.info or {}
    local metadata = {}
    for k, v in pairs(info) do metadata[k] = v end
    -- qb uses .quality (0-100) for durability and .serie for serial
    metadata.durability = metadata.durability or info.quality
    metadata.serial     = metadata.serial     or info.serie
    metadata.components = metadata.components or qbAttachmentsToComponents(info.attachments)
    -- qb weapon names are lowercase → uppercase to match MBT/WeaponsInfo/ox; keep raw for qb-side.
    local rawName = item.name
    local name = rawName
    if type(rawName) == 'string' and rawName:sub(1, 7):upper() == 'WEAPON_' then
        name = rawName:upper()
    end
    return {
        name     = name,
        rawName  = rawName,
        slot     = item.slot,
        count    = item.amount,
        metadata = metadata,
        label    = item.label or item.name,
    }
end

-- Canonicalize a name (weapon names → UPPER) so searches match regardless of case:
-- callers pass canonical WEAPON_ names but qb's raw item.name is lowercase.
local function canonName(n)
    if type(n) == 'string' and n:sub(1, 7):upper() == 'WEAPON_' then return n:upper() end
    return n
end

---Mimics ox_inventory:Search('slots', itemName | {itemNames})
function Inventory:Search(_, itemName)
    local items  = QBCore.Functions.GetPlayerData().items or {}
    local result = {}

    if type(itemName) == 'string' then
        local want = canonName(itemName)
        for _, item in pairs(items) do
            if canonName(item.name) == want then
                result[#result + 1] = normalizeItem(item)
            end
        end

    elseif type(itemName) == 'table' then
        local nameSet = {}
        for _, n in pairs(itemName) do nameSet[canonName(n)] = true end
        for _, item in pairs(items) do
            local cn = canonName(item.name)
            if nameSet[cn] then
                result[cn] = result[cn] or {}
                result[cn][#result[cn] + 1] = normalizeItem(item)
            end
        end
    end

    return result
end

AddEventHandler('ox_inventory:disarm', function()
    RemoveAllPedWeapons(cache.ped, true)
end)

-- ── Holster key mappings ──
-- Mirrors the RegisterKeyMapping appendMalisling() injects for ox_inventory.
-- holsterState: nil = idle, true = waiting for input, 'confirmed' | 'cancelled' = result
local holsterState = nil

RegisterCommand('confirmHolster', function()
    if holsterState == true then holsterState = 'confirmed' end
end, false)

RegisterCommand('cancelHolster', function()
    if holsterState == true then holsterState = 'cancelled' end
end, false)

RegisterKeyMapping('confirmHolster',
    MBT.HolsterControls["Confirm"]["Label"],
    MBT.HolsterControls["Confirm"]["Input"],
    MBT.HolsterControls["Confirm"]["Key"])

RegisterKeyMapping('cancelHolster',
    MBT.HolsterControls["Cancel"]["Label"],
    MBT.HolsterControls["Cancel"]["Input"],
    MBT.HolsterControls["Cancel"]["Key"])

-- ── Helpers ──

local function findWeaponDataByHash(weaponHash)
    for _, item in pairs(QBCore.Functions.GetPlayerData().items or {}) do
        if joaat(item.name) == weaponHash then
            local normalized = normalizeItem(item)
            normalized.hash  = weaponHash
            return normalized
        end
    end
    return nil
end

--- 'native' (default) → qb-weapons owns the sidearm draw animation, no malisling
--- confirm modal on qb. 'malisling' → ox-parity modal + our anim (requires the
--- sidearms removed from qb-weapons Config.WeapDraw.weapons; see startup warning).
local function qbSidearmDrawMode()
    return (MBT.QBWeapons and MBT.QBWeapons.SidearmDrawMode) or 'native'
end

local function needsHolsterPrompt(weaponData)
    if not weaponData then return false end
    -- Use our live config, not the replicated convar: SetConvarReplicated doesn't reliably
    -- reach the client on every qb server, which silently killed the side-weapon prompt
    -- (pistol drew then bounced back). MBT.EnableSling is always set + honours dashboard toggles.
    if not MBT.EnableSling then return false end
    local wInfo = MBT.WeaponsInfo
        and MBT.WeaponsInfo["Weapons"]
        and MBT.WeaponsInfo["Weapons"][weaponData.name]
    if not (wInfo and wInfo.type == 'side') then return false end
    -- QB default lets qb-weapons own the pistol draw (no double-play/bounce);
    -- only take over in ox-parity mode.
    return qbSidearmDrawMode() == 'malisling'
end

-- Warn once if ox-parity mode is on while qb-weapons is running: qb-weapons will
-- otherwise double-play its stock draw animation over ours.
CreateThread(function()
    Wait(2000)
    if qbSidearmDrawMode() == 'malisling' and GetResourceState('qb-weapons') == 'started' then
        Utils.mbtWarn("QBWeapons.SidearmDrawMode = 'malisling': remove your sidearms from "
            .. "qb-weapons Config.WeapDraw.weapons, or qb-weapons will double-play the draw animation.")
    end
end)

-- ── Inventory snapshot polling ──
-- Emulates ox_inventory:itemCount / ox_inventory:updateInventory for core/client.lua.
local lastSnapshot = {}

CreateThread(function()
    while not MBT.WeaponsInfo do Wait(500) end

    while true do
        local currentSnapshot = {}

        for _, item in pairs(QBCore.Functions.GetPlayerData().items or {}) do
            if Utils.isWeapon(item.name) then
                -- Key by CANONICAL name (WEAPON_*): core handlers look up MBT.WeaponsInfo (uppercase-keyed).
                local nd = normalizeItem(item)
                currentSnapshot[nd.name] = nd
            end
        end

        -- Weapon removed → emulate ox_inventory:itemCount(name, 0)
        for name in pairs(lastSnapshot) do
            if not currentSnapshot[name] then
                TriggerEvent('ox_inventory:itemCount', name, 0)
            end
        end

        -- Weapon added → emulate ox_inventory:updateInventory({ [slot] = itemData })
        for name, data in pairs(currentSnapshot) do
            if not lastSnapshot[name] then
                TriggerEvent('ox_inventory:updateInventory', { [data.slot] = data })
            end
        end

        lastSnapshot = currentSnapshot
        Wait(1000)
    end
end)

-- ── currentWeapon detection ──
-- Emulates ox_inventory:currentWeapon by polling GetCurrentPedWeapon; on a direct
-- armed→armed switch the previous weapon is re-slung (core only re-slings on a clean holster).
-- REQUIRES qb-weapons' weapdraw (client/weapdraw.lua) DISABLED — it animates every swap over
-- 1–4s through UNARMED, which no real-time weapon-on-back tracker can follow (startup warning below).
-- For side weapons the holster confirm UI shows post-equip: RMB = keep in hand · BACKSPACE = sling.
local lastWeaponHash = `WEAPON_UNARMED`

--- Weapon type ('side'/'back'/…) from a canonical weapon name.
local function typeOf(name)
    return name and MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]
        and MBT.WeaponsInfo.Weapons[name].type or nil
end

--- Play a weapon type's holster gesture from MBT.PropInfo[type].HolsterAnim: dir 'in' = draw
--- (animIn), 'out' = put away (animOut). No-op if the draw animation is off or the type has no clip.
---@param weaponHash number?  the weapon being drawn (dir='in' only) — for the Quick Draw bridge hook
local function playHolsterAnim(wtype, dir, weaponHash)
    if not (MBT.QBWeapons and MBT.QBWeapons.DrawAnimation) then return end
    local ha = wtype and MBT.PropInfo and MBT.PropInfo[wtype] and MBT.PropInfo[wtype].HolsterAnim
    if not ha or not ha.dict then return end
    local clip = (dir == 'out') and ha.animOut or ha.animIn
    local ms   = ((dir == 'out') and ha.sleepOut) or ha.sleep or 1000
    if not clip or clip == '0' or clip == 0 then return end
    -- Quick Draw (shooting bridge): the companion may speed up the draw-in gesture
    -- only — putting a weapon away isn't a skill check.
    if dir ~= 'out' and MBT.ShootingBridge and weaponHash then
        local mult = MBT.ShootingBridge.OnDrawSpeedRequest(wtype, weaponHash)
        if mult then ms = math.floor(ms * mult) end
    end
    lib.requestAnimDict(ha.dict)
    TaskPlayAnim(cache.ped, ha.dict, clip, 2.5, -4.0, ms, 48, 0.0, false, false, false)
    Wait(ms)
end

--- Equip shared by all transitions: fires currentWeapon(data), with the side-weapon holster prompt when qbSidearmDrawMode == 'malisling'.
local function doEquip(weaponData, weaponHash)
    if needsHolsterPrompt(weaponData) then
        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)   -- hide during prompt
        holsterState = true
        SendNUIMessage({ action = 'showHolster', data = {
            weaponLabel = weaponData.name:upper(),
            position    = MBT.UI and MBT.UI.Position or 'bottom-center',
            style       = MBT.Holster and MBT.Holster.Style or 'standard',
            confirm     = { label = MBT.HolsterControls["Confirm"]["Label"], display = 'RMB' },
            cancel      = { label = MBT.HolsterControls["Cancel"]["Label"],  display = 'BACKSPACE' },
            locale      = buildNuiLocale(),
        }})
        local isCine = (MBT.Holster and MBT.Holster.Style) == 'cinematic'
        while holsterState == true do
            if isCine then
                -- Cinematic anchors near the player (botz-style). qb hides the weapon
                -- during the prompt, so track the right-hand bone, not the weapon object.
                local pos = GetWorldPositionOfEntityBone(cache.ped, GetPedBoneIndex(cache.ped, 28422))
                local on, sx, sy = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z + 0.2)
                SendNUIMessage({ action = 'holster:anchor', data = on and { x = sx, y = sy } or { off = true } })
                Wait(0)
            else
                Wait(50)
            end
        end
        SendNUIMessage({ action = 'hideHolster' })
        if holsterState == 'confirmed' then
            -- Weapon is still hidden from the prompt: play the draw gesture, THEN bring it out —
            -- a coordinated draw, not a gesture over an already-out gun (matches the else branch).
            playHolsterAnim(typeOf(weaponData.name), 'in', weaponHash)
            SetCurrentPedWeapon(cache.ped, weaponHash, true)
            TriggerEvent('ox_inventory:currentWeapon', weaponData)
        else
            lastWeaponHash = `WEAPON_UNARMED`   -- cancelled: weapon stays on the sling
        end
        holsterState = nil
    else
        -- Coordinated draw: hide weapon, play draw gesture, then bring it out, so it reads as
        -- a real draw (not a gesture over an already-out gun). Poll is blocked during the Wait.
        local t  = typeOf(weaponData.name)
        local ha = t and MBT.PropInfo and MBT.PropInfo[t] and MBT.PropInfo[t].HolsterAnim
        if MBT.QBWeapons and MBT.QBWeapons.DrawAnimation
            and ha and ha.dict and ha.animIn and ha.animIn ~= '0' and ha.animIn ~= 0 then
            SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
            lib.requestAnimDict(ha.dict)
            local ms = ha.sleep or 1000
            -- Quick Draw (shooting bridge): companion may speed up the draw-in gesture.
            if MBT.ShootingBridge then
                local mult = MBT.ShootingBridge.OnDrawSpeedRequest(t, weaponHash)
                if mult then ms = math.floor(ms * mult) end
            end
            -- Softer blend-in (2.5) so the draw eases in. Gesture length per type via HolsterAnim.sleep.
            TaskPlayAnim(cache.ped, ha.dict, ha.animIn, 2.5, -4.0, ms, 48, 0.0, false, false, false)
            Wait(ms)
            SetCurrentPedWeapon(cache.ped, weaponHash, true)
        end
        TriggerEvent('ox_inventory:currentWeapon', weaponData)
    end
end

--- After a direct armed→armed switch, re-create the PREVIOUS weapon's slung prop (qb-weapons swaps without a stable UNARMED step, so core never re-slings it).
local function reslingPrevious(prevHash)
    if prevHash == `WEAPON_UNARMED` then return end
    local mine = playersToTrack[cache.serverId]
    local prevData = findWeaponDataByHash(prevHash)
    local prevType = prevData and MBT.WeaponsInfo.Weapons[prevData.name]
        and MBT.WeaponsInfo.Weapons[prevData.name].type
    if prevType and (not mine or not mine[prevType] or mine[prevType] == false) then
        prevData.type = prevType
        TriggerServerEvent('mbt_malisling:syncSling', { playerWeapons = { [prevType] = prevData } })
    end
end

--- Direct armed→armed switch: replay a real weapdraw sequence — HOLSTER the old weapon
--- then DRAW the new — instead of qb's instant swap. qb already drew the new weapon, so
--- hide it, replay the old put-away gesture, then draw the new via doEquip (poll blocked throughout).
local function doSwitch(prevHash, newData, newHash)
    local prevData = findWeaponDataByHash(prevHash)
    local prevType = typeOf(prevData and prevData.name)
    local pha = prevType and MBT.PropInfo and MBT.PropInfo[prevType]
        and MBT.PropInfo[prevType].HolsterAnim
    if MBT.QBWeapons and MBT.QBWeapons.DrawAnimation
        and pha and pha.dict and pha.animOut and pha.animOut ~= '0' and pha.animOut ~= 0 then
        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)   -- hide the new weapon qb just drew
        local ammo = (prevData and prevData.metadata and prevData.metadata.ammo) or 30
        GiveWeaponToPed(cache.ped, prevHash, ammo, false, true)  -- old weapon back for the holster gesture
        lib.requestAnimDict(pha.dict)
        TaskPlayAnim(cache.ped, pha.dict, pha.animOut, 2.5, -4.0, pha.sleepOut or 1000, 48, 0.0, false, false, false)
        Wait(pha.sleepOut or 1000)
        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)   -- put the old weapon away
    end
    doEquip(newData, newHash)
end

CreateThread(function()
    while not MBT.WeaponsInfo do Wait(500) end

    while true do
        if holsterState ~= nil then
            Wait(100)
        else
            local _, h = GetCurrentPedWeapon(cache.ped, 1)

            if h ~= lastWeaponHash then
                local prevHash = lastWeaponHash
                lastWeaponHash = h
                if h ~= `WEAPON_UNARMED` then
                    local wd = findWeaponDataByHash(h)
                    if prevHash ~= `WEAPON_UNARMED` then
                        if wd then doSwitch(prevHash, wd, h) end   -- armed→armed: holster old, draw new
                    else
                        if wd then doEquip(wd, h) end              -- draw from unarmed
                    end
                    -- Re-sling the put-away weapon (core only re-slings on a clean
                    -- holster-to-unarmed step, which a direct switch never produces).
                    reslingPrevious(prevHash)
                else
                    -- Coordinated holster: bring weapon back into hand so the put-away gesture
                    -- shows it, play the anim, then remove + re-sling onto the back at the END.
                    -- Poll blocked for the gesture; lastWeaponHash already UNARMED so no re-trigger.
                    local prevData = findWeaponDataByHash(prevHash)
                    local prevType = typeOf(prevData and prevData.name)
                    local ha = prevType and MBT.PropInfo and MBT.PropInfo[prevType]
                        and MBT.PropInfo[prevType].HolsterAnim
                    if MBT.QBWeapons and MBT.QBWeapons.DrawAnimation
                        and prevHash ~= `WEAPON_UNARMED`
                        and ha and ha.dict and ha.animOut and ha.animOut ~= '0' and ha.animOut ~= 0 then
                        -- qb REMOVES the weapon on holster (not just unselects), so give it back
                        -- for the gesture, then only DESELECT it (keep on ped) so qb's next draw works.
                        local ammo = (prevData and prevData.metadata and prevData.metadata.ammo) or 30
                        GiveWeaponToPed(cache.ped, prevHash, ammo, false, true)
                        lib.requestAnimDict(ha.dict)
                        TaskPlayAnim(cache.ped, ha.dict, ha.animOut, 2.5, -4.0, ha.sleepOut or 1000, 48, 0.0, false, false, false)
                        Wait(ha.sleepOut or 1000)
                        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)   -- put it away (deselect)
                    end
                    TriggerEvent('ox_inventory:currentWeapon', nil)
                end
            end

            -- Frame-level so the coordinated draw hides the weapon within ~1 frame of
            -- equip (otherwise it visibly flashes before the draw animation).
            Wait(0)
        end
    end
end)

-- ── qb-weapons weapon-draw compatibility notice ──
-- qb-weapons' weapdraw.lua animates every draw/holster/switch over 1–4s through UNARMED,
-- breaking weapon-on-back tracking. malisling already provides its own prompt + sling, so
-- weapdraw is redundant; warn once if qb-weapons is running so the owner can disable it.
CreateThread(function()
    Wait(5000)
    if GetResourceState('qb-weapons') == 'started' then
        Utils.mbtWarn("qb-weapons detected: for correct weapon-on-back behaviour, disable its "
            .. "draw animation — comment `client/weapdraw.lua` in qb-weapons/fxmanifest.lua. "
            .. "weapdraw animates swaps through UNARMED and conflicts with the sling.")
    end
end)
