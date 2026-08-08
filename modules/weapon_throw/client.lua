-- Enabled is read at use time, so the dashboard can toggle it live.
if not MBT.Throw then return end

local currentWeapon
local throwAnim  = MBT.Throw["Animation"]
local isThrowing = false

local HAND_BONE = 6286   -- right-hand grip bone the weapon prop attaches to

-- Throw origin: the right-hand grip bone. Watch out — GetWorldPositionOfEntityBone wants the
-- bone INDEX, not the ID; pass 6286 raw and you get (0,0,0).
local function handPos()
    return GetWorldPositionOfEntityBone(cache.ped, GetPedBoneIndex(cache.ped, HAND_BONE))
end

AddEventHandler('ox_inventory:currentWeapon', function(data)
    if data then currentWeapon = data end
end)

local function isAllowedToThrow(weaponGroup)
    local g = MBT.Throw["Groups"][weaponGroup]   -- nil for an unconfigured/unknown weapon group
    return g and g["Allowed"] or false
end

-- Detach and fling `vel` as an impulse, then let the engine do the tumble/arc/landing.
-- Impulse (not a teleport to the landing spot) is what gives the throw its fluid feel.
-- Returns where it comes to rest.
local function launchForce(obj, vel)
    DetachEntity(obj, true, true)
    SetEntityCollision(obj, true, true)
    ActivatePhysics(obj)
    SetEntityNoCollisionEntity(obj, cache.ped, true)

    ApplyForceToEntity(obj, 1, vel.x, vel.y, vel.z, 0,0,0, 0, false, true, true, false, true)

    -- Keep collision with the thrower off for a few ticks (not just once).
    CreateThread(function()
        local until_ = GetGameTimer() + 650
        while GetGameTimer() < until_ and DoesEntityExist(obj) do
            SetEntityNoCollisionEntity(obj, cache.ped, true)
            Wait(0)
        end
    end)

    Wait(250)
    while DoesEntityExist(obj) and IsEntityInAir(obj) do Wait(50) end
    Wait(500)
    local coords = DoesEntityExist(obj) and GetEntityCoords(obj) or nil
    if DoesEntityExist(obj) then DeleteObject(obj) end
    return coords
end

-- Forward throw. `power` scales the per-group impulse: 1.0 is the original throw,
-- charge passes 1.0..MaxMultiplier.
local function throwInstant(data, model, power)
    power = power or 1.0
    TaskPlayAnim(cache.ped, throwAnim["Dict"], throwAnim["Anim"], 8.0, -8.0, -1, 0, 0.0, false, false, false)
    local pos = handPos()
    local obj = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
    AttachEntityToEntity(obj, cache.ped, GetPedBoneIndex(cache.ped, HAND_BONE),
        0,0,0, 0,0,0, false, false, true, false, 0, false)
    Wait(500)
    local fwd = GetEntityForwardVector(cache.ped)
    local mul = (MBT.Throw["Groups"][data.Group] and MBT.Throw["Groups"][data.Group]["Multipliers"])
                or { X = 20.0, Y = 20.0, Z = 10.0 }
    return launchForce(obj, vector3(fwd.x * mul.X * power, fwd.y * mul.Y * power, fwd.z + mul.Z * power))
end

-- ── Entry: disarm, play the throw, create the ground drop ───────────────────────
local function throwWeapon(data, power)
    if isThrowing then return end
    isThrowing = true
    LocalPlayer.state:set('invBusy', true, false)
    lib.requestAnimDict(throwAnim["Dict"])
    local model = GetWeapontypeModel(data.Hash)
    lib.requestModel(model)
    TriggerEvent("ox_inventory:disarm", true)
    equippedWeapon.dropped = true

    local coords = throwInstant(data, model, power or 1.0)

    ClearPedTasks(cache.ped)
    RemoveAnimDict(throwAnim["Dict"])
    SetModelAsNoLongerNeeded(model)

    if coords then
        TriggerServerEvent("mbt_malisling:createWeaponDrop", {
            WeaponInfo = currentWeapon,
            Coords     = coords,
        })
    else
        -- Disarmed but never thrown → put it back on the body (item still in inv).
        equippedWeapon.dropped = false
        TriggerServerEvent('mbt_malisling:checkInventory')
    end

    LocalPlayer.state:set('invBusy', false, false)
    isThrowing = false
end

