if GetResourceState('qb-inventory') ~= 'started' or GetResourceState('ox_inventory') == 'started' then return end

if GetResourceState('qb-core') ~= 'started' then
    warn("mbt_malisling: qb-inventory requires qb-core to be running.")
    return
end

-- QBCore is set up by modules/bridge/qb/server.lua which loads first (bridge/ < inventory/)

-- ── Normalisation helper ───────────────────────────────────────────────────────
-- Maps qb-inventory item field names to the ox_inventory-compatible field names
-- that core/server.lua and the weapon modules expect.
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
        count    = item.amount,
        slot     = item.slot,
        metadata = metadata,
        label    = item.label or item.name,
    }
end

-- ── Global inventory interface ─────────────────────────────────────────────────
Inventory = {}

---Mimics ox_inventory:GetSlot(source, slot)
function Inventory:GetSlot(source, slot)
    local item = exports['qb-inventory']:GetItemBySlot(tonumber(source), tonumber(slot))
    return normalizeItem(item)
end

---Mimics ox_inventory:RemoveItem(source, name, count, metadata, slot)
function Inventory:RemoveItem(source, name, count, _, slot)
    return exports['qb-inventory']:RemoveItem(tonumber(source), name, count, slot) ~= false
end

---Mimics ox_inventory:GetInventoryItems(source) — returns a table keyed by item name
function Inventory:GetInventoryItems(source)
    local Player = QBCore.Functions.GetPlayer(tonumber(source))
    if not Player then return {} end
    local result = {}
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item.name and item.amount and item.amount > 0 then
            result[item.name] = normalizeItem(item)
        end
    end
    return result
end

---Mimics ox_inventory:SetMetadata(source, slot, metadata)
---Uses qb-inventory's SetItemData export (no destructive remove+re-add needed)
function Inventory:SetMetadata(source, slot, metadata)
    local item = exports['qb-inventory']:GetItemBySlot(tonumber(source), tonumber(slot))
    if not item then return false end
    -- Merge new metadata back to qb-style info, preserving fields we don't touch
    local newInfo = item.info or {}
    for k, v in pairs(metadata) do newInfo[k] = v end
    -- Sync normalized fields back to qb field names
    if metadata.durability then newInfo.quality = metadata.durability end
    if metadata.serial     then newInfo.serie   = metadata.serial     end
    return exports['qb-inventory']:SetItemData(tonumber(source), item.name, 'info', newInfo, tonumber(slot)) ~= false
end

---Mimics ox_inventory:CustomDrop(id, items, coords, slots, maxWeight, ownerId, modelHash)
---Creates a qb-inventory stash and tells nearby clients to spawn a lootable pickup prop.
function Inventory:CustomDrop(id, items, coords, _, _, _, modelHash)
    -- Convert { {name, count, metadata}, ... } to qb item format
    local qbItems = {}
    for i, v in ipairs(items) do
        qbItems[i] = {
            name   = v[1],
            amount = v[2],
            info   = v[3] or {},
            slot   = i,
        }
    end

    local ok, err = pcall(function()
        exports['qb-inventory']:CreateInventory(id, qbItems)
    end)
    if not ok then
        warn(("mbt_malisling: CustomDrop ~ CreateInventory failed (%s). " ..
              "Items may not be lootable — verify your qb-inventory version."):format(err))
    end

    -- Spawn a lootable prop client-side for nearby players
    TriggerClientEvent('mbt_malisling:spawnPickupProp', -1, {
        id     = id,
        coords = coords,
        model  = modelHash,
    })
end

-- ── Flashlight state persistence ───────────────────────────────────────────────
-- Stores flashlight on/off state into item.info.flashlightState when player holsters.
AddStateBagChangeHandler('WeaponFlashlightState', nil, function(bagName, key, value)
    if not value then return end
    local playerSource = tonumber(bagName:gsub('player:', ''))

    for slot, payload in pairs(value) do
        local item = exports['qb-inventory']:GetItemBySlot(playerSource, tonumber(slot))
        if not item then return end
        local newInfo = item.info or {}
        newInfo.flashlightState = payload.FlashlightState
        exports['qb-inventory']:SetItemData(playerSource, item.name, 'info', newInfo, tonumber(slot))
    end
end)

-- ── Pickup drop callback ───────────────────────────────────────────────────────
-- Called by the client when a player presses E near a dropped weapon prop.
lib.callback.register('mbt_malisling:openWeaponDrop', function(source, dropId)
    exports['qb-inventory']:OpenInventory(source, dropId)
    return true
end)

-- ── Weapon data fallback ───────────────────────────────────────────────────────
function loadInventoryWeaponsData()
    local file  = LoadResourceFile(GetCurrentResourceName(), 'data/weapons_fallback.lua')
    local chunk = assert(load(file, '@@mbt_malisling/data/weapons_fallback.lua'))
    return chunk()
end
