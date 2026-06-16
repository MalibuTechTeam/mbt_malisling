if GetResourceState('qb-inventory') ~= 'started' or GetResourceState('ox_inventory') == 'started' then return end

-- QBCore is already set up by modules/bridge/qb/client.lua which loads first
-- (bridge/ < inventory/ alphabetically)

---Global inventory interface — drop-in replacement for exports['ox_inventory'] client-side.
---ox_inventory events are emulated via polling threads below.
Inventory = {}

-- ── Attachment translation (qb → MBT/ox) ───────────────────────────────────────
-- qb-weapons stores attachments in info.attachments as { { component = <GTA hash
-- or name> }, ... }. The slung-prop renderer (core applyAttachments) expects
-- metadata.components = { '<ox item key>', ... } indexing MBT.WeaponsInfo.Components
-- (each key's client.component is a list of GTA hashes). Reverse-map qb's GTA
-- components back to those keys so the slung prop shows scope/flashlight/suppressor
-- on qb too. ox-only fields are untouched (this file no-ops when ox is running).
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

-- ── Normalisation helper ───────────────────────────────────────────────────────
-- Maps qb-inventory item field names to the ox_inventory-compatible field names.
local function normalizeItem(item)
    if not item then return nil end
    local info = item.info or {}
    local metadata = {}
    for k, v in pairs(info) do metadata[k] = v end
    -- qb uses .quality (0-100) for durability and .serie for serial number
    metadata.durability = metadata.durability or info.quality
    metadata.serial     = metadata.serial     or info.serie
    -- qb attachments → ox-style components list (for slung-prop accessories)
    metadata.components = metadata.components or qbAttachmentsToComponents(info.attachments)
    -- qb weapon names are lowercase → canonicalize to uppercase to match MBT +
    -- MBT.WeaponsInfo + ox. Keep the raw qb name for any qb-side comparison.
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

-- Canonicalize a name the same way normalizeItem does (weapon names → UPPER) so
-- searches match regardless of case. Callers now pass canonical WEAPON_ names
-- (from MBT.WeaponsInfo / equippedWeapon), but qb's raw item.name is lowercase.
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

-- ox_inventory:disarm → native weapon removal
AddEventHandler('ox_inventory:disarm', function()
    RemoveAllPedWeapons(cache.ped, true)
end)

-- ── Holster key mappings ───────────────────────────────────────────────────────
-- Mirrors the RegisterKeyMapping injected by appendMalisling() for ox_inventory.
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

-- ── Helpers ────────────────────────────────────────────────────────────────────

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
    -- Read our own live config, not the replicated convar: SetConvarReplicated
    -- ('malisling:enable_sling') doesn't reliably reach the client on every qb
    -- server, which silently disabled the side-weapon holster prompt (pistol drew
    -- then bounced straight back to the holster). MBT.EnableSling is always set
    -- here (config.lua default + applyConfig) and honours live dashboard toggles.
    if not MBT.EnableSling then return false end
    local wInfo = MBT.WeaponsInfo
        and MBT.WeaponsInfo["Weapons"]
        and MBT.WeaponsInfo["Weapons"][weaponData.name]
    if not (wInfo and wInfo.type == 'side') then return false end
    -- QB default: let qb-weapons own the pistol draw animation (no double-play,
    -- no re-equip bounce). Only take over when explicitly in ox-parity mode.
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

-- ── Inventory snapshot polling ─────────────────────────────────────────────────
-- Emulates ox_inventory:itemCount and ox_inventory:updateInventory for core/client.lua.
local lastSnapshot = {}

CreateThread(function()
    while not MBT.WeaponsInfo do Wait(500) end

    while true do
        local currentSnapshot = {}

        for _, item in pairs(QBCore.Functions.GetPlayerData().items or {}) do
            if Utils.isWeapon(item.name) then
                -- Key by the CANONICAL name (WEAPON_*): the core itemCount/updateInventory
                -- handlers look weapons up in MBT.WeaponsInfo, which is uppercase-keyed.
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

-- ── currentWeapon detection ────────────────────────────────────────────────────
-- Emulates ox_inventory:currentWeapon for core/client.lua, weapon_drop, weapon_throw,
-- weapon_jamming by polling GetCurrentPedWeapon. On a direct armed→armed switch the
-- previous weapon is re-slung (the core only re-slings on a clean holster step).
-- NOTE: requires qb-weapons' weapon-draw animation (client/weapdraw.lua) to be
-- DISABLED — weapdraw animates every swap over 1–4s, oscillating the ped weapon
-- through UNARMED, which no real-time weapon-on-back tracker can follow cleanly.
-- Without qb-weapons (or with weapdraw off) this works instantly. A startup warning
-- (below) reminds the user when qb-weapons is present.
-- For side-type weapons the holster confirmation UI is shown post-equip:
--   RMB (confirm) → weapon stays in hand · BACKSPACE (cancel) → weapon put on sling
local lastWeaponHash = `WEAPON_UNARMED`

--- Weapon type ('side'/'back'/…) from a canonical weapon name.
local function typeOf(name)
    return name and MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]
        and MBT.WeaponsInfo.Weapons[name].type or nil
end

--- Equip handling shared by all transitions: fires currentWeapon(data), with the
--- side-weapon holster prompt when enabled (qbSidearmDrawMode == 'malisling').
local function doEquip(weaponData, weaponHash)
    if needsHolsterPrompt(weaponData) then
        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)   -- hide during prompt
        holsterState = true
        SendNUIMessage({ action = 'showHolster', data = {
            weaponLabel = weaponData.name:upper(),
            position    = MBT.UI and MBT.UI.Position or 'bottom-center',
            confirm     = { label = MBT.HolsterControls["Confirm"]["Label"], display = 'RMB' },
            cancel      = { label = MBT.HolsterControls["Cancel"]["Label"],  display = 'BACKSPACE' },
            locale      = buildNuiLocale(),
        }})
        while holsterState == true do Wait(50) end
        SendNUIMessage({ action = 'hideHolster' })
        if holsterState == 'confirmed' then
            SetCurrentPedWeapon(cache.ped, weaponHash, true)
            TriggerEvent('ox_inventory:currentWeapon', weaponData)
            playHolsterAnim(typeOf(weaponData.name), 'in')
        else
            lastWeaponHash = `WEAPON_UNARMED`   -- cancelled: weapon stays on the sling
        end
        holsterState = nil
    else
        -- Coordinated draw: hide the weapon, play the draw gesture, then bring it out,
        -- so the animation reads as a real draw (not a gesture over an already-out gun).
        -- The poll is blocked here during the Wait, so it never sees the hidden state.
        local t  = typeOf(weaponData.name)
        local ha = t and MBT.PropInfo and MBT.PropInfo[t] and MBT.PropInfo[t].HolsterAnim
        if MBT.QBWeapons and MBT.QBWeapons.DrawAnimation
            and ha and ha.dict and ha.animIn and ha.animIn ~= '0' and ha.animIn ~= 0 then
            SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
            lib.requestAnimDict(ha.dict)
            -- Softer blend-in (2.5) so the draw eases in instead of snapping. Tune the
            -- gesture length per weapon type via MBT.PropInfo[type].HolsterAnim.sleep.
            TaskPlayAnim(cache.ped, ha.dict, ha.animIn, 2.5, -4.0, ha.sleep or 1000, 48, 0.0, false, false, false)
            Wait(ha.sleep or 1000)
            SetCurrentPedWeapon(cache.ped, weaponHash, true)
        end
        TriggerEvent('ox_inventory:currentWeapon', weaponData)
    end
