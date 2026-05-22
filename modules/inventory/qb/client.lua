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
    return {
        name     = item.name,
        slot     = item.slot,
        count    = item.amount,
        metadata = metadata,
        label    = item.label or item.name,
    }
end

---Mimics ox_inventory:Search('slots', itemName | {itemNames})
function Inventory:Search(_, itemName)
    local items  = QBCore.Functions.GetPlayerData().items or {}
    local result = {}

    if type(itemName) == 'string' then
        for _, item in pairs(items) do
            if item.name == itemName then
                result[#result + 1] = normalizeItem(item)
            end
        end

    elseif type(itemName) == 'table' then
        local nameSet = {}
        for _, n in pairs(itemName) do nameSet[n] = true end
        for _, item in pairs(items) do
            if nameSet[item.name] then
                result[item.name] = result[item.name] or {}
                result[item.name][#result[item.name] + 1] = normalizeItem(item)
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

local function needsHolsterPrompt(weaponData)
    if not weaponData then return false end
    if GetConvar('malisling:enable_sling', 'false') ~= 'true' then return false end
    local wInfo = MBT.WeaponsInfo
        and MBT.WeaponsInfo["Weapons"]
        and MBT.WeaponsInfo["Weapons"][weaponData.name]
    return wInfo and wInfo.type == 'side'
end

-- ── Inventory snapshot polling ─────────────────────────────────────────────────
-- Emulates ox_inventory:itemCount and ox_inventory:updateInventory for core/client.lua.
local lastSnapshot = {}

CreateThread(function()
    while not MBT.WeaponsInfo do Wait(500) end

    while true do
        local currentSnapshot = {}

        for _, item in pairs(QBCore.Functions.GetPlayerData().items or {}) do
            if Utils.isWeapon(item.name) then
                currentSnapshot[item.name] = normalizeItem(item)
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

-- ── Pickup prop handler ────────────────────────────────────────────────────────
-- Server fires this when a weapon is dropped/thrown; we spawn a prop and show
-- an interaction prompt so nearby players can loot it.
RegisterNetEvent('mbt_malisling:spawnPickupProp')
AddEventHandler('mbt_malisling:spawnPickupProp', function(payload)
    local dropId   = payload.id
    local coords   = payload.coords
    local model    = payload.model or `prop_cs_cuffs_01`

    lib.requestModel(model)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    CreateThread(function()
        while DoesEntityExist(obj) do
            local myCoords = GetEntityCoords(cache.ped)
            local dist     = #(myCoords - coords)

            if dist < 2.0 then
                lib.showTextUI('[E] ' .. Translate('pickup_weapon'))

                if IsControlJustPressed(0, 38) then -- E key
                    lib.hideTextUI()
                    local opened = lib.callback.await('mbt_malisling:openWeaponDrop', false, dropId)
                    if opened then
                        DeleteObject(obj)
                        return
                    end
                end
            else
                lib.hideTextUI()
            end

            Wait(0)
        end

        lib.hideTextUI()
    end)
end)
