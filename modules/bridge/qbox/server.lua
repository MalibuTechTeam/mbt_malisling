if GetResourceState('qbx_core') ~= 'started' then return end

AddEventHandler('QBCore:Server:PlayerLoaded', function(qbPlayer)
    local s = qbPlayer.PlayerData.source
    playersToTrack[s] = {}
end)

function getPlayerJob(s)
    s = tonumber(s)
    local xPlayer = exports['qbx_core']:GetPlayer(s)
    if not xPlayer then return '' end
    return xPlayer.PlayerData.job.name
end

--- Jobs as a set, mirroring the ox_core bridge — always zero or one entry (QBox has one job per player).
---@param s number|string
---@return table<string, true>
function getPlayerJobs(s)
    local job = getPlayerJob(s)
    return job ~= '' and { [job] = true } or {}
end

function getPlayerSex(s)
    s = tonumber(s)
    local xPlayer = exports['qbx_core']:GetPlayer(s)
    if not xPlayer then return 'male' end
    return xPlayer.PlayerData.charinfo.gender == 0 and 'male' or 'female'
end

--- Character name + stable id (for Chain of Custody).
---@return string name, string id
function getPlayerName(s)
    s = tonumber(s)
    local xPlayer = exports['qbx_core']:GetPlayer(s)
    if not xPlayer then return GetPlayerName(s) or ('Player ' .. tostring(s)), tostring(s) end
    local ci = xPlayer.PlayerData.charinfo or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):match('^%s*(.-)%s*$')
    if not name or name == '' then name = GetPlayerName(s) or ('Player ' .. tostring(s)) end
    return name, xPlayer.PlayerData.citizenid or tostring(s)
end

--- Framework-native usable item registration (cb receives the player source); on ox_inventory the item's server.export path is used instead.
function registerUsableItem(name, cb)
    exports.qbx_core:CreateUseableItem(name, function(source) cb(source) end)
end