end

--- After a direct armed→armed switch, re-create the PREVIOUS weapon's slung prop
--- (qb-weapons swaps without a stable UNARMED step, so the core never re-slings it).
--- Runs only after the new weapon has settled, so it never perturbs the draw.
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

--- Direct armed→armed switch: reproduce a real weapdraw-style sequence — HOLSTER the
--- old weapon (gesture, weapon in hand) THEN DRAW the new one — instead of qb's instant
--- swap. qb already drew the new weapon, so we hide it, replay the old weapon's put-away
--- gesture, then draw the new via doEquip. The poll is blocked here for the whole sequence.
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
    doEquip(newData, newHash)   -- now draw the new weapon (hide → animIn → show)
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
                        -- Armed→armed switch: holster the old weapon, then draw the new.
                        if wd then doSwitch(prevHash, wd, h) end
                    else
                        -- Draw from unarmed.
                        if wd then doEquip(wd, h) end
                    end
                    -- Re-sling the weapon we just put away (the core only re-slings on a
                    -- clean holster-to-unarmed step, which a direct switch never produces).
                    reslingPrevious(prevHash)
                else
                    -- Coordinated holster: bring the weapon back into the hand so the
                    -- put-away gesture actually shows it, play the holster animation, then
                    -- remove it and re-sling onto the back at the END. The poll is blocked
                    -- here for the gesture; lastWeaponHash is already UNARMED so it won't
                    -- re-trigger when we resume.
                    local prevData = findWeaponDataByHash(prevHash)
                    local prevType = typeOf(prevData and prevData.name)
                    local ha = prevType and MBT.PropInfo and MBT.PropInfo[prevType]
                        and MBT.PropInfo[prevType].HolsterAnim
                    if MBT.QBWeapons and MBT.QBWeapons.DrawAnimation
                        and prevHash ~= `WEAPON_UNARMED`
                        and ha and ha.dict and ha.animOut and ha.animOut ~= '0' and ha.animOut ~= 0 then
                        -- qb REMOVES the weapon from the ped on holster (not just unselects),
                        -- so GiveWeaponToPed it back into the hand for the gesture, then
                        -- only DESELECT it (keep it on the ped) — so qb's next draw still works.
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

            -- Frame-level so the coordinated draw can hide the weapon within ~1 frame of
            -- it being equipped (otherwise it visibly flashes before the draw animation).
            Wait(0)
        end
    end
end)

-- ── qb-weapons weapon-draw compatibility notice ────────────────────────────────
-- qb-weapons' client/weapdraw.lua animates every weapon draw/holster/switch over
-- 1–4s, oscillating the ped weapon through UNARMED. That breaks any weapon-on-back
-- system that tracks the held weapon. malisling already provides its own holster
-- prompt + sling, so weapdraw is redundant here. Warn once if qb-weapons is running
-- so the server owner can disable weapdraw for correct sling behaviour.
CreateThread(function()
    Wait(5000)
    if GetResourceState('qb-weapons') == 'started' then
        Utils.mbtWarn("qb-weapons detected: for correct weapon-on-back behaviour, disable its "
            .. "draw animation — comment `client/weapdraw.lua` in qb-weapons/fxmanifest.lua. "
            .. "weapdraw animates swaps through UNARMED and conflicts with the sling.")
    end
end)
