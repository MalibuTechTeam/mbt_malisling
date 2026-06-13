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

-- Trunk rotation is a raw Euler offset on the vehicle boot bone (rotOrder=2). Large
-- pitch+roll combinations gimbal-lock the orientation (yaw stops responding, entRot
-- snaps to -90,0,0). A weapon laid in a trunk never needs more than a gentle tilt, so
-- we constrain pitch/roll to ±TRUNK_MAX_TILT and keep yaw free. This also scrubs any
-- corrupt rotation an earlier build may have persisted (clamped on load + save).
local TRUNK_MAX_TILT = 45.0
local function clampN(n, lo, hi)
    n = tonumber(n) or 0.0
    return (n < lo and lo) or (n > hi and hi) or n
end
local function norm180(n)
    local m = (tonumber(n) or 0.0) % 360.0
    return (m > 180.0) and (m - 360.0) or m
end
local function safeTrunkOffset(d)
    d = (type(d) == 'table') and d or DEFAULT_OFFSET
    local p, r = d.Pos or {}, d.Rot or {}
    return {
        Pos = { x = clampN(p.x, -3.0, 3.0), y = clampN(p.y, -3.0, 3.0), z = clampN(p.z, -3.0, 3.0) },
        Rot = { x = clampN(norm180(r.x), -TRUNK_MAX_TILT, TRUNK_MAX_TILT),
                y = clampN(norm180(r.y), -TRUNK_MAX_TILT, TRUNK_MAX_TILT),
                z = (tonumber(r.z) or 0.0) % 360.0 },
    }
end

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

-- ── ox_inventory trunk parity ────────────────────────────────────────────────
-- ox_inventory keeps per-model flags that decide WHICH door is the storage:
--   Storage[hash] == 3       → "trunk in the hood" (front, e.g. the Adder) → door 4
--   Storage[hash] == 0 or 1  → no trunk storage
--   otherwise (nil)          → normal rear boot                            → door 5
-- We load ox_inventory's own data file so our open/close + proximity match it
-- exactly. Feature-gated: without ox_inventory we fall back to the door-5 heuristic.
local oxStorage = nil
CreateThread(function()
    if GetResourceState('ox_inventory') ~= 'started' then return end
    local chunk = LoadResourceFile('ox_inventory', 'data/vehicles.lua')
    local fn = chunk and load(chunk)
    if not fn then return end
    local ok, data = pcall(fn)
    if ok and type(data) == 'table' then oxStorage = data.Storage end
end)

local function hoodTrunk(veh)
    return oxStorage ~= nil and oxStorage[GetEntityModel(veh)] == 3
end

--- Boot door(s) for this vehicle, ox_inventory-faithful: hood-trunk models (Adder
--- etc.) use the front door 4, vans (class 12) the rear doors {2,3}, everything else
--- the boot door 5 — falling back to the rear doors if the boot door isn't valid.
local function bootDoorList(veh)
    if hoodTrunk(veh) then return { 4 } end
    if GetVehicleClass(veh) == 12 then return { 2, 3 } end
    if GetIsDoorValid(veh, 5) then return { 5 } end
    return { 2, 3 }
end

--- Local-space offset from the vehicle origin to the storage opening — front for hood
--- trunks, rear otherwise. Used as the prop BASE on models with no 'boot' bone (so the
--- weapon sits in the opening instead of dead-centre/under the car), and in world space
--- as the editor's proximity + camera anchor.
local function trunkAnchorLocal(veh)
    local mn, mx = GetModelDimensions(GetEntityModel(veh))
    local fy = hoodTrunk(veh) and 1.0 or 0.0   -- max.y = front of the model, min.y = rear
    return vector3(mn.x + (mx.x - mn.x) * 0.5, mn.y + (mx.y - mn.y) * fy, mn.z + (mx.z - mn.z) * 0.5)
end

local function trunkAnchor(veh)
    local o = trunkAnchorLocal(veh)
    return GetOffsetFromEntityInWorldCoords(veh, o.x, o.y, o.z)
end

