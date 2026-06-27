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

-- The NUI fetches this lazily when the position editor opens.
lib.callback.register('mbt_malisling:getJobs', function()
    return getAllJobs()
end)
