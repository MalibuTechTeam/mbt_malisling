-- ─────────────────────────────────────────────────────────────────────────────
-- Suppressor Heat Glow
--
-- The suppressor heats up during sustained fire and visibly glows orange -> red,
-- then cools down over a few seconds. Purely visual, no combat impact (combat
-- mechanics belong to mbt_shooting).
--
-- Heat only accumulates while the weapon is in hand (that is when you fire it),
-- but the glow keeps rendering — and cooling — on the matching slung prop after
-- you holster, which reads as more realistic than the glow snapping off. We draw
-- the glow at the prop's gun_muzzle world position: a plain draw call, unaffected
-- by the engine quirks that make slung-weapon *flashlight* attachment unreliable.
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the feature block exists; Enabled is checked in the loop so the admin
-- menu can toggle it live (cfg is the live MBT.SuppressorHeat table).
if not MBT.SuppressorHeat then return end

local cfg = MBT.SuppressorHeat

local heat            = 0   -- 0 .. cfg.MaxHeat
local lastShotTime    = 0
local lastArmedHash   = 0   -- last non-unarmed weapon held (for cold-on-swap reset)
local suppHash        = 0   -- weapon hash whose suppressor currently holds the heat
local lastClip        = nil -- clip ammo last frame, to detect shots fired
local suppressorComps = {}

--- Collect every suppressor component hash from the weapon data malisling
--- loaded at runtime (ox_inventory's data/weapons.lua → MBT.WeaponsInfo).
--- Suppressors are tagged type='muzzle'; key-name match is a fallback.
---@return boolean ok  true if at least one suppressor component was found
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
        -- HasPedGotWeaponComponent returns a boolean on modern FiveM (and 1/0 on
        -- older builds) — accept both, never compare strictly against 1.
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
--- The entity to glow on: the weapon in hand if armed, otherwise the matching
--- slung prop on the player's back so the suppressor keeps glowing and visibly
--- cools after holstering (more realistic than snapping off).
---
--- The slung prop is one of the local player's CreateWeaponObject entities tracked
--- by core/client.lua in playersToTrack[cache.serverId][slot]; we match it by model
--- (GetEntityModel == GetWeapontypeModel) so it works on any slot. Drawing on its
--- gun_muzzle bone is just a world-space draw call — unlike the slung-flashlight
--- attach, it isn't affected by the engine quirks the header warns about.
---@param weaponHash number  hash of the (possibly holstered) suppressed weapon
---@return number entity  0 if neither held nor slung prop is available
local function glowEntity(weaponHash)
    local held = GetCurrentPedWeaponEntityIndex(cache.ped)
    if held and held ~= 0 and DoesEntityExist(held) then
        return held
    end

    if not weaponHash or weaponHash == 0 then return 0 end
    local mine = playersToTrack and playersToTrack[cache.serverId]
    if not mine then return 0 end

    local wantModel = GetWeapontypeModel(weaponHash)
    for _, ent in pairs(mine) do
        if type(ent) == 'number' and ent ~= 0 and DoesEntityExist(ent)
            and GetEntityModel(ent) == wantModel then
            return ent
        end
    end
    return 0
end

--- World position of the given weapon entity's muzzle (no hand fallback: snapping
--- to the hand bone when the entity is gone is exactly what caused the holster
--- flicker). Returns nil when the entity is invalid so callers can skip drawing.
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

--- Start / maintain the looped heat-glow particle on the weapon's muzzle.
--- Tints orange -> red and scales with heat. Works on the held weapon or, once
--- holstered, the matching slung prop (entity resolved by the caller).
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
        if not cfg.Enabled then
            if heat > 0 then heat = 0 end
            stopGlow()
            Wait(500)
            goto continue
        end
        local has, weaponHash = GetCurrentPedWeapon(cache.ped, true)
        local armed = has and weaponHash ~= 0 and weaponHash ~= `WEAPON_UNARMED`

        -- Cold-on-swap: drawing a DIFFERENT weapon than the last armed one resets
        -- heat. Holstering (going unarmed) does NOT — the suppressor stays hot and
        -- keeps cooling on the back. Re-drawing the same still-hot weapon keeps it.
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

            -- Detect shots via clip-ammo decrement: IsPedShooting is true for too
            -- few frames per shot to accumulate heat reliably. Each round fired
            -- adds a fixed amount of heat. Only while the gun is in hand.
            if heldSupp then
                local _, clip = GetAmmoInClip(cache.ped, weaponHash)
                if lastClip and clip and clip < lastClip then
                    local shots = lastClip - clip
                    -- Only small per-tick drops are gunfire. A whole-magazine drop
                    -- (holster / unequip / reload glitch) is implausible as fire and
                    -- would otherwise spike heat and light the suppressor on the back
                    -- without a shot being fired — ignore it.
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

            -- Render on the held weapon, or on the matching slung prop once holstered
            -- (glowEntity resolves both). No render when no valid entity exists, so
            -- the glow never snaps to a fallback position — that was the flicker.
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
            -- Per-frame only while the weapon is in hand or genuinely hot (where the glow throb
            -- reads best); when it's just cooling on the slung back-prop, 60fps is overkill. Decay
            -- stays correct (it's GetFrameTime-based, so the larger dt compensates).
            if heldSupp or heat >= (cfg.HotThreshold or 75) then Wait(0) else Wait(20) end
        end
        ::continue::
    end
end)