local function openBoot(veh)
    if NetworkGetEntityIsNetworked(veh) and not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local deadline = GetGameTimer() + 600
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < deadline do Wait(50) end
    end
    for _, d in ipairs(bootDoorList(veh)) do SetVehicleDoorOpen(veh, d, false, false) end
end

local function shutBoot(veh)
    if not DoesEntityExist(veh) then return end
    for _, d in ipairs(bootDoorList(veh)) do SetVehicleDoorShut(veh, d, false) end
end

local function playAnim(dict, name, ms, flag)
    ms = ms or 1000
    if not dict or dict == '' or not name or name == '' or not DoesAnimDictExist(dict) then Wait(ms); return end
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, name, 4.0, -4.0, ms, flag or 49, 0.0, false, false, false)
    Wait(ms)
    ClearPedTasks(cache.ped)
end

--- Positioned anim (TaskPlayAnimAdvanced) at the ped's current spot — ox uses this for
--- the 'return_case'/'trevor_action' close gesture; plain TaskPlayAnim doesn't show it.
local function playAnimAdvanced(dict, name, ms)
    ms = ms or 1000
    if not dict or dict == '' or not name or name == '' or not DoesAnimDictExist(dict) then Wait(ms); return end
    lib.requestAnimDict(dict)
    local p = GetEntityCoords(cache.ped, true)
    TaskPlayAnimAdvanced(cache.ped, dict, name, p.x, p.y, p.z, 0.0, 0.0, GetEntityHeading(cache.ped),
        2.0, 2.0, ms, 49, 0.25, 0, 0)
    Wait(ms)
    ClearPedTasks(cache.ped)
end

-- ── Stow / Retrieve flows — mirror ox_inventory's open/close-trunk feel ────────────
--- Open boot → bend & place/take anim → run op() → close gesture → shut boot.
local function trunkAction(veh, place, op)
    local a = cfg.Animation or {}
    openBoot(veh)
    Wait(a.BootOpenDelayMs or 250)
    if place then
        playAnim(a.PlaceDict, a.PlaceAnim, a.PlaceMs)      -- bend & put the weapon in
    else
        playAnim(a.TakeDict, a.TakeAnim, a.TakeMs)         -- bend & lift the weapon out
    end
    local res = op()
    playAnimAdvanced(a.CloseDict, a.CloseAnim, a.CloseMs)  -- hands close the lid (positioned)
    Wait(150)
    shutBoot(veh)
    return res
end

local function doStow(veh)
    if busy or not cfg.Enabled or not veh or veh == 0 then return end
    if cache.vehicle or not holdingLongGun() then return end
    if GetEntitySpeed(veh) > 1.0 then return end
    busy = true
    local slot, netId = CurrentWeapon.slot, VehToNet(veh)
    local res = trunkAction(veh, true, function()
        return lib.callback.await('mbt_malisling:trunkRack:stow', false, { netId = netId, slot = slot })
    end)
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
    local res = trunkAction(veh, false, function()
        return lib.callback.await('mbt_malisling:trunkRack:retrieve', false, { netId = netId, index = index })
    end)
    busy = false
    if res and res.ok then
        -- Equip straight into hand when enabled; otherwise the weapon stays in inventory.
        if cfg.EquipOnRetrieve then
            if GetResourceState('ox_inventory') == 'started' and res.equipSlot then
                exports.ox_inventory:useSlot(res.equipSlot)                  -- ox: equip the slot
            elseif GetResourceState('qb-inventory') == 'started' and res.name
                and PlayerData and PlayerData.items then
                -- qb: trigger the normal use-weapon flow (avoids desync vs raw GiveWeaponToPed)
                for _, it in pairs(PlayerData.items) do
                    -- qb item names are lowercase; res.name is canonical UPPER.
                    if it.name and it.name:upper() == res.name
                        and (not res.serial or (it.info and it.info.serie == res.serial)) then
                        TriggerServerEvent('qb-inventory:server:useItem', it)
                        break
                    end
                end
            end
        end
    elseif res and res.reason then
        MBT.NotifyLabel(res.reason)
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
    -- Fully open (avoids the open-swing slide); checks the boot door(s), vans included.
    for _, d in ipairs(bootDoorList(veh)) do
        if GetVehicleDoorAngleRatio(veh, d) > 0.8 then return true end
    end
    return false
