-- ─────────────────────────────────────────────────────────────────────────────
-- Vehicle Trunk Weapon Rack — client
--
-- Realistic stow/retrieve of a long gun in a vehicle's trunk:
--   • ox_target option on the boot (bone-limited), gated to on-foot + long gun.
--   • Boot physically opens, a "place/take" anim plays, the weapon prop appears
--     racked in the trunk (synced to everyone via the vehicle statebag), boot shuts.
-- Persistence + validation are server-authoritative (server.lua). This file only
-- drives the interaction, animation, and renders the synced props.
--
-- ox_target is a soft dependency; without it a proximity [E] prompt is used.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.VehicleTrunkRack then return end

local cfg = MBT.VehicleTrunkRack
local DEFAULT_OFFSET = { Pos = { x = 0.0, y = -0.10, z = -0.30 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } }

local CurrentWeapon = {}
local busy          = false
local rackedProps   = {}  -- [veh] = { [index] = propEntity }

AddEventHandler('ox_inventory:currentWeapon', function(w) CurrentWeapon = w or {} end)

-- ── Helpers ────────────────────────────────────────────────────────────────────
local function holdingLongGun()
    local name = CurrentWeapon and CurrentWeapon.name
    if not name then return false end
    local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]
    local t = w and w.type
    return t and cfg.AllowedTypes and cfg.AllowedTypes[t] or false
end

local function rackList(veh)
    local s = Entity(veh).state.mbt_trunkRack
    return (type(s) == 'table') and s or nil
end

local function rackCount(veh)
    local s = rackList(veh)
    return s and #s or 0
end

local function bootBone(veh)
    local b = GetEntityBoneIndexByName(veh, 'boot')
    if b == -1 then b = GetEntityBoneIndexByName(veh, 'bootlid') end
    return b
end

local function openBoot(veh)
    if NetworkGetEntityIsNetworked(veh) and not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local deadline = GetGameTimer() + 600
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < deadline do Wait(50) end
    end
    SetVehicleDoorOpen(veh, 5, false, false)   -- door 5 = boot
end

local function shutBoot(veh)
    if DoesEntityExist(veh) then SetVehicleDoorShut(veh, 5, false) end
end

local function playAnim(dict, name, ms)
    ms = ms or 1500
    if not dict or dict == '' or not name or name == '' or not DoesAnimDictExist(dict) then Wait(ms); return end
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, name, 4.0, -4.0, ms, 49, 0.0, false, false, false)
    Wait(ms)
    ClearPedTasks(cache.ped)
end

-- ── Stow / Retrieve flows ────────────────────────────────────────────────────────
local function doStow(veh)
    if busy or not cfg.Enabled or not veh or veh == 0 then return end
    if cache.vehicle or not holdingLongGun() then return end
    if GetEntitySpeed(veh) > 1.0 then return end
    busy = true

    local slot  = CurrentWeapon.slot
    local netId = VehToNet(veh)
    local a     = cfg.Animation or {}

    openBoot(veh)
    Wait(a.BootOpenDelayMs or 350)
    local res = lib.callback.await('mbt_malisling:trunkRack:stow', false, { netId = netId, slot = slot })
    -- Anim blocking so the boot stays open for the whole placement (props show while open).
    playAnim(a.PlaceDict, a.PlaceAnim, a.PlaceMs)
    Wait(200)
    shutBoot(veh)
    busy = false

    if not res or not res.ok then
        if res and res.reason then MBT.NotifyLabel(res.reason) end
    end
end

local function retrieveIndex(veh, index)
    if busy or not cfg.Enabled or not veh or veh == 0 then return end
    if GetEntitySpeed(veh) > 1.0 then return end
    busy = true

    local netId = VehToNet(veh)
    local a     = cfg.Animation or {}

    openBoot(veh)
    Wait(a.BootOpenDelayMs or 350)
    local res = lib.callback.await('mbt_malisling:trunkRack:retrieve', false, { netId = netId, index = index })
    playAnim(a.TakeDict, a.TakeAnim, a.TakeMs)
    Wait(200)
    shutBoot(veh)
    busy = false

    if not res or not res.ok then
        if res and res.reason then MBT.NotifyLabel(res.reason) end
    end
end

local function doRetrieve(veh)
    local list = rackList(veh)
    if not list or #list == 0 then return end
    if #list == 1 then
        retrieveIndex(veh, 1)
        return
    end
    -- More than one racked: let the player pick which.
    local options = {}
    for i, e in ipairs(list) do
        options[#options + 1] = {
            title    = e.weapon,
            icon     = 'fa-solid fa-gun',
            onSelect = function() retrieveIndex(veh, i) end,
        }
    end
    lib.registerContext({ id = 'mbt_trunk_pick', title = Translate('trunk_retrieve'), options = options })
    lib.showContext('mbt_trunk_pick')
