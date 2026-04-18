-- Inventory is provided by modules/inventory/*/server.lua

RegisterNetEvent("mbt_malisling:createWeaponDrop", function(data)
    assert(data.WeaponInfo.ObjHash ~= nil, 'createWeaponDrop ~ ObjHash of weapon nil')
    if type(data.WeaponInfo.slot) ~= 'number' then return end

    local item = Inventory:GetSlot(source, data.WeaponInfo.slot)
    if not item then return end

    local success = Inventory:RemoveItem(source, item.name, item.count, nil, item.slot)
    if success then
        local r = ('ThrownDrop %s000000000'):format(os.time(os.date('*t')))
        Inventory:CustomDrop(r, {
            { item.name, item.count, item.metadata }
        }, data.Coords, 1, 10000, nil, data.WeaponInfo.ObjHash or `prop_water_corpse_01`)
    end
end)
