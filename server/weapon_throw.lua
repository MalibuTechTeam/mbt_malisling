local ox_inventory = exports["ox_inventory"]

RegisterNetEvent("mbt_malisling:createWeaponDrop", function(data)
    assert(data.WeaponInfo.ObjHash ~= nil, 'dropWeapon ~ hash of weapons nil')

    local r = ('ThrownDrop %s000000000'):format(os.time(os.date('*t')))

    if type(data.WeaponInfo.slot) == 'number' then
        local item = ox_inventory:GetSlot(source, data.WeaponInfo.slot)
        local success = ox_inventory:RemoveItem(source, item.name, item.count, nil, item.slot)
        if success then
            ox_inventory:CustomDrop(r, {
                { item.name, item.count, item.metadata }
            }, data.Coords, 1, 10000, nil, data.WeaponInfo.ObjHash or `prop_water_corpse_01`)
        end
    end
end)
