-- ─────────────────────────────────────────────────────────────────────────────
-- Ground weapon drop system.
--
-- malisling owns the dropped-weapon visual prop and the loot interaction
-- (see modules/weapon_drop/client.lua). The item itself is held here in memory
-- and handed straight back to whoever loots it — no ox_inventory drop/stash,
-- so the visual is immune to ox_inventory changes (its drop renderer rejects
-- weapon models since 2.47.x, which is why drops showed a generic bag).
--
-- GroundDrop is global so weapon_throw/server.lua (loaded after) can reuse it.
-- ─────────────────────────────────────────────────────────────────────────────

GroundDrop = {}

local drops = {}  -- [dropId] = { coords = vec3, weaponHash = number, item = { name, count, metadata } }

local function newDropId()
    return ('mbtdrop_%d_%d'):format(os.time(), math.random(100000, 999999))
end

--- Pull a weapon out of a player's inventory and spawn it as a ground drop.
---@param src number
---@param slot number
---@param weaponHash number  weapon hash (joaat) — used client-side by CreateWeaponObject
---@param coords vector3
function GroundDrop.Create(src, slot, weaponHash, coords)
    local item = Inventory:GetSlot(src, slot)
    if not item then return end
    if not Inventory:RemoveItem(src, item.name, item.count, nil, item.slot) then return end

    local dropId = newDropId()
    drops[dropId] = {
        coords     = coords,
        weaponHash = weaponHash,
        item       = { name = item.name, count = item.count, metadata = item.metadata },
    }

    TriggerClientEvent('mbt_malisling:spawnGroundDrop', -1, dropId, coords, weaponHash)
    Utils.mbtDebugger("GroundDrop.Create ~ created", dropId, "for", item.name)
end

-- Loot a ground drop: hand the item back and despawn the prop everywhere.
lib.callback.register('mbt_malisling:lootGroundDrop', function(src, dropId)
    local drop = drops[dropId]
    if not drop then return false end

    local added = Inventory:AddItem(src, drop.item.name, drop.item.count, drop.item.metadata)
    if not added then return false end  -- inventory full etc. — leave the drop in place

    drops[dropId] = nil
    TriggerClientEvent('mbt_malisling:removeGroundDrop', -1, dropId)
    Utils.mbtDebugger("lootGroundDrop ~", src, "looted", dropId)
    return true
end)

-- Late-join sync: a freshly-loaded client requests every active drop.
lib.callback.register('mbt_malisling:getGroundDrops', function()
    return drops
end)

-- ── Drop-on-death ──────────────────────────────────────────────────────────────
RegisterNetEvent('mbt_malisling:dropWeapon', function(data)
    local src = source
    if type(data) ~= 'table' or type(data.slot) ~= 'number' then return end
    if type(data.weaponHash) ~= 'number' then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    GroundDrop.Create(src, data.slot, data.weaponHash, GetEntityCoords(ped))
end)
