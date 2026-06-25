-- Load if the block exists; Enabled checked at use time (live-apply via menu).
if not MBT.Throw then return end

local currentWeapon
local throwAnim  = MBT.Throw["Animation"]
local isThrowing = false

local HAND_BONE = 6286   -- grip bone the weapon prop attaches to (kept from the legacy throw)
local G = 9.81           -- gravity; the SAME value drives the preview arc AND the launch

AddEventHandler('ox_inventory:currentWeapon', function(data)
    if data then currentWeapon = data end
end)

local function isAllowedToThrow(weaponGroup)
    local g = MBT.Throw["Groups"][weaponGroup]   -- nil for an unconfigured/unknown weapon group
    return g and g["Allowed"] or false
end

-- ── Trajectory helpers (shared by the aim PREVIEW and the actual THROW) ─────────
-- One source of truth: the arc you see is the exact physics the weapon is launched
-- with, so the preview matches the landing (the thing that usually breaks these).
local function rotationToDirection(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

--- Raycast from the gameplay camera to the world; returns the ground/hit coords.
local function camGroundPoint(maxDist)
    local cam = GetGameplayCamCoord()
    local dir = rotationToDirection(GetGameplayCamRot(2))
    local dest = cam + dir * (maxDist + 40.0)
    local _, hit, endCoords = GetShapeTestResult(
        StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, cache.ped, 0))
    if hit then return endCoords end
    return dest   -- no hit → far point; clampTarget ground-probes it
end

--- Clamp the aim point to MaxDistance (horizontal) from the throw origin, then drop
--- it onto the ground so the marker sits on a surface.
local function clampTarget(origin, target, maxDist)
    local dx, dy = target.x - origin.x, target.y - origin.y
    local d = math.sqrt(dx * dx + dy * dy)
    local cx, cy, cz = target.x, target.y, target.z
    if d > maxDist and d > 0.001 then
        local s = maxDist / d
        cx, cy = origin.x + dx * s, origin.y + dy * s
        local _, hit, endCoords = GetShapeTestResult(
            StartShapeTestRay(cx, cy, origin.z + 8.0, cx, cy, origin.z - 50.0, 1, cache.ped, 0))
        if hit then return endCoords end
        cz = origin.z
    end
    return vector3(cx, cy, cz)
end

--- Velocity (and flight time) to carry a projectile from `origin` to `target` in a
--- clamped flight time. vz includes the +½·G·t² needed to fight gravity over t.
local function solveVelocityByTime(origin, target)
    local aim = MBT.Throw.Aim or {}
    local dx, dy, dz = target.x - origin.x, target.y - origin.y, target.z - origin.z
    local dist = math.sqrt(dx * dx + dy * dy)
    local t = math.max(aim.MinFlightTime or 0.45,
                       math.min(aim.MaxFlightTime or 1.25, dist / (aim.HorizontalSpeed or 13.0)))
    return vector3(dx / t, dy / t, (dz + 0.5 * G * t * t) / t), t
end

local function projectilePoint(origin, vel, t)
    return vector3(origin.x + vel.x * t, origin.y + vel.y * t,
                   origin.z + vel.z * t - 0.5 * G * t * t)
end

local function drawArc(origin, vel, flightTime, m)
    for i = 1, 28 do
        local p = projectilePoint(origin, vel, flightTime * (i / 28.0))
        DrawMarker(28, p.x, p.y, p.z, 0,0,0, 0,0,0, 0.07,0.07,0.07, m.r, m.g, m.b, m.a,
                   false, false, 2, false, nil, nil, false)
    end
end

--- Launch a detached object with a solved velocity, wait for it to settle (robust:
--- not just IsEntityInAir), and return the landed coords.
local function launchAndSettle(obj, vel)
    DetachEntity(obj, true, true)
    SetEntityNoCollisionEntity(obj, cache.ped, true)
    ActivatePhysics(obj)
    SetEntityVelocity(obj, vel.x, vel.y, vel.z)

    local start = GetGameTimer()
    local last  = GetEntityCoords(obj)
    local stable = 0
    while DoesEntityExist(obj) and (GetGameTimer() - start) < 6000 do
        Wait(50)
        local c     = GetEntityCoords(obj)
        local moved = #(c - last)
        if not IsEntityInAir(obj) and #(GetEntityVelocity(obj)) < 0.35 and moved < 0.05 then
            stable = stable + 1
            if stable >= 3 then break end
        else
            stable = 0
        end
        last = c
    end
    local coords = DoesEntityExist(obj) and GetEntityCoords(obj) or last
    if DoesEntityExist(obj) then DeleteObject(obj) end
    return coords
end

