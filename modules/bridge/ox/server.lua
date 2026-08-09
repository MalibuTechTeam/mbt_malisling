if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

AddEventHandler('ox:playerLoaded', function(source, userid, charid)
    playersToTrack[source] = {}
end)

--- Every group the player belongs to, as a set. ox_core is the only framework here that
--- can put someone in several at once, which is why this exists: `getPlayerJob` has to
--- pick ONE, and picking one out of several is a guess whichever way you do it.
---@param s number|string
---@return table<string, true>
function getPlayerJobs(s)
    s = tonumber(s)
    local player = Ox.GetPlayer(s)
    if not player then return {} end
    local groups = player.getGroups()
    if not groups then return {} end
    local set = {}
    for name in pairs(groups) do set[name] = true end
    return set
end

--- Single job name. Prefer `getPlayerJobs` for "is this player a cop?" questions.
--- Sorted pick, not `next()`: with more than one group the choice is arbitrary either
--- way, but an arbitrary STABLE answer can be reported and reproduced, while
--- `for k in pairs(groups) do return k end` returned a different group run to run and
--- made job checks fail at random on ox_core.
---@param s number|string
---@return string
function getPlayerJob(s)
    local names = {}
    for name in pairs(getPlayerJobs(s)) do names[#names+1] = name end
    if #names == 0 then return '' end
    table.sort(names)
    return names[1]
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
