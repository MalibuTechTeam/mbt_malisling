-- ─────────────────────────────────────────────────────────────────────────────
-- Showcase Poses
--
-- Static display poses to show off the player and their slung weapons (for
-- screenshots / gunshop windows / RP markets). The command enters a looped idle
-- pose; running it again cycles to the next pose, /pose <n> jumps to a specific
-- one. Moving, shooting or entering a vehicle exits. Local-only and cosmetic —
-- the slung props are already visible to others through the scope system.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ShowcasePoses or not MBT.ShowcasePoses.Enabled then return end

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

local function stopPose()
    if not posing then return end
    posing = false
    ClearPedTasks(cache.ped)
    if cfg.Sync then TriggerServerEvent('mbt_malisling:setShowcasePose', false) end
end

--- Enter (or switch to) pose index n.
local function startPose(n)
    local p = poses[n]
    if not p then return end
    current = n

    if cache.vehicle then
        MBT.NotifyLabel('pose_in_vehicle')
        return
    end

    if not DoesAnimDictExist(p.dict) then
        Utils.mbtWarn('showcase_poses ~ missing dict: ' .. tostring(p.dict))
        return
    end
    applyPose(cache.ped, p)
    if cfg.Sync then TriggerServerEvent('mbt_malisling:setShowcasePose', n) end

    if not posing then
        posing = true
        -- Exit watcher: leave the pose the moment it stops making sense.
        CreateThread(function()
            -- Small grace so the keypress that started the pose doesn't instantly
            -- trip the movement check.
            Wait(300)
            while posing do
                if cache.vehicle
                    or IsPedShooting(cache.ped)
                    or GetEntitySpeed(cache.ped) > 0.5
                    or IsPedRagdoll(cache.ped)
                    or IsEntityDead(cache.ped) then
                    stopPose()
                    break
                end
                Wait(150)
            end
        end)
    end
end

RegisterCommand(cfg.Command, function(_, args)
    local n = tonumber(args[1])
    if n then
        startPose(n)                      -- /pose <n> → specific pose
    elseif posing then
        local nextIdx = current % #poses + 1
        startPose(nextIdx)                -- already posing → cycle to next
    else
        startPose(1)                      -- first call → first pose
    end
end, false)

if cfg.Key and cfg.Key ~= '' then
    RegisterKeyMapping(cfg.Command, '[MBT] Showcase pose', 'keyboard', cfg.Key)
end

-- Remote players' poses (group photos + late-join). The statebag fires for every
-- client — including those who stream the poser in AFTER the pose started — so
-- their ped replays it. We skip our own player (handled by the local logic above).
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
