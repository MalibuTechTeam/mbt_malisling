local CurrentWeapon = {}

AddEventHandler('ox_inventory:currentWeapon', function(currentWeapon) CurrentWeapon = currentWeapon end)
if MBT.DropWeaponOnDeath then

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

function dropCurrentWeapon()
    local playerPed = cache.ped
    local boneIndex = GetPedBoneIndex(playerPed, 57005)
    local bonePos = GetWorldPositionOfEntityBone(playerPed, boneIndex)
    local weaponModel = GetWeapontypeModel(CurrentWeapon.hash)
    local currentWeapon = Utils.tableDeepCopy(CurrentWeapon)
    lib.requestModel(weaponModel)
    equippedWeapon.dropped = true
    local weaponObj = CreateObject(weaponModel, bonePos.x, bonePos.y, bonePos.z, true, true, true)
    ActivatePhysics(weaponObj)
    TriggerEvent("ox_inventory:disarm", true)
    while IsEntityInAir(weaponObj) do Wait(100) end
    local deadline = GetGameTimer() + 800
    repeat
        Wait(50)
        local vel = GetEntityVelocity(weaponObj)
        if math.abs(vel.x) < 0.05 and math.abs(vel.y) < 0.05 and math.abs(vel.z) < 0.05 then break end
    until GetGameTimer() > deadline
    local weaponCoords = GetEntityCoords(weaponObj)
    DeleteObject(weaponObj)
    TriggerServerEvent("mbt_malisling:createWeaponDrop", {
        WeaponInfo = currentWeapon,
        Coords = weaponCoords
    })
end

exports('dropCurrentWeapon', dropCurrentWeapon)
