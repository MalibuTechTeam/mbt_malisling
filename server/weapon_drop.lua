local ox_inventory = exports["ox_inventory"]

RegisterServerEvent('mbt_malisling:dropWeapon', function(data)
    local _source = source
    
    print(data.slot, data.hash)

    assert(data.hash ~= nil, 'dropWeapon ~ hash of weapons nil')

    local r = ('DeadDrop %s000000000'):format(os.time(os.date('*t')))
    
    if type(data.slot) == 'number' then
        local item = ox_inventory:GetSlot(source, data.slot)
        local success = ox_inventory:RemoveItem(_source, item.name, item.count, nil, item.slot)
        if success then
            ox_inventory:CustomDrop(r, {
                { item.name, item.count, item.metadata }
            }, GetEntityCoords(GetPlayerPed(_source)), 1, 10000, nil, data.hash or `prop_water_corpse_01`)
        end
    end
end)