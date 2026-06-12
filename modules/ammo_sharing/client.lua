-- ─────────────────────────────────────────────────────────────────────────────
-- Ammo Sharing — client
--
-- Press the share key while holding a weapon near another player to offer them a
-- portion of your ammo. The receiver gets a key-driven prompt (reuses the
-- Handoff pill NUI) and, on accept, both play a synced give/take gesture while
-- the server moves the ammo item. Mirrors the weapon-handoff flow.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.AmmoSharing then return end

local cfg = MBT.AmmoSharing

local CurrentWeapon = {}
AddEventHandler('ox_inventory:currentWeapon', function(w) CurrentWeapon = w or {} end)

-- ── Giver ───────────────────────────────────────────────────────────────────────
local function closestPlayer()
    local pc = GetEntityCoords(cache.ped)
    local best, bestDist = nil, (cfg.MaxDistance or 2.5)
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= cache.ped and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
            local d = #(pc - GetEntityCoords(ped))
            if d < bestDist then best, bestDist = pid, d end
        end
    end
    return best
end

local function shareAmmo()
    if not cfg.Enabled or cache.vehicle then return end
    local target = closestPlayer()
    if not target then MBT.NotifyLabel('ammo_no_target') return end
    TriggerServerEvent('mbt_malisling:ammo:offer', {
        target = GetPlayerServerId(target),
        weapon = CurrentWeapon and CurrentWeapon.name,   -- resolves ammo type server-side
    })
end

RegisterCommand('mbtShareAmmo', shareAmmo, false)
RegisterKeyMapping('mbtShareAmmo', '[MBT] Share ammo with player', 'keyboard', cfg.Key or 'H')

-- ── Receiver prompt (reuses the Handoff pill) ─────────────────────────────────────
local offer = nil

local function closePrompt(accept)
    if not offer then return end
    offer = nil
    SendNUIMessage({ action = 'hideHandoff', data = {} })
    if accept == nil then return end
    lib.callback.await('mbt_malisling:ammo:respond', false, accept)
end

RegisterNetEvent('mbt_malisling:ammo:incoming', function(data)
    if offer or type(data) ~= 'table' or not cfg.Enabled then return end
    offer = data
    SendNUIMessage({ action = 'showHandoff', data = {
        locale   = buildNuiLocale(),
        fromName = data.fromName,
        weapon   = 'AMMO',
        -- Reuse the Handoff pill's bold slot for the rounds line.
        label    = ('%d× %s'):format(data.amount or 0, Translate('ammo_rounds')),
    } })
    CreateThread(function()
        local deadline = GetGameTimer() + (data.timeoutMs or 8000)
        while offer do
            Wait(0)
            for _, c in ipairs({ 38, 177, 24, 25 }) do DisableControlAction(0, c, true) end
            if IsDisabledControlJustPressed(0, 38) then closePrompt(true)
            elseif IsDisabledControlJustPressed(0, 177) then closePrompt(false)
            elseif GetGameTimer() > deadline then closePrompt(nil) end
        end
    end)
end)

RegisterNetEvent('mbt_malisling:ammo:expired', function() closePrompt(nil) end)

RegisterNetEvent('mbt_malisling:ammo:anim', function(d)
    if type(d) ~= 'table' then return end
    local a = cfg.Animation or {}
    local dict = (d.role == 'give') and (a.GiveDict or 'mp_common') or (a.TakeDict or 'mp_common')
    local anim = (d.role == 'give') and (a.GiveAnim or 'givetake1_a') or (a.TakeAnim or 'givetake2_a')
    local ms   = (d.role == 'give') and (a.GiveMs or 900) or (a.TakeMs or 900)
    local other = GetPlayerPed(GetPlayerFromServerId(d.other or 0))
    if other and other ~= 0 and DoesEntityExist(other) then
        TaskTurnPedToFaceEntity(cache.ped, other, 400); Wait(400)
    end
    if DoesAnimDictExist(dict) then
        lib.requestAnimDict(dict)
        TaskPlayAnim(cache.ped, dict, anim, 4.0, -4.0, ms, 49, 0.0, false, false, false)
        Wait(ms); ClearPedTasks(cache.ped)
    end
end)

RegisterNetEvent('mbt_malisling:ammo:result', function(labelKey)
    if type(labelKey) == 'string' then MBT.NotifyLabel(labelKey) end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and offer then
        offer = nil
        SendNUIMessage({ action = 'hideHandoff', data = {} })
    end
end)
