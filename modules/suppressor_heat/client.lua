-- ─────────────────────────────────────────────────────────────────────────────
-- Suppressor Heat Glow — the suppressor glows orange→red under sustained fire and
-- cools over a few seconds. Visual only. Heat accrues only while the gun is in hand;
-- the glow then keeps rendering + cooling on the matching slung prop after holster,
-- drawn at the prop's gun_muzzle world position (a plain draw call) to sidestep the
-- engine quirks that make slung-weapon *flashlight* attachment unreliable.
-- ─────────────────────────────────────────────────────────────────────────────

-- Enabled is read inside the loop so the dashboard can toggle it live.
if not MBT.SuppressorHeat then return end

local cfg = MBT.SuppressorHeat

local heat            = 0   -- 0 .. cfg.MaxHeat
local lastShotTime    = 0
local lastArmedHash   = 0   -- last non-unarmed weapon held (for cold-on-swap reset)
local suppHash        = 0   -- weapon hash whose suppressor currently holds the heat
local lastClip        = nil -- clip ammo last frame, to detect shots fired
local suppressorComps = {}

-- External heat drive (companion combat resource, via export). When fresh, it takes
-- precedence over the internal ammo-based heat and glows ANY held weapon's muzzle —
-- not just suppressed ones — so a paid overheat system is the single source of truth.
local extHeat01 = 0.0   -- 0..1 normalised heat pushed by the companion
local extHeatAt = 0     -- GetGameTimer() of the last push (freshness gate)

--- Companion drives the muzzle glow with its own heat (0..1). Overrides the internal
--- suppressor heat while fresh; works on any weapon in hand.
---@param t number  0..1
exports('SetMuzzleHeat', function(t)
    extHeat01 = math.max(0.0, math.min(tonumber(t) or 0.0, 1.0))
    extHeatAt = GetGameTimer()
end)

