-- ─────────────────────────────────────────────────────────────────────────────
-- Pat-down (LEO frisk) — client
--
-- OFFICER: press the frisk key near a person (allowed job, server-checked) → a
-- consent request goes to them. On accept the officer plays a frisk gesture for
-- the search time, then a result card lists the weapons found and how each was
-- carried (visible / concealed / back). TARGET: a key-driven consent pill
-- (E accept / BACKSPACE decline) + a notification that they were frisked.
-- All truth is server-side; this file only drives input, anim and the NUI.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.PatDown then return end

local cfg = MBT.PatDown

-- ── Officer ─────────────────────────────────────────────────────────────────────
local function closestPlayer()
    local pc = GetEntityCoords(cache.ped)
    local best, bestDist = nil, (cfg.MaxDistance or 2.0)
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= cache.ped and DoesEntityExist(ped) then
            local d = #(pc - GetEntityCoords(ped))
            if d < bestDist then best, bestDist = pid, d end
        end
    end
    return best
end

local function startPatdown()
    if not cfg.Enabled or cache.vehicle then return end
    local target = closestPlayer()
    if not target then MBT.NotifyLabel('patdown_no_target') return end
    TriggerServerEvent('mbt_malisling:patdown:request', GetPlayerServerId(target))
end

RegisterCommand('mbtPatdown', startPatdown, false)
RegisterKeyMapping('mbtPatdown', '[MBT] Pat-down nearby person', 'keyboard', cfg.Key or 'Y')

local busy = false

--- Officer runs the frisk: face the target, play the gesture for the search time,
--- then show the result card.
RegisterNetEvent('mbt_malisling:patdown:run', function(data)
    if busy or type(data) ~= 'table' then return end
    busy = true
    local other = GetPlayerPed(GetPlayerFromServerId(data.target or 0))
    if other and other ~= 0 and DoesEntityExist(other) then
        TaskTurnPedToFaceEntity(cache.ped, other, 400)
    end
    local a = cfg.Animation or {}
    if a.CopDict and DoesAnimDictExist(a.CopDict) then
        lib.requestAnimDict(a.CopDict)
        TaskPlayAnim(cache.ped, a.CopDict, a.CopAnim, 4.0, -4.0, data.searchMs or 2000, 49, 0.0, false, false, false)
    end
    Wait(data.searchMs or 2000)
    ClearPedTasks(cache.ped)
    busy = false

    local findings = type(data.findings) == 'table' and data.findings or {}
    if #findings == 0 then
        MBT.NotifyLabel('patdown_none')
        return
    end
    SendNUIMessage({ action = 'showPatdownResult', data = {
        locale   = buildNuiLocale(),
        findings = findings,
    } })
end)

RegisterNetEvent('mbt_malisling:patdown:result', function(d)
    if type(d) == 'table' and type(d.reason) == 'string' then MBT.NotifyLabel(d.reason) end
end)

-- ── Target ──────────────────────────────────────────────────────────────────────
local prompt = nil   -- consent pill up

local function closePrompt(accept)
    if not prompt then return end
    prompt = nil
    SendNUIMessage({ action = 'hidePatdownPrompt', data = {} })
    if accept == nil then return end
    TriggerServerEvent('mbt_malisling:patdown:respond', accept)
end

RegisterNetEvent('mbt_malisling:patdown:prompt', function(data)
    if prompt or type(data) ~= 'table' then return end
    prompt = true
    SendNUIMessage({ action = 'showPatdownPrompt', data = {
        locale = buildNuiLocale(), officer = data.officer,
    } })
    CreateThread(function()
        local deadline = GetGameTimer() + (cfg.RequestTimeoutMs or 8000)
        while prompt do
            Wait(0)
            for _, c in ipairs({ 38, 177, 24, 25 }) do DisableControlAction(0, c, true) end
            if IsDisabledControlJustPressed(0, 38) then closePrompt(true)
            elseif IsDisabledControlJustPressed(0, 177) then closePrompt(false)
            elseif GetGameTimer() > deadline then closePrompt(nil) end
        end
    end)
end)

RegisterNetEvent('mbt_malisling:patdown:expired', function() closePrompt(nil) end)

RegisterNetEvent('mbt_malisling:patdown:searched', function()
    MBT.NotifyLabel('patdown_searched')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and prompt then
        prompt = nil
        SendNUIMessage({ action = 'hidePatdownPrompt', data = {} })
    end
end)