--- Validate intent + the held weapon, then throw at the given power (nil = legacy 1.0).
local function attemptThrowWeapon(power)
    if not MBT.Throw["Enabled"] then return end
    if cache.vehicle then return end
    local hasWeapon, weaponHash = GetCurrentPedWeapon(cache.ped)
    local weaponGroup = GetWeapontypeGroup(weaponHash)
    if not hasWeapon then return end
    if not isAllowedToThrow(weaponGroup) then MBT.NotifyLabel("no_allowed_throw"); return end
    throwWeapon({ Hash = weaponHash, Group = weaponGroup }, power)
end

-- ── Charge-power throw (Throw.Charge.Enabled — experimental, default OFF) ────────
-- Hold the key to charge power (tap = the legacy throw at 1.0; full charge = MaxMultiplier),
-- release to throw forward where you face. No raycast, no aim jitter.
local chargeState

local function getChargeConfig()
    return MBT.Throw.Charge or {}
end

local function canStartCharge()
    if not MBT.Throw["Enabled"] then return false end
    if isThrowing then return false end
    if cache.vehicle or IsEntityDead(cache.ped) then return false end
    return true
end

-- heldMs → (powerMultiplier, pct). A tap (< threshold) is 1.0; holding ramps 1.0 →
-- MaxMultiplier over (ChargeMs - threshold). A short hold is never weaker than a tap.
local function computeChargePower(heldMs)
    local c = getChargeConfig()
    local threshold = c.TapThresholdMs or 150
    local chargeMs  = c.ChargeMs or 900
    local maxMul    = c.MaxMultiplier or 1.25
    if heldMs < threshold then return 1.0, 0.0 end
    local pct = math.max(0.0, math.min(1.0, (heldMs - threshold) / math.max(1, chargeMs - threshold)))
    return 1.0 + (maxMul - 1.0) * pct, pct
end

local function endCharge()
    if not chargeState then return end
    chargeState = nil
    if getChargeConfig().ShowUI then SendNUIMessage({ action = 'charge:end' }) end
end

-- Key DOWN: start charging (or, if charge disabled, the immediate legacy throw).
RegisterCommand('+' .. MBT.Throw["Command"], function()
    local charge = getChargeConfig()
    if not charge.Enabled then
        attemptThrowWeapon()   -- legacy behaviour: throw on key down
        return
    end
    if not canStartCharge() then return end

    local hasWeapon, weaponHash = GetCurrentPedWeapon(cache.ped)
    if not hasWeapon then return end
    local group = GetWeapontypeGroup(weaponHash)
    if not isAllowedToThrow(group) then MBT.NotifyLabel("no_allowed_throw"); return end

    chargeState = { startedAt = GetGameTimer(), data = { Hash = weaponHash, Group = group } }
    if charge.ShowUI then SendNUIMessage({ action = 'charge:start' }) end

    -- Throttle the UI (50ms / Δpct ≥ 0.02), and self-clean: a lost key-up (restart, focus
    -- loss) must never soft-lock the player.
    CreateThread(function()
        local lastPct = -1
        while chargeState do
            Wait(50)
            if not chargeState then return end
            local c = getChargeConfig()
            local held = GetGameTimer() - chargeState.startedAt
            local has, hash = GetCurrentPedWeapon(cache.ped)
            if not c.Enabled or cache.vehicle or IsEntityDead(cache.ped) or isThrowing
                or not has or hash ~= chargeState.data.Hash
                or held > (c.ChargeMs or 900) + 1500 then
                endCharge()
                return
            end
            if c.ShowUI then
                local _, pct = computeChargePower(held)
                if math.abs(pct - lastPct) >= 0.02 then
                    lastPct = pct
                    SendNUIMessage({ action = 'charge:update', pct = pct })
                end
            end
        end
    end)
end, false)

-- Key UP: release → throw at the charged power (only path that disarms / sets invBusy).
RegisterCommand('-' .. MBT.Throw["Command"], function()
    if not chargeState then return end
    local state = chargeState
    chargeState = nil
    if getChargeConfig().ShowUI then SendNUIMessage({ action = 'charge:end' }) end

    if cache.vehicle or IsEntityDead(cache.ped) or isThrowing then return end
    local power = computeChargePower(GetGameTimer() - state.startedAt)
    throwWeapon(state.data, power)
end, false)

RegisterKeyMapping('+' .. MBT.Throw["Command"], "[MBT] Throw your current weapon", "keyboard", MBT.Throw["Key"])