-- ── Legacy: instant forward throw (Aim.Enabled = false — Gianmarco's behaviour) ──
local function throwInstant(data, model)
    local pos = GetWorldPositionOfEntityBone(cache.ped, HAND_BONE)
    local obj = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
    AttachEntityToEntity(obj, cache.ped, GetPedBoneIndex(cache.ped, HAND_BONE),
        0,0,0, 0,0,0, false, false, true, false, 0, false)
    Wait(500)
    DetachEntity(obj, true, true)
    local fwd = GetEntityForwardVector(cache.ped)
    local mul = MBT.Throw["Groups"][data.Group]["Multipliers"] or { X = 20.0, Y = 20.0, Z = 10.0 }
    ApplyForceToEntity(obj, 1, fwd.x * mul.X, fwd.y * mul.Y, fwd.z + mul.Z, 0,0,0, 0, false, true, true, false, true)
    Wait(250)
    while IsEntityInAir(obj) do Wait(250) end
    Wait(700)
    local coords = GetEntityCoords(obj)
    Wait(100)
    DeleteObject(obj)
    return coords
end

--- Per-group max throw distance: heavier weapons reach less. Reuses the legacy
--- per-group Multipliers.X (Gianmarco's weight tuning), since SetEntityVelocity ignores
--- model mass — so the weight feel comes from clamping the arc shorter instead.
local function groupReach(group)
    local aim  = MBT.Throw.Aim or {}
    local g    = MBT.Throw["Groups"][group]
    local mulX = (g and g.Multipliers and g.Multipliers.X) or 20.0
    local factor = math.max(aim.MinReachFactor or 0.25, math.min(1.0, mulX / (aim.ReachReference or 40.0)))
    return (aim.MaxDistance or 18.0) * factor
end

-- ── Aim-arc throw (Aim.Enabled = true) ─────────────────────────────────────────
local function throwAimed(data, model)
    local aim = MBT.Throw.Aim
    local m   = aim.Marker or { r = 80, g = 180, b = 255, a = 180 }
    local maxD = groupReach(data.Group)

    -- Weapon in hand for the windup; freeze the anim there while the player aims.
    local pos = GetWorldPositionOfEntityBone(cache.ped, HAND_BONE)
    local obj = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
    AttachEntityToEntity(obj, cache.ped, GetPedBoneIndex(cache.ped, HAND_BONE),
        0,0,0, 0,0,0, false, false, true, false, 0, false)
    Wait(120)   -- let the windup play in
    SetEntityAnimSpeed(cache.ped, throwAnim["Dict"], throwAnim["Anim"], 0.0)   -- freeze
    FreezeEntityPosition(cache.ped, true)   -- aim with the camera; no sliding/walking off

    local confirmed, cancelled = false, false
    while not confirmed and not cancelled do
        Wait(0)
        if IsEntityDead(cache.ped) or cache.vehicle then cancelled = true break end

        local origin = GetWorldPositionOfEntityBone(cache.ped, HAND_BONE)
        local target = clampTarget(origin, camGroundPoint(maxD), maxD)
        local vel, ft = solveVelocityByTime(origin, target)
        drawArc(origin, vel, ft, m)
        DrawMarker(1, target.x, target.y, target.z - 0.95, 0,0,0, 0,0,0, 0.5,0.5,1.0,
                   m.r, m.g, m.b, 120, false, false, 2, false, nil, nil, false)

        -- LMB confirms (instead of firing); Backspace cancels.
        DisableControlAction(0, 24, true)    -- attack
        DisableControlAction(0, 25, true)    -- aim
        DisableControlAction(0, 257, true)   -- attack2
        DisableControlAction(0, 263, true)   -- melee attack
        if IsDisabledControlJustPressed(0, 24) then confirmed = true end
        if IsControlJustPressed(0, 177) then cancelled = true end   -- Backspace
    end

    FreezeEntityPosition(cache.ped, false)

    if cancelled then
        if DoesEntityExist(obj) then DeleteObject(obj) end
        return nil
    end

    -- Release: resume the anim, recompute from the CURRENT hand pos to the aim point.
    SetEntityAnimSpeed(cache.ped, throwAnim["Dict"], throwAnim["Anim"], 1.0)
    local origin = GetWorldPositionOfEntityBone(cache.ped, HAND_BONE)
    local target = clampTarget(origin, camGroundPoint(maxD), maxD)
    local vel = solveVelocityByTime(origin, target)
    Wait(80)   -- small beat so the release frame plays before the launch
    return launchAndSettle(obj, vel)
end

-- ── Entry: play the anim, route to aimed or instant, then create the drop ───────
local function throwWeapon(data)
    if isThrowing then return end
    isThrowing = true
    LocalPlayer.state:set('invBusy', true, false)
    lib.requestAnimDict(throwAnim["Dict"])
    local model = GetWeapontypeModel(data.Hash)
    lib.requestModel(model)
    TriggerEvent("ox_inventory:disarm", true)
    equippedWeapon.dropped = true
    TaskPlayAnim(cache.ped, throwAnim["Dict"], throwAnim["Anim"], 8.0, -8.0, -1, 0, 0.0, false, false, false)

    local coords
    if MBT.Throw.Aim and MBT.Throw.Aim.Enabled then
        coords = throwAimed(data, model)
    else
        coords = throwInstant(data, model)
    end

    ClearPedTasks(cache.ped)
    RemoveAnimDict(throwAnim["Dict"])
    SetModelAsNoLongerNeeded(model)

    if coords then
        TriggerServerEvent("mbt_malisling:createWeaponDrop", {
            WeaponInfo = currentWeapon,
            Coords     = coords,
        })
    end

    LocalPlayer.state:set('invBusy', false, false)
    isThrowing = false
end

local function attemptThrowWeapon()
    if not MBT.Throw["Enabled"] then return end
    if cache.vehicle then return end
    local hasWeapon, weaponHash = GetCurrentPedWeapon(cache.ped)
    local weaponGroup = GetWeapontypeGroup(weaponHash)
    if not hasWeapon then return end
    if not isAllowedToThrow(weaponGroup) then MBT.NotifyLabel("no_allowed_throw"); return end
    throwWeapon({ Hash = weaponHash, Group = weaponGroup })
end

RegisterCommand(MBT.Throw["Command"], attemptThrowWeapon)
RegisterKeyMapping(MBT.Throw["Command"], "[MBT] Throw your current weapon", "keyboard", MBT.Throw["Key"])
