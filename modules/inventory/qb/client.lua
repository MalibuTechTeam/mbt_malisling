if GetResourceState('qb-inventory') ~= 'started' or GetResourceState('ox_inventory') == 'started' then return end

-- QBCore is already set up by modules/bridge/qb/client.lua which loads first
-- (bridge/ < inventory/ alphabetically)

---Global inventory interface — drop-in replacement for exports['ox_inventory'] client-side.
---ox_inventory events are emulated via polling threads below.
Inventory = {}

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

-- ── currentWeapon polling + holster prompt ─────────────────────────────────────
-- Emulates ox_inventory:currentWeapon for core/client.lua, weapon_drop, weapon_throw,
-- and weapon_jamming.
-- For side-type weapons the holster confirmation UI is shown post-equip:
--   RMB (confirm) → weapon stays in hand
--   BACKSPACE (cancel) → weapon put back on sling
local lastWeaponHash = `WEAPON_UNARMED`

CreateThread(function()
    while not MBT.WeaponsInfo do Wait(500) end

    while true do
        -- Yield while holster prompt is active to avoid re-entrant detection
        if holsterState ~= nil then
            Wait(100)
        else
            local _, weaponHash = GetCurrentPedWeapon(cache.ped, 1)

            if weaponHash ~= lastWeaponHash then
                lastWeaponHash = weaponHash

                if weaponHash ~= `WEAPON_UNARMED` then
                    local weaponData = findWeaponDataByHash(weaponHash)

                    if needsHolsterPrompt(weaponData) then
                        -- Disarm immediately so weapon is not visible during prompt
                        SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
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
                            -- Re-equip and notify the rest of the system
                            SetCurrentPedWeapon(cache.ped, weaponHash, true)
                            TriggerEvent('ox_inventory:currentWeapon', weaponData)
                        end
                        -- If 'cancelled': weapon stays disarmed; lastWeaponHash == weaponHash so
                        -- next poll will see UNARMED and fire currentWeapon(nil) automatically.

                        holsterState = nil
                    else
                        TriggerEvent('ox_inventory:currentWeapon', weaponData)
                    end

                else
                    TriggerEvent('ox_inventory:currentWeapon', nil)
                end
            end

            Wait(250)
        end
    end
end)
