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
