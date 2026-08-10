-- ─────────────────────────────────────────────────────────────────────────────
-- Jobs bridge — server. Enumerates framework jobs/groups into a flat list
-- { { name='police', label='Police' }, ... } for the NUI per-job position editor.
-- Framework detected at runtime.
-- ─────────────────────────────────────────────────────────────────────────────

local function started(res) return GetResourceState(res) == 'started' end

local function pushJobs(src, list)
    for name, data in pairs(src or {}) do
        if type(name) == 'string' and name ~= '' then
            list[#list + 1] = { name = name, label = (type(data) == 'table' and data.label) or name }
        end
    end
end

--- Normalized job list across ESX / QB-Core / QBox / OX-Core. Empty if none.
---@return { name: string, label: string }[]
function getAllJobs()
    local list = {}

    if started('es_extended') then
        local ESX = exports.es_extended:getSharedObject()
        if ESX and ESX.GetJobs then pushJobs(ESX.GetJobs(), list) end

    elseif started('qbx_core') then
        local ok, jobs = pcall(function() return exports.qbx_core:GetJobs() end)
        if ok then pushJobs(jobs, list) end

    elseif started('qb-core') then
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore and QBCore.Shared then pushJobs(QBCore.Shared.Jobs, list) end

    elseif started('ox_core') then
        pushJobs(GlobalState['ox:groups'], list)
    end

    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

--- Does the player hold any job in `allowed` (a set keyed by job name)?
--- Use this instead of `allowed[getPlayerJob(src)]`: on ox_core a player can be in
--- several groups at once and `getPlayerJob` has to pick one of them, so the direct
--- lookup answers "is their arbitrarily-chosen group in the list", which is not the
--- question anyone is asking. One framework call, then a lookup per allowed job.
---@param s number|string
---@param allowed table<string, boolean>?
---@return boolean
function playerHasAnyJob(s, allowed)
    if type(allowed) ~= 'table' then return false end
    local held = getPlayerJobs(s)
    for name, on in pairs(allowed) do
        if on and held[name] then return true end
    end
    return false
end

--- Does the player hold this exact job?
---@param s number|string
---@param name string?
---@return boolean
function playerHasJob(s, name)
    if type(name) ~= 'string' or name == '' then return false end
    return getPlayerJobs(s)[name] == true
end

-- The NUI fetches this lazily when the position editor opens.
lib.callback.register('mbt_malisling:getJobs', function()
    return getAllJobs()
end)
