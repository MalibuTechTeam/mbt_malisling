-- ── Weapon drop — server ──
-- ox path: weapons leave the player as real ox drops (CustomDrop); the client renders the
--   weapon model + ox_target itself (ox can't). Covers drag-drop, death and throw in one path.
-- qb path (fallback): lighter GroundDrop — item held server-side, handed back on loot.
-- WeaponDropServer is global so weapon_throw/server.lua can reuse Create().

local isOx = GetResourceState('ox_inventory') == 'started'

WeaponDropServer = {}

if isOx then
    --- Pull a weapon from a player's inventory and create a real ox drop for it.
    function WeaponDropServer.Create(src, slot, coords)
        local item = Inventory:GetSlot(src, slot)
        if not item then return end
        -- Forensic backbone: a dropped weapon keeps a serial.
        if MBT.EnsureSerial then MBT.EnsureSerial(src, item) end
        if not Inventory:RemoveItem(src, item.name, item.count, nil, item.slot) then return end

        if MBT.LogWeaponDrop then MBT.LogWeaponDrop(src, item, coords) end

        exports.ox_inventory:CustomDrop('Weapon', {
            { item.name, item.count, item.metadata }
        }, coords)
    end

    -- Despawn: clients run the timer and request despawn on expiry. Clearing the drop's
    -- inventory makes ox remove the empty drop + broadcast removeDrop. Deduped so redundant
    -- requests (one per client running the timer) are no-ops.
    local despawned = {}  -- [dropId] = true
    RegisterNetEvent('mbt_malisling:despawnWeaponDrop', function(dropId)
        local src = source
        -- dropId is client-supplied, so it never reaches ClearInventory unvalidated: ox drop
        -- ids are strings (player/stash inventories are numeric), and OUR drops hold only
        -- WEAPON_ items — a player/stash inventory (bread, phone, …) fails the check and is
        -- refused, so a replayed id can't wipe someone's inventory.
        if type(dropId) ~= 'string' or despawned[dropId] then return end
        if not (MBT.NetThrottle and MBT.NetThrottle(src, 'despawn', 250)) then return end

        local items = exports.ox_inventory:GetInventoryItems(dropId)
        if type(items) ~= 'table' or not next(items) then return end
        for _, item in pairs(items) do
            if type(item) ~= 'table' or type(item.name) ~= 'string'
               or item.name:sub(1, 7) ~= 'WEAPON_' then return end
        end

        despawned[dropId] = true
        exports.ox_inventory:ClearInventory(dropId)
        SetTimeout(10000, function() despawned[dropId] = nil end)   -- forget so the table can't grow unbounded
    end)

    --- Which weapons a freshly created drop holds; ox can merge several items into ONE drop, so return EVERY weapon's hash (client renders a model for each). Empty list → no weapons.
    lib.callback.register('mbt_malisling:checkWeaponDrop', function(src, dropId)
        local items = exports.ox_inventory:GetInventoryItems(dropId)
        if type(items) ~= 'table' then return {} end
        local hashes = {}
        for _, item in pairs(items) do
            -- Utils.isWeapon is client-only; inline the check here (server-side).
            if type(item) == 'table' and type(item.name) == 'string'
               and item.name:sub(1, 7) == 'WEAPON_' then
                hashes[#hashes + 1] = joaat(item.name)
                if #hashes >= 6 then break end   -- sanity cap
            end
        end
        return hashes
    end)
else
    -- qb fallback: GroundDrop give-back.
    local drops = {}  -- [dropId] = { coords, weaponHash, item }

    function WeaponDropServer.Create(src, slot, coords, weaponHash)
        local item = Inventory:GetSlot(src, slot)
        if not item then return end
        -- Forensic backbone: a dropped weapon keeps a serial.
        if MBT.EnsureSerial then MBT.EnsureSerial(src, item) end
        if not Inventory:RemoveItem(src, item.name, item.count, nil, item.slot) then return end

        if MBT.LogWeaponDrop then MBT.LogWeaponDrop(src, item, coords) end

        -- Never trust the client's weaponHash (visual/forensic spoof: the drop could look like a
        -- knife but loot a rifle). Derive it from the item that actually left the inventory.
        weaponHash = joaat(item.name)
        local dropId = ('mbtweapon_%d_%d'):format(os.time(), math.random(100000, 999999))
        drops[dropId] = {
            coords     = coords,
            weaponHash = weaponHash,
            item       = { name = item.name, count = item.count, metadata = item.metadata },
        }
        TriggerClientEvent('mbt_malisling:spawnGroundDrop', -1, dropId, coords, weaponHash)
    end

    lib.callback.register('mbt_malisling:lootGroundDrop', function(src, dropId)
        local drop = drops[dropId]
        if not drop then return false end
        -- Server-authoritative proximity: a client knows every drop id (getGroundDrops),
        -- so without this it could loot any drop on the map.
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return false end
        if not drop.coords or #(GetEntityCoords(ped) - drop.coords) > 3.0 then return false end
        if not Inventory:AddItem(src, drop.item.name, drop.item.count, drop.item.metadata) then
            return false  -- inventory full etc. — leave the drop in place
        end
        drops[dropId] = nil
        TriggerClientEvent('mbt_malisling:removeGroundDrop', -1, dropId)
        return true
    end)

    lib.callback.register('mbt_malisling:getGroundDrops', function()
        -- Late-join sync only needs coords + hash. Don't leak item metadata (serial) or let
        -- a client enumerate every grounded weapon's contents.
        local out = {}
        for id, d in pairs(drops) do out[id] = { coords = d.coords, weaponHash = d.weaponHash } end
        return out
    end)

    -- Despawn: clients run the timer and request it on expiry. The whole drop is
    -- ours, so drop the item entirely and tell everyone to remove the prop. Deduped.
    RegisterNetEvent('mbt_malisling:despawnGroundDrop', function(dropId)
        if not dropId or not drops[dropId] then return end
        drops[dropId] = nil
        TriggerClientEvent('mbt_malisling:removeGroundDrop', -1, dropId)
    end)
end

-- Drop-on-death (both paths). The ox Create ignores the 4th arg.
RegisterNetEvent('mbt_malisling:dropWeapon', function(data)
    local src = source
    if type(data) ~= 'table' or type(data.slot) ~= 'number' then return end
    if not (MBT.NetThrottle and MBT.NetThrottle(src, 'dropWeapon', 250)) then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    WeaponDropServer.Create(src, data.slot, GetEntityCoords(ped), data.weaponHash)
end)
