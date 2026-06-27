-- ─────────────────────────────────────────────────────────────────────────────
-- Showcase Poses — static display poses (screenshots / gunshops / RP markets).
-- Command enters a looped idle pose; re-running cycles, /pose <n> jumps. Moving,
-- shooting or entering a vehicle exits. Local-only/cosmetic (props already sync).
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the block exists; Enabled checked at use time (live-apply via menu).
if not MBT.ShowcasePoses then return end

local cfg   = MBT.ShowcasePoses
local poses = cfg.Poses or {}

local posing  = false
local current = 0   -- index of the active pose

--- Play a pose anim on a ped (local or remote). Best-effort: a remote pose can be
--- interrupted by GTA's own state machine, so never block on it.
local function applyPose(ped, p)
    if not p or not DoesAnimDictExist(p.dict) then return end
    lib.requestAnimDict(p.dict)
    TaskPlayAnim(ped, p.dict, p.anim, 4.0, -4.0, -1, p.flag or 1, 0.0, false, false, false)
end

--- Push the pose HUD (active pose name + index + controls).
local function showHud()
    SendNUIMessage({ action = 'showPose', data = {
        name   = poses[current] and poses[current].label or '—',
        index  = current,
        total  = #poses,
        locale = buildNuiLocale(),
    } })
end

local function stopPose()
    if not posing then return end
    posing = false
    ClearPedTasks(cache.ped)
    SendNUIMessage({ action = 'hidePose', data = {} })
    if cfg.Sync then TriggerServerEvent('mbt_malisling:setShowcasePose', false) end
end

--- Switch to pose index n (wraps) and refresh anim + HUD + sync. Stays in mode.
local function switchTo(n)
    if #poses == 0 then return end
    current = (n - 1) % #poses + 1
    applyPose(cache.ped, poses[current])
    showHud()
    if cfg.Sync then TriggerServerEvent('mbt_malisling:setShowcasePose', current) end
end

--- Enter pose mode at index n.
local function startPose(n)
    if not cfg.Enabled then return end
    if cache.vehicle then MBT.NotifyLabel('pose_in_vehicle'); return end
    if not poses[n] then return end
    if not DoesAnimDictExist(poses[n].dict) then
        Utils.mbtWarn('showcase_poses ~ missing dict: ' .. tostring(poses[n].dict))
        return
    end

    switchTo(n)

    if not posing then
        posing = true
        -- Pose-mode loop: ← → cycle, BACKSPACE exits, plus the auto-exit on
        -- movement/shoot/vehicle. Runs each frame only while posing.
        CreateThread(function()
            Wait(300)  -- grace so the entering keypress doesn't instantly exit
            while posing do
                DisableControlAction(0, 174, true)  -- arrow left  (INPUT_CELLPHONE_LEFT)
                DisableControlAction(0, 175, true)  -- arrow right (INPUT_CELLPHONE_RIGHT)
                DisableControlAction(0, 177, true)  -- backspace   (INPUT_CELLPHONE_CANCEL)
                if IsDisabledControlJustPressed(0, 175) then
                    switchTo(current + 1)
                elseif IsDisabledControlJustPressed(0, 174) then
                    switchTo(current - 1)
                elseif IsDisabledControlJustPressed(0, 177) then
                    stopPose(); break
                elseif cache.vehicle or IsPedShooting(cache.ped)
                    or GetEntitySpeed(cache.ped) > 0.5
                    or IsPedRagdoll(cache.ped) or IsEntityDead(cache.ped) then
                    stopPose(); break
                end
                Wait(0)
            end
        end)
    end
end

RegisterCommand(cfg.Command, function(_, args)
    local n = tonumber(args[1])
    if n then
        startPose(n)                  -- /pose <n> → specific pose
    elseif posing then
        switchTo(current + 1)         -- already posing → cycle to next
    else
        startPose(1)                  -- first call → first pose
    end
end, false)

if cfg.Key and cfg.Key ~= '' then
    RegisterKeyMapping(cfg.Command, '[MBT] Showcase pose', 'keyboard', cfg.Key)
end

-- Remote players' poses (group photos + late-join): the statebag fires for every
-- client, including ones streaming the poser in AFTER the pose started, so the ped
-- replays it. Skip our own player (handled locally above).
if cfg.Sync then
    AddStateBagChangeHandler('mbt_showcasePose', nil, function(bagName, _, value)
        local player = GetPlayerFromStateBagName(bagName)
        if player == 0 or player == PlayerId() then return end
        local ped = GetPlayerPed(player)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end
        if value then
            applyPose(ped, poses[value])
        else
            ClearPedTasks(ped)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then stopPose() end
end)
