if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId)
    playersToTrack[playerId] = {}
end)

function getPlayerJob(s)
    s = tonumber(s)
    local xPlayer = ESX.GetPlayerFromId(s)
    if not xPlayer then return '' end
    return xPlayer.job.name
end

function getPlayerSex(s)
    s = tonumber(s)
    local xPlayer = ESX.GetPlayerFromId(s)
    if not xPlayer then return 'male' end
    return xPlayer.get('sex') == 'm' and 'male' or 'female'
end