end

-- Live dev tuner state (/mbt_trunktune) — overrides the offset for one vehicle.
local tuning = nil   -- { veh, class, off }

--- Offset for this vehicle: live tuner > per-MODEL > per-class > default.
--- Per-model is the precise tier (each vehicle exact), tuned with /mbt_trunktune.
local function offsetFor(veh)
    if tuning and tuning.veh == veh then return tuning.off end
    local po = cfg.PropOffset or {}
    local model = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or '')
    return safeTrunkOffset((po.ByModel and po.ByModel[model])
        or (po.ByClass and po.ByClass[GetVehicleClass(veh)])
        or po.Default or DEFAULT_OFFSET)
end

--- Anchor on the 'boot' bone — it sits at the trunk, so the prop is VISIBLE and easy
--- to tune there (body-space bone 0 placed it inside/under the car = invisible). The
--- boot bone is the lid, so its open height varies per vehicle → tune per MODEL with
--- /mbt_trunktune. The slide while the lid swings is avoided by only rendering once the
--- boot is FULLY open (see bootIsOpen). bone 0 fallback for vehicles with no boot bone.
local function anchorFor(veh)
    local off = offsetFor(veh)
    local bone = GetEntityBoneIndexByName(veh, 'boot')
    local bx, by, bz = 0.0, 0.0, 0.0
    if bone == -1 then
        -- No boot bone (e.g. hood-trunk supercars): anchor at the storage opening in
        -- body space so the prop is visible there, then apply the saved offset on top.
        bone = 0
        local b = trunkAnchorLocal(veh)
        bx, by, bz = b.x, b.y, b.z
    end
    return bone, bx + off.Pos.x, by + off.Pos.y, bz + off.Pos.z, off.Rot
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
                    -- isPed=FALSE: the target is a VEHICLE (not a ped). The ped editor
                    -- needed isPed=true because it attaches to a PED; on a vehicle bone
                    -- isPed=true is wrong and breaks placement — this path always worked
                    -- with false.
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
    if kind == 'class' then po.ByClass[tonumber(key)] = data and safeTrunkOffset(data) or nil
    elseif kind == 'model' then po.ByModel[key] = data and safeTrunkOffset(data) or nil end
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

-- ── Trunk live editor (admin NUI) ─────────────────────────────────────────────
-- Same UX as the weapon-prop editor: the dashboard collapses, an orbit camera
-- frames the open trunk, and a preview weapon rides the boot bone while the admin
-- nudges the offset live. Targets the CLOSEST vehicle (its real scale → precise).
-- Spawns its own preview weapon, so you can tune an empty vehicle too. Save writes
-- the per-model or per-class override through the ACE-checked offset event.
local tedit = nil   -- { veh, model, class, off, prop, cam, orbit }

local TEDIT_WEAPON = 'WEAPON_CARBINERIFLE'

local function teditAttach()
    if not tedit or not tedit.veh or not DoesEntityExist(tedit.veh) then return end

    -- THE REAL FIX (Codex): a reused CreateWeaponObject does NOT reliably take a new
    -- attach rotation — re-attaching the same prop leaves the rotation stuck. The working
    -- /mbt_trunktune path (renderRack) DELETES + RECREATES the weapon object on every
    -- change, which is why its rotation works. So we do the same here: rebuild the
    -- preview prop on every live update. (isPed stays true — the command works with it.)
    if tedit.prop and DoesEntityExist(tedit.prop) then DeleteEntity(tedit.prop) end
    local hash = joaat(TEDIT_WEAPON)
    lib.requestWeaponAsset(hash, 1000, 31, 1)
    local prop = CreateWeaponObject(hash, 50, 0.0, 0.0, 0.0, true, 1.0, 0)
    if not prop or not DoesEntityExist(prop) then tedit.prop = nil; return end
    tedit.prop = prop
    SetEntityCollision(prop, false, false)

    local bone = GetEntityBoneIndexByName(tedit.veh, 'boot')
    local bx, by, bz = 0.0, 0.0, 0.0
    if bone == -1 then
        bone = 0
        local b = trunkAnchorLocal(tedit.veh)   -- match the runtime rack anchor
        bx, by, bz = b.x, b.y, b.z
    end
    local o = tedit.off
    AttachEntityToEntity(prop, tedit.veh, bone,
        bx + o.Pos.x, by + o.Pos.y, bz + o.Pos.z, o.Rot.x, o.Rot.y, o.Rot.z,
        false, false, false, false, 2, true)   -- isPed=FALSE (vehicle target, like the command)
