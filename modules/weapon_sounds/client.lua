if not MBT.Sounds or not MBT.Sounds.Enabled then return end

local volume = MBT.Sounds.Volume or 0.4

local function resolveFile(action, weaponType)
    local tbl = action == 'holster' and MBT.Sounds.Holster or MBT.Sounds.Unholster
    return (tbl and (tbl[weaponType] or tbl.default)) or action
end

local function playSound(file)
    SendNUIMessage({ action = 'playHolsterSound', data = { file = file, volume = volume } })
end

AddEventHandler('mbt_malisling:onHolster', function(weaponType)
    local file = resolveFile('holster', weaponType)
    playSound(file)
    TriggerServerEvent('mbt_malisling:syncHolsterSound', weaponType, 'holster')
end)

AddEventHandler('mbt_malisling:onUnholster', function(weaponType)
    local file = resolveFile('unholster', weaponType)
    playSound(file)
    TriggerServerEvent('mbt_malisling:syncHolsterSound', weaponType, 'unholster')
end)

RegisterNetEvent('mbt_malisling:remoteHolsterSound')
AddEventHandler('mbt_malisling:remoteHolsterSound', function(sourcePlayer, weaponType, action)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(sourcePlayer))
    if not targetPed or not DoesEntityExist(targetPed) then return end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(targetPed)) > MBT.Sounds.MaxDistance then return end
    playSound(resolveFile(action, weaponType))
end)
