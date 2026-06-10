if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

AddEventHandler('ox:playerLoaded', function(source, userid, charid)
    playersToTrack[source] = {}
end)

function getPlayerJob(s)
    s = tonumber(s)
    local player = Ox.GetPlayer(s)
    if not player then return '' end
    local groups = player.getGroups()
    if not groups then return '' end
    for k in pairs(groups) do return k end
    return ''
end

function getPlayerSex(s)
    s = tonumber(s)
    local player = Ox.GetPlayer(s)
    if not player then return 'male' end
    return player.get('gender') or 'male'
end

--- Character name + stable id (for Chain of Custody).
---@return string name, string id
function getPlayerName(s)
    s = tonumber(s)
    local player = Ox.GetPlayer(s)
    if not player then return GetPlayerName(s) or ('Player ' .. tostring(s)), tostring(s) end
    local first = player.firstName or player.get('firstName') or ''
    local last  = player.lastName or player.get('lastName') or ''
    local name  = (first .. ' ' .. last):match('^%s*(.-)%s*$')
    if not name or name == '' then name = GetPlayerName(s) or ('Player ' .. tostring(s)) end
    return name, tostring(player.charId or player.userId or s)
end