end

local function teditUpdateCam()
    if not tedit or not tedit.cam then return end
    local bone = GetEntityBoneIndexByName(tedit.veh, 'boot')
    local c = (bone ~= -1) and GetWorldPositionOfEntityBone(tedit.veh, bone) or trunkAnchor(tedit.veh)
    local orb = tedit.orbit
    local yawR, pitchR = math.rad(orb.yaw), math.rad(orb.pitch)
    SetCamCoord(tedit.cam,
        c.x + orb.dist * math.cos(pitchR) * math.sin(yawR),
        c.y + orb.dist * math.cos(pitchR) * math.cos(yawR),
        c.z + 0.2 + orb.dist * math.sin(pitchR))
    PointCamAtCoord(tedit.cam, c.x, c.y, c.z)
end

local function teditStop()
    if not tedit then return end
    local veh = tedit.veh
    if tedit.prop and DoesEntityExist(tedit.prop) then DeleteEntity(tedit.prop) end
    if tedit.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(tedit.cam, false)
    end
    tedit = nil
    SetEntityVisible(cache.ped, true, false)   -- restore the editor's ped
    if veh and DoesEntityExist(veh) then shutBoot(veh) end
end

RegisterNUICallback('trunkEdit:start', function(_, cb)
    if tedit then cb({ ok = false, reason = 'busy' }); return end
    if cache.vehicle then
        -- The dashboard shows the reason inline (no ox_lib notify here).
        cb({ ok = false, reason = 'on_foot' }); return
    end
    local pcoords = GetEntityCoords(cache.ped)
    local veh = lib.getClosestVehicle(pcoords, 6.0, false)
    if not veh or veh == 0 then
        cb({ ok = false, reason = 'no_vehicle' }); return
    end

    -- (1) Be standing AT the storage opening — front for hood trunks (the Adder),
    -- rear otherwise — using ox_inventory's own anchor + a small margin over its 1.5m.
    if #(pcoords - trunkAnchor(veh)) > ((cfg.InteractionDistance or 2.5) + 0.5) then
        cb({ ok = false, reason = 'not_at_trunk' }); return
    end

    -- (2) Open the boot and WAIT until it's actually open — you can't place a weapon
    -- in a closed trunk. This is the real "does it have a usable trunk" test, so it
    -- covers vehicles with no boot at all (e.g. bikes): they simply never open.
    openBoot(veh)
    local deadline = GetGameTimer() + 1500
    while not bootIsOpen(veh) and GetGameTimer() < deadline do Wait(50) end
    if not bootIsOpen(veh) then
        shutBoot(veh)
        cb({ ok = false, reason = 'trunk_wont_open' }); return
    end

    local model = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or '?')
    local class = GetVehicleClass(veh)
    local b = offsetFor(veh)
    local off = { Pos = { x = b.Pos.x, y = b.Pos.y, z = b.Pos.z },
                  Rot = { x = b.Rot.x, y = b.Rot.y, z = b.Rot.z } }

    -- Hide the editor's own ped so it never stands between the camera and the trunk
    -- (you're standing AT the opening, so otherwise you'd block your own view).
    SetEntityVisible(cache.ped, false, false)

    -- Default camera: stand OUTSIDE the storage opening looking straight in — BEHIND the
    -- car for a rear boot, in FRONT for a hood trunk. Derived from the vehicle's real
    -- forward vector: the old heading±180 math had a sign mismatch with the orbit's
    -- sin/cos, so the camera only framed the trunk when the car happened to point north.
    local fwd = GetEntityForwardVector(veh)
    local dx, dy = fwd.x, fwd.y
    if not hoodTrunk(veh) then dx, dy = -dx, -dy end   -- rear boot → camera behind the car
    local camYaw = math.deg(math.atan(dx, dy)) % 360.0
    tedit = {
        veh = veh, model = model, class = class, off = off, prop = nil,   -- teditAttach creates it
        savedOff = safeTrunkOffset(off),   -- Reset baseline: last save, or the open-time offset
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true),
        orbit = { yaw = camYaw, pitch = -15.0, dist = 2.6 },
    }
    teditAttach()
    teditUpdateCam()
    RenderScriptCams(true, false, 0, true, true)

    -- Re-frame once the lid is fully open (the boot bone height settles).
    CreateThread(function()
        local deadline = GetGameTimer() + 1500
        while tedit and GetGameTimer() < deadline and not bootIsOpen(tedit.veh) do Wait(100) end
        if tedit then teditAttach(); teditUpdateCam() end
    end)

    cb({ ok = true, model = model, class = class, off = off,
         view = { yaw = tedit.orbit.yaw, pitch = tedit.orbit.pitch, dist = tedit.orbit.dist } })
