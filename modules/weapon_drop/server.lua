-- Inventory is provided by modules/inventory/*/server.lua

RegisterNetEvent('mbt_malisling:dropWeapon', function(data)
    assert(data.hash ~= nil, 'dropWeapon ~ hash of weapons nil')
    if type(data.slot) ~= 'number' then return end

    local item = Inventory:GetSlot(source, data.slot)
    if not item then return end

    local success = Inventory:RemoveItem(source, item.name, item.count, nil, item.slot)
    if success then
        local r = ('DeadDrop %s000000000'):format(os.time(os.date('*t')))
        Inventory:CustomDrop(r, {
            { item.name, item.count, item.metadata }
        }, GetEntityCoords(GetPlayerPed(source)), 1, 10000, nil, data.hash or `prop_water_corpse_01`)
    end
end)
