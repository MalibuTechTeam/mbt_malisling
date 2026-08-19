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

--- Jobs as a set, mirroring the ox_core bridge — always zero or one entry (ESX has one job per player).
---@param s number|string
---@return table<string, true>
function getPlayerJobs(s)
    local job = getPlayerJob(s)
    return job ~= '' and { [job] = true } or {}
end

function getPlayerSex(s)
    s = tonumber(s)
    local xPlayer = ESX.GetPlayerFromId(s)
    if not xPlayer then return 'male' end
    return xPlayer.get('sex') == 'm' and 'male' or 'female'
end

--- Character name + stable id (for Chain of Custody).
---@return string name, string id
function getPlayerName(s)
    s = tonumber(s)
    local xPlayer = ESX.GetPlayerFromId(s)
    if not xPlayer then return GetPlayerName(s) or ('Player ' .. tostring(s)), tostring(s) end
    local name = (xPlayer.getName and xPlayer.getName()) or GetPlayerName(s) or ('Player ' .. tostring(s))
    return name, xPlayer.identifier or tostring(s)
end

--- Framework-native usable item registration (cb receives the player source); on ox_inventory the item's server.export path is used instead.
function registerUsableItem(name, cb)
    ESX.RegisterUsableItem(name, function(source) cb(source) end)
end
