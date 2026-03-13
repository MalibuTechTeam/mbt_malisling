if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

AddEventHandler('QBCore:Server:PlayerLoaded', function(qbPlayer)
    local s = qbPlayer.PlayerData.source
    playersToTrack[s] = {}
end)

function getPlayerJob(s)
    s = tonumber(s)
    local xPlayer = QBCore.Functions.GetPlayer(s)
    if not xPlayer then return '' end
    return xPlayer.PlayerData.job.name
end

function getPlayerSex(s)
    s = tonumber(s)
    local xPlayer = QBCore.Functions.GetPlayer(s)
    if not xPlayer then return 'male' end
    return xPlayer.PlayerData.charinfo.gender == 0 and 'male' or 'female'
end