end

-- ── Statebag-driven rack: render the props ONLY while the boot is OPEN ─────────
-- The weapon is only visible with the trunk open (realistic, and it sidesteps
-- per-vehicle offset perfection — a closed sedan trunk hides it anyway). rackedData
-- mirrors the bag; a loop spawns/despawns the props as the boot opens/closes.
local rackedData = {}   -- [veh] = list of { weapon, wtype }

local function clearProps(veh)
    local r = rackedProps[veh]
    if not r then return end
    for _, p in pairs(r.props) do if p and DoesEntityExist(p) then DeleteEntity(p) end end
    rackedProps[veh] = nil
end

local function bootIsOpen(veh)
    return GetVehicleDoorAngleRatio(veh, 5) > 0.8   -- door 5 = boot; fully open avoids the open-swing slide
end

-- Live dev tuner state (/mbt_trunktune) — overrides the offset for one vehicle.
local tuning = nil   -- { veh, class, off }

--- Offset for this vehicle: live tuner > per-MODEL > per-class > default.
--- Per-model is the precise tier (each vehicle exact), tuned with /mbt_trunktune.
local function offsetFor(veh)
    if tuning and tuning.veh == veh then return tuning.off end
    local po = cfg.PropOffset or {}
    local model = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or '')
    return (po.ByModel and po.ByModel[model])
        or (po.ByClass and po.ByClass[GetVehicleClass(veh)])
        or po.Default or DEFAULT_OFFSET
end

--- Anchor on the 'boot' bone — it sits at the trunk, so the prop is VISIBLE and easy
--- to tune there (body-space bone 0 placed it inside/under the car = invisible). The
--- boot bone is the lid, so its open height varies per vehicle → tune per MODEL with
--- /mbt_trunktune. The slide while the lid swings is avoided by only rendering once the
--- boot is FULLY open (see bootIsOpen). bone 0 fallback for vehicles with no boot bone.
local function anchorFor(veh)
    local off = offsetFor(veh)
    local bone = GetEntityBoneIndexByName(veh, 'boot')
    if bone == -1 then bone = 0 end
    return bone, off.Pos.x, off.Pos.y, off.Pos.z, off.Rot
end

