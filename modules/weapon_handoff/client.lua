-- ─────────────────────────────────────────────────────────────────────────────
-- Physical Weapon Handoff — client
-- GIVER: press the key while holding a weapon near another player (closest in
-- reach gets the offer). RECEIVER: key-driven NUI prompt (E accept / BACKSPACE
-- decline). On accept both peds face each other + play a synced give/take gesture.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.Handoff then return end

local cfg = MBT.Handoff

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

local function offerWeapon()
    if not cfg.Enabled or cache.vehicle then return end
    if not CurrentWeapon or not CurrentWeapon.name or not CurrentWeapon.slot then return end
    local target = closestPlayer()
    if not target then MBT.NotifyLabel('handoff_no_target') return end
    TriggerServerEvent('mbt_malisling:handoff:offer', {
        target = GetPlayerServerId(target),
        slot   = CurrentWeapon.slot,
        name   = CurrentWeapon.name,
    })
end

RegisterCommand('mbtHandoff', offerWeapon, false)
RegisterKeyMapping('mbtHandoff', '[MBT] Hand weapon to player', 'keyboard', cfg.Key or 'G')

-- ── Receiver prompt (key-driven NUI, no mouse focus) ──────────────────────────────
local offer = nil   -- incoming offer payload while the prompt is up

local function closePrompt(accept)
    if not offer then return end
    offer = nil
    SendNUIMessage({ action = 'hideHandoff', data = {} })
    if accept == nil then return end   -- expired/cancelled: no response to send
    local res = lib.callback.await('mbt_malisling:handoff:respond', false, accept)
    if accept and res and res.ok and not res.declined and cfg.EquipOnAccept then
        if GetResourceState('ox_inventory') == 'started' and res.equipSlot then
            exports.ox_inventory:useSlot(res.equipSlot)                  -- ox
        elseif GetResourceState('qb-inventory') == 'started' and res.name
            and PlayerData and PlayerData.items then
            -- qb: find the just-received weapon by name(+serial) and use it.
            for _, it in pairs(PlayerData.items) do
                if it.name and it.name:upper() == res.name
                    and (not res.serial or (it.info and it.info.serie == res.serial)) then
                    TriggerServerEvent('qb-inventory:server:useItem', it)
                    break
                end
            end
        end
    end
end

RegisterNetEvent('mbt_malisling:handoff:incoming', function(data)
    if offer or type(data) ~= 'table' then return end
    if not cfg.Enabled then return end
    offer = data
    SendNUIMessage({ action = 'showHandoff', data = {
        locale   = buildNuiLocale(),
        fromName = data.fromName,
        weapon   = data.weapon,
        label    = data.label,
        serial   = data.serial,
        style    = MBT.UIStyle or 'standard',
    } })
    CreateThread(function()
        local deadline = GetGameTimer() + (data.timeoutMs or 8000)
        while offer do
            Wait(0)
            for _, c in ipairs({ 38, 177, 24, 25 }) do DisableControlAction(0, c, true) end
            if IsDisabledControlJustPressed(0, 38) then       -- E → accept
                closePrompt(true)
            elseif IsDisabledControlJustPressed(0, 177) then  -- BACKSPACE → decline
                closePrompt(false)
            elseif GetGameTimer() > deadline then
                closePrompt(nil)                              -- expired locally
            end
        end
    end)
end)

RegisterNetEvent('mbt_malisling:handoff:expired', function()
    closePrompt(nil)
end)

-- ── Synced gesture + giver feedback ───────────────────────────────────────────────
RegisterNetEvent('mbt_malisling:handoff:anim', function(d)
    if type(d) ~= 'table' then return end
    local a = cfg.Animation or {}
    local dict = (d.role == 'give') and (a.GiveDict or 'mp_common') or (a.TakeDict or 'mp_common')
    local anim = (d.role == 'give') and (a.GiveAnim or 'givetake1_a') or (a.TakeAnim or 'givetake2_a')
    local ms   = (d.role == 'give') and (a.GiveMs or 900) or (a.TakeMs or 900)

    local other = GetPlayerPed(GetPlayerFromServerId(d.other or 0))
    if other and other ~= 0 and DoesEntityExist(other) then
        TaskTurnPedToFaceEntity(cache.ped, other, 400)
        Wait(400)
    end
    if DoesAnimDictExist(dict) then
        lib.requestAnimDict(dict)
        TaskPlayAnim(cache.ped, dict, anim, 4.0, -4.0, ms, 49, 0.0, false, false, false)
        Wait(ms)
        ClearPedTasks(cache.ped)
    end
end)

RegisterNetEvent('mbt_malisling:handoff:result', function(labelKey)
    if type(labelKey) == 'string' then MBT.NotifyLabel(labelKey) end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and offer then
        offer = nil
        SendNUIMessage({ action = 'hideHandoff', data = {} })
    end
end)
