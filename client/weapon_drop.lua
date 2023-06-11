if MBT.DropWeaponOnDeath then
    local CurrentWeapon = {}

    AddEventHandler('ox_inventory:currentWeapon', function(currentWeapon) CurrentWeapon = currentWeapon end)

    AddEventHandler('gameEventTriggered', function(event, data)
        if event == 'CEventNetworkEntityDamage' then
            if data[1] == cache.ped and IsEntityDead(cache.ped) then
                if CurrentWeapon then
                    DeleteEntity(GetWeaponObjectFromPed(cache.ped))
                    TriggerServerEvent('mbt_malisling:dropWeapon', {
                        slot = CurrentWeapon.slot,
                        hash = GetWeapontypeModel(CurrentWeapon.hash)
                    })
                end
            end
        end
    end)
end