local function renderRack(veh)
    clearProps(veh)
    local list = rackedData[veh]
    if not list or #list == 0 or not DoesEntityExist(veh) then return end
    local bone, ox, oy, oz, rot = anchorFor(veh)
    local props = {}
    for i, e in ipairs(list) do
        local hash = joaat(e.weapon)
        if hash and hash ~= 0 then
            lib.requestWeaponAsset(hash, 1000, 31, 1)
            local obj = CreateWeaponObject(hash, 50, 0.0, 0.0, 0.0, true, 1.0, 0)
            if obj and DoesEntityExist(obj) then
                SetEntityCollision(obj, false, false)
                AttachEntityToEntity(obj, veh, bone,
                    ox, oy, oz + (i - 1) * 0.08,   -- stack multiples
                    rot.x, rot.y, rot.z,
                    false, false, false, false, 2, true)
                props[i] = obj
            end
        end
    end
    rackedProps[veh] = { props = props, count = #list }
end

AddStateBagChangeHandler('mbt_trunkRack', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    if not veh or veh == 0 then return end
    if type(value) == 'table' and #value > 0 then
        rackedData[veh] = value
    else
        rackedData[veh] = nil
        clearProps(veh)
    end
end)

-- Show props only while the boot is open; refresh on rack change; drop gone vehicles.
CreateThread(function()
    while true do
        Wait(300)
        for veh, list in pairs(rackedData) do
            if not DoesEntityExist(veh) then
                clearProps(veh); rackedData[veh] = nil
            else
                local r = rackedProps[veh]
                if bootIsOpen(veh) then
                    if not r or r.count ~= #list then renderRack(veh) end
                elseif r then
                    clearProps(veh)
                end
            end
        end
    end
end)

-- Re-publish racks for the closest vehicle (covers respawned vehicles whose bag
-- the server hasn't pushed since the restart). Debounced per net id.
CreateThread(function()
    local queried = {}
    local nextClear = GetGameTimer() + 60000
    while true do
        Wait(1500)
        if cfg.Enabled and not cache.vehicle then
            local now = GetGameTimer()
            if now > nextClear then queried = {}; nextClear = now + 60000 end
            local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0, false)
            if veh and veh ~= 0 and Entity(veh).state.mbt_trunkRack == nil then
                local netId = VehToNet(veh)
                if not queried[netId] then
                    queried[netId] = true
                    lib.callback.await('mbt_malisling:trunkRack:getRack', false, netId)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh in pairs(rackedProps) do clearProps(veh) end
end)

-- ── Prop-offset overrides (DB-persisted, broadcast by the server) ─────────────────
local function applyTrunkOffset(scope, data)
    local po = cfg.PropOffset or {}
    cfg.PropOffset = po
    po.ByClass = po.ByClass or {}
    po.ByModel = po.ByModel or {}
    local kind, key = (scope or ''):match('^(%a+):(.+)$')
    if kind == 'class' then po.ByClass[tonumber(key)] = data or nil
    elseif kind == 'model' then po.ByModel[key] = data or nil end
end

RegisterNetEvent('mbt_malisling:trunkOffset:apply', function(p)
    if type(p) ~= 'table' then return end
    applyTrunkOffset(p.scope, (type(p.data) == 'table') and p.data or nil)
end)

-- Pull existing overrides on (re)start / join.
CreateThread(function()
    local list = lib.callback.await('mbt_malisling:getTrunkOffsets', false)
    if type(list) == 'table' then
        for _, e in ipairs(list) do applyTrunkOffset(e.scope, e.data) end
    end
end)

-- NUI (admin menu) — list + reset the saved overrides.
RegisterNUICallback('trunkOffsets:get', function(_, cb)
    cb(lib.callback.await('mbt_malisling:getTrunkOffsets', false) or {})
end)
RegisterNUICallback('trunkOffsets:reset', function(data, cb)
    if type(data) == 'table' and type(data.scope) == 'string' then
        TriggerServerEvent('mbt_malisling:trunkOffset:reset', { scope = data.scope })
    end
    cb({})
end)

-- ── Interaction (ox_target preferred, [E] fallback) ──────────────────────────────
if GetResourceState('ox_target') == 'started' then
    exports.ox_target:addGlobalVehicle({
        {
            name        = 'mbt_trunk_stow',
            icon        = 'fa-solid fa-box-archive',
            label       = Translate('trunk_stow'),
            bones       = { 'boot', 'bootlid' },
            distance    = (cfg.InteractionDistance or 2.5),
            canInteract = function(entity)
                return cfg.Enabled and not cache.vehicle and holdingLongGun()
                    and rackCount(entity) < (cfg.Capacity or 2)
            end,
            onSelect = function(data) doStow(data.entity) end,
        },
        {
            name        = 'mbt_trunk_retrieve',
            icon        = 'fa-solid fa-hand',
            label       = Translate('trunk_retrieve'),
            bones       = { 'boot', 'bootlid' },
            distance    = (cfg.InteractionDistance or 2.5),
            canInteract = function(entity)
                return cfg.Enabled and not cache.vehicle and rackCount(entity) > 0
            end,
            onSelect = function(data) doRetrieve(data.entity) end,
        },
        {
            -- Open/close the boot so you can actually SEE the racked weapons
            -- (props render only while the trunk is open).
            name        = 'mbt_trunk_view',
            icon        = 'fa-solid fa-eye',
            label       = Translate('trunk_view'),
            bones       = { 'boot', 'bootlid' },
            distance    = (cfg.InteractionDistance or 2.5),
            canInteract = function(entity)
                return cfg.Enabled and not cache.vehicle and rackCount(entity) > 0
            end,
            onSelect = function(data)
                local veh = data.entity
                if bootIsOpen(veh) then
                    SetVehicleDoorShut(veh, 5, false)
                else
                    if NetworkGetEntityIsNetworked(veh) and not NetworkHasControlOfEntity(veh) then
                        NetworkRequestControlOfEntity(veh)
                    end
                    SetVehicleDoorOpen(veh, 5, false, false)
                end
            end,
        },
    })
else
    -- Fallback: [E] prompt at the boot of the closest vehicle.
    CreateThread(function()
        local shown = false
        while true do
            local sleep = 600
            if cfg.Enabled and not cache.vehicle then
                local ped = cache.ped
                local veh = lib.getClosestVehicle(GetEntityCoords(ped), cfg.InteractionDistance or 2.5, false)
                local atBoot = false
                if veh and veh ~= 0 then
                    local bone = bootBone(veh)
                    local bpos = (bone ~= -1) and GetWorldPositionOfEntityBone(veh, bone) or GetEntityCoords(veh)
                    if #(GetEntityCoords(ped) - bpos) < (cfg.InteractionDistance or 2.5) then atBoot = true end
                end
                local canStow     = atBoot and holdingLongGun() and rackCount(veh) < (cfg.Capacity or 2)
                local canRetrieve = atBoot and rackCount(veh) > 0
                if canStow or canRetrieve then
                    sleep = 0
                    local label = canStow and Translate('trunk_stow') or Translate('trunk_retrieve')
                    if not shown then lib.showTextUI('[E] ' .. label); shown = true end
                    if IsControlJustReleased(0, 38) then
                        if canStow then doStow(veh) else doRetrieve(veh) end
                    end
                elseif shown then
                    lib.hideTextUI(); shown = false
                end
            elseif shown then
                lib.hideTextUI(); shown = false
            end
            Wait(sleep)
        end
    end)
end

-- ── Dev tuner: /mbt_trunktune — dial the prop offset live, print the config line ─
-- Stand near a vehicle that has a stowed weapon, run the command. Arrows move,
-- Q/E rotate, SHIFT = bigger step, ENTER prints the per-MODEL config line (paste
-- under PropOffset.ByModel for pixel-perfect placement), BACKSPACE exits. Because
-- you tune with the trunk OPEN, the value bakes in the real open-lid position.
RegisterCommand('mbt_trunktune', function()
    if tuning then return end
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0, false)
    if not veh or veh == 0 or rackCount(veh) == 0 then
        lib.notify({ type = 'inform', description = 'Stand near a vehicle with a stowed weapon, then run /mbt_trunktune.' })
        return
    end
    if NetworkGetEntityIsNetworked(veh) and not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
    end
    SetVehicleDoorOpen(veh, 5, false, false)
    local b = offsetFor(veh)
    tuning = {
        veh = veh, class = GetVehicleClass(veh),
        model = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or '?'),
        off = { Pos = { x = b.Pos.x, y = b.Pos.y, z = b.Pos.z },
                Rot = { x = b.Rot.x, y = b.Rot.y, z = b.Rot.z } },
    }
    renderRack(veh)

    local rotAxis = 'z'   -- which rotation axis Q/E control (R cycles x→y→z)
    CreateThread(function()
        while tuning do
            Wait(0)
            local o = tuning.off
            for _, c in ipairs({ 172, 173, 174, 175, 21, 44, 38, 45, 47, 177, 191 }) do DisableControlAction(0, c, true) end
            local step = IsDisabledControlPressed(0, 21) and 0.10 or 0.01
            local moved = false
            if IsDisabledControlPressed(0, 172) then o.Pos.z = o.Pos.z + step; moved = true       -- ↑ raise
            elseif IsDisabledControlPressed(0, 173) then o.Pos.z = o.Pos.z - step; moved = true    -- ↓ lower
            elseif IsDisabledControlPressed(0, 174) then o.Pos.y = o.Pos.y - step; moved = true    -- ← back
            elseif IsDisabledControlPressed(0, 175) then o.Pos.y = o.Pos.y + step; moved = true    -- → forward
            elseif IsDisabledControlPressed(0, 44)  then o.Rot[rotAxis] = (o.Rot[rotAxis] - 2) % 360; moved = true -- Q rotate
            elseif IsDisabledControlPressed(0, 38)  then o.Rot[rotAxis] = (o.Rot[rotAxis] + 2) % 360; moved = true -- E rotate
            end
            if IsDisabledControlJustPressed(0, 45) then  -- R → cycle rotation axis
                rotAxis = (rotAxis == 'z' and 'x') or (rotAxis == 'x' and 'y') or 'z'
            end
            if moved then renderRack(tuning.veh) end

            SetTextFont(4); SetTextScale(0.42, 0.42); SetTextColour(255, 255, 255, 255); SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString(('TRUNK TUNE  ~y~%s~s~ (cls %d)   z %.2f y %.2f   rot[%s] %.0f    arrows=move · Q/E=rotate · R=axis · SHIFT=fast · ENTER=save MODEL · G=class · BKSP=exit')
                :format(tuning.model, tuning.class, o.Pos.z, o.Pos.y, rotAxis:upper(), o.Rot[rotAxis]))
            DrawText(0.5, 0.86)

            local function saveScope(scope, msg)
                TriggerServerEvent('mbt_malisling:trunkOffset:save', {
                    scope = scope,
                    data = { Pos = { x = o.Pos.x, y = o.Pos.y, z = o.Pos.z },
                             Rot = { x = o.Rot.x, y = o.Rot.y, z = o.Rot.z } },
                })
                lib.notify({ type = 'success', description = msg })
            end
            if IsDisabledControlJustPressed(0, 191) then       -- ENTER → save this exact MODEL
                saveScope('model:' .. tuning.model, ('Saved trunk position for %s'):format(tuning.model))
            elseif IsDisabledControlJustPressed(0, 47) then    -- G → save the whole CLASS (broad)
                saveScope('class:' .. tuning.class, ('Saved trunk position for class %d'):format(tuning.class))
            end
            if IsDisabledControlJustPressed(0, 177) then  -- BACKSPACE → exit
                local v = tuning.veh; tuning = nil
                SetVehicleDoorShut(v, 5, false)
                renderRack(v)
            end
        end
    end)
end, false)
