-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon drop — server
--
-- ox_inventory path: weapons leave the player as real ox drops (CustomDrop).
--   The client listens to ox_inventory:createDrop, asks checkWeaponDrop whether
--   the drop holds a weapon, and renders the weapon model + ox_target itself
--   (ox can't render weapon models). This covers native drag-drop, death drop
--   and throw with one path, and keeps native walk-in pickup working.
--
-- qb-inventory path (fallback tier): a lighter GroundDrop system — the item is
--   held server-side and handed straight back on loot. No native-drop coverage.
--
-- WeaponDropServer is global so weapon_throw/server.lua can reuse Create().
-- ─────────────────────────────────────────────────────────────────────────────

local isOx = GetResourceState('ox_inventory') == 'started'

WeaponDropServer = {}

if isOx then
    --- Pull a weapon from a player's inventory and create a real ox drop for it.
    ---@param src number
    ---@param slot number
    ---@param coords vector3
    function WeaponDropServer.Create(src, slot, coords)
        local item = Inventory:GetSlot(src, slot)
        if not item then return end
        -- Forensic backbone: a dropped weapon keeps a serial (safe transition).
        if MBT.EnsureSerial then MBT.EnsureSerial(src, item) end
        if not Inventory:RemoveItem(src, item.name, item.count, nil, item.slot) then return end

        if MBT.LogWeaponDrop then MBT.LogWeaponDrop(src, item, coords) end

        exports.ox_inventory:CustomDrop('Weapon', {
            { item.name, item.count, item.metadata }
        }, coords)
    end

    -- Despawn: clients run the timer and request the despawn on expiry. Clearing
    -- the drop's inventory makes ox remove the now-empty drop and broadcast
    -- ox_inventory:removeDrop to everyone. Deduped so redundant client requests
    -- (one per client running the timer) are no-ops.
    local despawned = {}  -- [dropId] = true
    RegisterNetEvent('mbt_malisling:despawnWeaponDrop', function(dropId)
        if not dropId or despawned[dropId] then return end
        despawned[dropId] = true
        exports.ox_inventory:ClearInventory(dropId)
        -- Forget the id after a moment so the table can't grow unbounded.
        SetTimeout(10000, function() despawned[dropId] = nil end)
    end)

    --- The client asks, for a freshly created drop, whether it holds a weapon.
    --- Returns the weapon hash (for CreateWeaponObject) or false.
    lib.callback.register('mbt_malisling:checkWeaponDrop', function(src, dropId)
        local items = exports.ox_inventory:GetInventoryItems(dropId)
        if type(items) ~= 'table' then return false end
        for _, item in pairs(items) do
            -- Utils.isWeapon is client-only; inline the check here (server-side).
            if type(item) == 'table' and type(item.name) == 'string'
               and item.name:sub(1, 7) == 'WEAPON_' then
                return joaat(item.name)
            end
        end
        return false
    end)
else
    -- qb fallback: GroundDrop give-back.
    local drops = {}  -- [dropId] = { coords, weaponHash, item }

    ---@param src number
    ---@param slot number
    ---@param coords vector3
    ---@param weaponHash number
    function WeaponDropServer.Create(src, slot, coords, weaponHash)
        local item = Inventory:GetSlot(src, slot)
        if not item then return end
        -- Forensic backbone: a dropped weapon keeps a serial (safe transition).
        if MBT.EnsureSerial then MBT.EnsureSerial(src, item) end
        if not Inventory:RemoveItem(src, item.name, item.count, nil, item.slot) then return end

        if MBT.LogWeaponDrop then MBT.LogWeaponDrop(src, item, coords) end

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
        if not Inventory:AddItem(src, drop.item.name, drop.item.count, drop.item.metadata) then
            return false  -- inventory full etc. — leave the drop in place
        end
        drops[dropId] = nil
        TriggerClientEvent('mbt_malisling:removeGroundDrop', -1, dropId)
        return true
    end)

    lib.callback.register('mbt_malisling:getGroundDrops', function()
        return drops
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
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    WeaponDropServer.Create(src, data.slot, GetEntityCoords(ped), data.weaponHash)
end)
