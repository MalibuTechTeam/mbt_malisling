-- ─────────────────────────────────────────────────────────────────────────────
-- Low Ready (chest carry)
-- Toggles a slung LONG GUN between back and a "low ready" chest sling by re-attaching
-- the existing prop. With Transition.Enabled the swap is CHOREOGRAPHED (anim + prop
-- re-parented back → hand → chest in sync). Nearby players get the plain final
-- placement (no frame-synced choreography) to avoid desync.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.LowReady then return end   -- always register the keybind; Enabled is live-checked in toggle()

local cfg = MBT.LowReady
local tr  = cfg.Transition or { Enabled = false }

-- [propType] = true while that type is in low-ready (chest) for the LOCAL player.
local lowReady = {}
local busy       = false  -- a transition sequence is running
local lastToggle = 0      -- client toggle debounce (>= server rate-limit, avoids remote desync)

local function pedSexKey(ped)
    return IsPedMale(ped) and 'male' or 'female'
end

local function attachAt(prop, ped, bone, pos, rot, isPed, rotOrder, fixedRot)
    local boneIndex = GetPedBoneIndex(ped, bone)
    AttachEntityToEntity(prop, ped, boneIndex,
        pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, rot.x + 0.0, rot.y + 0.0, rot.z + 0.0,
        true, true, false, isPed and true or false, rotOrder or 2,
        fixedRot ~= false)
end

local function placeChest(prop, ped, propType)
    local p = cfg.Position[propType]
    if p then attachAt(prop, ped, p.Bone, p.Pos, p.Rot, p.isPed, p.RotOrder, p.FixedRot) end
end

--- Per-sex chest-stance attach info for `propType`, or nil if not low-ready; shaped like getAttachInfo's return so the core spawn path re-slings straight to the chest with no back→chest snap.
function MBT.GetLowReadyOverride(propType)
    if not cfg.Enabled or not lowReady[propType] then return nil end
    local p = cfg.Position and cfg.Position[propType]
    if not p then return nil end
    return { Bone = p.Bone, isPed = p.isPed, RotOrder = p.RotOrder, FixedRot = p.FixedRot,
             Pos = { male = p.Pos, female = p.Pos }, Rot = { male = p.Rot, female = p.Rot } }
end

local function placeBack(prop, ped, propType)
    local info = GetResolvedPropInfo(propType)
    if not info then return end
    local sex = pedSexKey(ped)
    attachAt(prop, ped, info.Bone, info.Pos[sex], info.Rot[sex],
        info.isPed, info.RotOrder, info.FixedRot)
end

local function placeHand(prop, ped)
    attachAt(prop, ped, tr.HandBone or 57005, tr.HandOffset.Pos, tr.HandOffset.Rot, false, 2, true)
end

--- Snap the prop to a named spot.
local function placeAt(prop, ped, propType, where)
    if where == 'hand' then placeHand(prop, ped)
    elseif where == 'chest' then placeChest(prop, ped, propType)
    else placeBack(prop, ped, propType) end
end

--- Choreographed step list: play each clip and snap the prop mid-clip; mask=true hides the prop until it snaps, masking the back→hand teleport so the weapon "appears" in hand instead of sliding across the body.
local function runSequence(prop, ped, propType, steps)
    for i = 1, #steps do
        local s = steps[i]
        lib.requestAnimDict(s.dict)
        TaskPlayAnim(ped, s.dict, s.anim, 8.0, -8.0, s.duration, 48, 0.0, false, false, false)
        -- Real speed control: TaskPlayAnim's 8th arg is START phase, not speed.
        if s.speed then SetEntityAnimSpeed(ped, s.dict, s.anim, s.speed) end
        if s.mask then SetEntityVisible(prop, false, false) end
        local placed = false
        local elapsed = 0
        while elapsed < s.duration do
            if not placed and elapsed >= (s.placeAt or 0) then
                placeAt(prop, ped, propType, s.place)
                if s.mask then SetEntityVisible(prop, true, false) end
                placed = true
            end
            Wait(0)
            elapsed = elapsed + GetFrameTime() * 1000
        end
        if not placed then
            placeAt(prop, ped, propType, s.place)
            if s.mask then SetEntityVisible(prop, true, false) end
        end
    end
    -- Safety: never leave the prop invisible.
    if DoesEntityExist(prop) then SetEntityVisible(prop, true, false) end
    ClearPedTasks(ped)
end

--- Local toggle. Finds the first eligible slung long gun and swaps it.
local function toggle()
    if busy or not cfg.Enabled then return end   -- Enabled is live-toggled from the dashboard
    local now = GetGameTimer()
    if now - lastToggle < 200 then return end     -- debounce: with transitions off there's no busy lock,
    lastToggle = now                              -- and the server drops events <150ms apart → desync

    local targetType, prop
    for propType in pairs(cfg.Types) do
        if cfg.Types[propType] then
            local ent = GetLocalSlungProp(propType)
            if ent then targetType, prop = propType, ent break end
        end
    end
    if not targetType then
        MBT.NotifyLabel('low_ready_none')
        return
    end

    local goChest = not lowReady[targetType]
    lowReady[targetType] = goChest or nil
    TriggerServerEvent('mbt_malisling:syncLowReady', targetType, goChest)

    if tr.Enabled then
        busy = true
        local steps = goChest and tr.ToChest or tr.ToBack
        runSequence(prop, cache.ped, targetType, steps)
        busy = false
    else
        placeAt(prop, cache.ped, targetType, goChest and 'chest' or 'back')
    end
end

RegisterCommand(cfg.Command, toggle, false)
RegisterKeyMapping(cfg.Command, '[MBT] Toggle low ready (chest carry)', 'keyboard', cfg.Key)

-- Nearby players: plain final placement (no choreography) on the prop we hold.
RegisterNetEvent('mbt_malisling:remoteLowReady', function(srcPlayer, propType, chest)
    local pid = GetPlayerFromServerId(srcPlayer)
    if pid == -1 then return end   -- unstreamed source: GetPlayerPed(-1) would resolve to OUR ped
    local ped = GetPlayerPed(pid)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local prop = playersToTrack[srcPlayer] and playersToTrack[srcPlayer][propType]
    if type(prop) ~= 'number' or not DoesEntityExist(prop) then return end
    placeAt(prop, ped, propType, chest and 'chest' or 'back')
end)

-- Persist chest stance across a draw: when the slung prop reappears (re-slung after
-- being drawn) the core re-attaches it on the BACK, so snap it back to chest + re-sync.
-- Flag clears only on explicit toggle, so drawing/holstering keeps the stance.
local wasPresent = {}
CreateThread(function()
    while true do
        Wait(next(lowReady) and 200 or 1000)   -- poll fast only while a chest stance is held
        for propType in pairs(lowReady) do
            local prop = GetLocalSlungProp(propType)
            local present = (prop and DoesEntityExist(prop)) and true or false
            if present and wasPresent[propType] == false and not busy then
                placeChest(prop, cache.ped, propType)
                TriggerServerEvent('mbt_malisling:syncLowReady', propType, true)
            end
            wasPresent[propType] = present
        end
    end
end)

-- Ped/skin change: new body re-slings on the back, so drop stale chest flags.
lib.onCache('ped', function()
    lowReady   = {}
    wasPresent = {}
end)

