if not MBT.Sounds then return end

local function resolveFile(action, weaponType)
    local tbl = action == 'holster' and MBT.Sounds.Holster or MBT.Sounds.Unholster
    return (tbl and (tbl[weaponType] or tbl.default)) or action
end

-- Read Enabled/Volume fresh each call (not cached) so live-apply works without a restart.
local function playSound(file)
    if not MBT.Sounds.Enabled then return end
    SendNUIMessage({ action = 'playHolsterSound', data = { file = file, volume = MBT.Sounds.Volume or 0.4 } })
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