--- Collect every suppressor component hash from MBT.WeaponsInfo (type='muzzle', or a 'supp' key-name fallback); returns true if at least one was found.
---@return boolean ok
local function buildSuppressorList()
    local comps = MBT.WeaponsInfo and MBT.WeaponsInfo.Components
    if not comps then return false end

    for key, data in pairs(comps) do
        local isSuppressor = data.type == 'muzzle'
            or (type(key) == 'string' and key:find('supp'))
        if isSuppressor and data.client and data.client.component then
            for _, hash in ipairs(data.client.component) do
                suppressorComps[#suppressorComps + 1] = hash
            end
        end
    end

    return #suppressorComps > 0
end

---@param weaponHash number
---@return boolean
local function heldWeaponHasSuppressor(weaponHash)
    if not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return false
    end
    for i = 1, #suppressorComps do
        -- HasPedGotWeaponComponent is boolean on modern FiveM, 1/0 on older — accept both.
        local r = HasPedGotWeaponComponent(cache.ped, weaponHash, suppressorComps[i])
        if r == true or r == 1 then
            return true
        end
    end
    return false
end

--- Heat ramp 0..1 above the warm threshold.
local function heatT()
    local span = cfg.MaxHeat - cfg.WarmThreshold
    return span > 0 and math.min(1.0, (heat - cfg.WarmThreshold) / span) or 1.0
end

-- ── Glow target entity ──────────────────────────────────────────────────────────
--- The held weapon if armed, else the matching slung prop (matched by model) so the glow survives holstering.
---@param weaponHash number  hash of the (possibly holstered) suppressed weapon
---@return number entity  0 if neither is available
local function glowEntity(weaponHash)
    local held = GetCurrentPedWeaponEntityIndex(cache.ped)
    if held and held ~= 0 and DoesEntityExist(held) then
        return held
    end

    if not weaponHash or weaponHash == 0 then return 0 end

    -- Matched by MODEL, which is why phase 3 has to move this to the serial: with two copies
    -- of the same weapon slung, the model alone can't say which one is the hot barrel.
    local wantModel = GetWeapontypeModel(weaponHash)
    return Slung.forEach(cache.serverId, function(ent)
        if GetEntityModel(ent) == wantModel then return ent end
    end) or 0
end

--- World position of the weapon entity's muzzle, or nil if the entity is gone (no hand-bone fallback — that snap-to-hand caused the holster flicker).
---@param entity number
---@return vector3?
local function muzzlePos(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local bone = GetEntityBoneIndexByName(entity, 'gun_muzzle')
    if bone ~= -1 then
        return GetWorldPositionOfEntityBone(entity, bone)
    end
    return GetEntityCoords(entity)  -- prop exists but exposes no muzzle bone
end

--- Heat-scaled orange->red colour + a throb multiplier once critically hot.
local function heatColour()
    local t = heatT()
    local throb = 1.0
    if heat >= cfg.HotThreshold then
        throb = 0.85 + 0.15 * math.sin(GetGameTimer() / 90.0)
    end
    return 255, math.floor(110 * (1.0 - t)), 0, t, throb
end

local function renderLight(entity)
    local pos = muzzlePos(entity)
    if not pos then return end
    local r, g, b, t, throb = heatColour()
    DrawLightWithRange(pos.x, pos.y, pos.z, r, g, b, cfg.Light.Range,
        cfg.Light.Intensity * (0.4 + 0.6 * t) * throb)
end

-- ── Glow-sphere mode (draws a glow that does not light the environment) ─────────
local function renderGlowSphere(entity)
    local pos = muzzlePos(entity)
    if not pos then return end
    local r, g, b, t, throb = heatColour()
    DrawGlowSphere(pos.x, pos.y, pos.z, cfg.GlowSphere.Radius, r, g, b,
        cfg.GlowSphere.Intensity * (0.4 + 0.6 * t) * throb, false, false)
end

-- ── Particle mode ──────────────────────────────────────────────────────────────
local fxHandle = nil
local fxEntity = nil

local function stopGlow()
    if fxHandle then
        StopParticleFxLooped(fxHandle, false)
        fxHandle = nil
        fxEntity = nil
    end
end

--- Start / maintain the looped heat-glow particle on the muzzle, tinting orange -> red and scaling with heat; works on the held weapon or, once holstered, the matching slung prop (entity resolved by the caller).
---@param weaponEntity number
local function updateGlow(weaponEntity)
    if not weaponEntity or weaponEntity == 0 or not DoesEntityExist(weaponEntity) then
        stopGlow()
        return
    end

    local p = cfg.Particle

    -- (Re)create the fx when missing or when the held weapon changed.
    if not fxHandle or fxEntity ~= weaponEntity then
        stopGlow()
        if not HasNamedPtfxAssetLoaded(p.Dict) then
            RequestNamedPtfxAsset(p.Dict)
            return  -- retry next frame once the asset streams in
        end
        local bone = GetEntityBoneIndexByName(weaponEntity, 'gun_muzzle')
        if bone == -1 then bone = 0 end
        UseParticleFxAssetNextCall(p.Dict)
        fxHandle = StartParticleFxLoopedOnEntityBone(p.Name, weaponEntity,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, p.Scale or 0.4, false, false, false)
        fxEntity = weaponEntity
    end

    if not fxHandle then return end

    local t = heatT()

    -- Colour ramps orange (1, 0.43, 0) -> deep red (1, 0, 0).
    SetParticleFxLoopedColour(fxHandle, 1.0, 0.43 * (1.0 - t), 0.0, false)

    local scale = (p.Scale or 0.4) * (0.6 + 0.4 * t)
    if heat >= cfg.HotThreshold then  -- subtle throb once critically hot
        scale = scale * (0.9 + 0.1 * math.sin(GetGameTimer() / 90.0))
    end
    SetParticleFxLoopedScale(fxHandle, scale)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then stopGlow() end
end)

CreateThread(function()
    -- MBT.WeaponsInfo is populated by Init() via a server callback.
    while not (MBT.WeaponsInfo and MBT.WeaponsInfo.Components) do Wait(500) end

    if not buildSuppressorList() then
        Utils.mbtWarn("suppressor_heat ~ no suppressor components in WeaponsInfo; feature inert")
        return
    end
    Utils.mbtDebugger("suppressor_heat ~ ready, suppressor components:", #suppressorComps)

    if cfg.Mode == 'particle' then
        RequestNamedPtfxAsset(cfg.Particle.Dict)  -- preload so the glow starts instantly
    end

    while true do
        -- Companion-driven glow (paid overheat): if a combat resource pushed heat
        -- recently, it OWNS the glow — on ANY held weapon's muzzle, bypassing both the
        -- suppressor/ammo path AND malisling's own suppressor toggle (shooting gates it
        -- on its side). Single source of truth, no double-count.
        if (GetGameTimer() - extHeatAt) < 600 then
            local eHas, eHash = GetCurrentPedWeapon(cache.ped, true)
            if eHas and eHash ~= 0 and eHash ~= `WEAPON_UNARMED` then
                heat = extHeat01 * cfg.MaxHeat
                if heat >= cfg.WarmThreshold then
                    local entity = GetCurrentPedWeaponEntityIndex(cache.ped)
                    if entity ~= 0 and DoesEntityExist(entity) then
                        if cfg.Mode == 'particle' then updateGlow(entity)
                        elseif cfg.Mode == 'light' then renderLight(entity)
                        else renderGlowSphere(entity) end
                    else stopGlow() end
                else
                    stopGlow()
                end
                lastClip = nil
                Wait(0)
                goto continue
            end
        end

        if not cfg.Enabled then
            if heat > 0 then heat = 0 end
            stopGlow()
            Wait(500)
            goto continue
        end
        local has, weaponHash = GetCurrentPedWeapon(cache.ped, true)
        local armed = has and weaponHash ~= 0 and weaponHash ~= `WEAPON_UNARMED`

        -- Cold-on-swap: drawing a DIFFERENT weapon resets heat; holstering does not
        -- (it stays hot, cooling on the back). Re-drawing the same hot weapon keeps it.
        if armed then
            if weaponHash ~= lastArmedHash then
                if weaponHash ~= suppHash then heat = 0 end
                lastClip = nil
                lastArmedHash = weaponHash
            end
        end

        local heldSupp = armed and heldWeaponHasSuppressor(weaponHash)
        if heldSupp then suppHash = weaponHash end

        if heat <= 0 and not heldSupp then
            -- Fully idle — nothing hot, no suppressed weapon in hand.
            suppHash = 0
            lastClip = nil
            stopGlow()
            Wait(400)
        else
            local dt = GetFrameTime()

            -- Detect shots by clip-ammo decrement (IsPedShooting is too brief per shot
            -- to count reliably); each round adds fixed heat. Only while in hand.
            if heldSupp then
                local _, clip = GetAmmoInClip(cache.ped, weaponHash)
                if lastClip and clip and clip < lastClip then
                    local shots = lastClip - clip
                    -- Only small per-tick drops are gunfire; a whole-magazine drop
                    -- (holster/unequip/reload) isn't a burst of fire — ignore it.
                    if shots <= (cfg.MaxShotsPerTick or 4) then
                        heat = math.min(cfg.MaxHeat, heat + shots * cfg.HeatPerShot)
                        lastShotTime = GetGameTimer()
                    end
                end
                lastClip = clip
            end

            if heat > 0 and (GetGameTimer() - lastShotTime) > cfg.DecayDelayMs then
                heat = math.max(0, heat - cfg.DecayRate * dt)
            end

            -- glowEntity resolves held weapon or slung prop; no entity → no render
            -- (never snap to a fallback position — that was the flicker).
            if heat >= cfg.WarmThreshold then
                local entity = glowEntity(suppHash ~= 0 and suppHash or weaponHash)
                if entity ~= 0 then
                    if cfg.Mode == 'particle' then
                        updateGlow(entity)
                    elseif cfg.Mode == 'light' then
                        renderLight(entity)
                    else  -- 'glow' (default)
                        renderGlowSphere(entity)
                    end
                else
                    stopGlow()
                end
            else
                stopGlow()
            end

            if heat <= 0 then suppHash = 0 end
            -- Per-frame while the glow is drawn or a gun is in hand (a draw-call glow flickers if
            -- not redrawn every frame); throttle only the invisible cooling tail. Decay is dt-based.
            if heldSupp or heat >= (cfg.WarmThreshold or 35) then Wait(0) else Wait(20) end
        end
        ::continue::
    end
end)