end)

RegisterNUICallback('trunkEdit:update', function(d, cb)
    if tedit and type(d) == 'table' and type(d.off) == 'table'
        and type(d.off.Pos) == 'table' and type(d.off.Rot) == 'table' then
        tedit.off = safeTrunkOffset(d.off)
        teditAttach()
    end
    cb({})
end)

RegisterNUICallback('trunkEdit:cam', function(d, cb)
    if tedit and tedit.cam and type(d) == 'table' then
        local orb = tedit.orbit
        -- Absolute values from the NUI sliders (clamped).
        if d.yaw   ~= nil then orb.yaw   = tonumber(d.yaw) % 360 end
        if d.pitch ~= nil then orb.pitch = math.max(-80.0, math.min(80.0, tonumber(d.pitch) or orb.pitch)) end
        if d.dist  ~= nil then orb.dist  = math.max(1.0, math.min(6.0, tonumber(d.dist) or orb.dist)) end
        teditUpdateCam()
    end
    cb({})
end)

RegisterNUICallback('trunkEdit:reset', function(_, cb)
    if tedit then
        -- Revert to the last SAVED offset (or the open-time offset if nothing saved yet),
        -- NOT the hardcoded stock default. To clear an override entirely, use the per-scope
        -- Reset in the Trunk Positions list.
        tedit.off = safeTrunkOffset(tedit.savedOff)
        teditAttach()
        cb(tedit.off)
    else
        cb({})
    end
end)

RegisterNUICallback('trunkEdit:save', function(d, cb)
    if tedit and type(d) == 'table' then
        local scope = (d.scope == 'class') and ('class:' .. tedit.class) or ('model:' .. tedit.model)
        tedit.off = safeTrunkOffset(tedit.off)
        tedit.savedOff = safeTrunkOffset(tedit.off)   -- Reset now returns here
        TriggerServerEvent('mbt_malisling:trunkOffset:save', {
            scope = scope,
            data  = { Pos = { x = tedit.off.Pos.x, y = tedit.off.Pos.y, z = tedit.off.Pos.z },
                      Rot = { x = tedit.off.Rot.x, y = tedit.off.Rot.y, z = tedit.off.Rot.z } },
        })
        cb({ ok = true, scope = (d.scope == 'class') and 'class' or 'model' })
    else
        cb({ ok = false })
    end
end)

RegisterNUICallback('trunkEdit:stop', function(_, cb)
    teditStop()
    cb({})
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then teditStop() end
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
                if bootIsOpen(veh) then shutBoot(veh) else openBoot(veh) end
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
    openBoot(veh)
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
                shutBoot(v)
                renderRack(v)
            end
        end
    end)
end, false)
