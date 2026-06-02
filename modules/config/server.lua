-- ─────────────────────────────────────────────────────────────────────────────
-- Admin config — server
--
-- Powers the admin dashboard (modules/admin NUI). On /mbtconfig the server ACE-
-- checks the player and sends a full config snapshot; on save it validates,
-- applies live to MBT.* on every client (broadcast), and persists the runtime-safe
-- fields to runtime_config.json so they survive a restart.
--
-- Built per-section so new sections plug in by extending snapshot()/applyGeneral
-- etc. Phase 1 wires the General section end-to-end; more sections follow.
-- ─────────────────────────────────────────────────────────────────────────────

local CONFIG_FILE     = 'data/runtime_config.json'
local VALID_POSITIONS = { ['bottom-center'] = true, ['top-center'] = true, ['bottom-right'] = true, ['custom'] = true }
local adminCommand    = (MBT.Admin and MBT.Admin.Command) or 'mbtconfig'
-- Default to the command's own ACE so a server with the usual
-- `add_ace group.admin command.* allow` (or a wildcard admin principal) works
-- with NO extra server.cfg lines — same as mbt_elevator.
local adminPerm       = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)

local function b(v) return v and true or false end
local function num(v, default) if type(v) == 'number' then return v end return default end

-- ── Snapshot: the config the dashboard reads (full state, incl. overview flags) ──
local function snapshot()
    local S, D = MBT.Sounds or {}, MBT.WeaponDrop or {}
    local DD, DL = D.Despawn or {}, D.Logging or {}
    local J, SH = MBT.Jamming or {}, MBT.SuppressorHeat or {}
    local SF, CH, WW = MBT.Safety or {}, MBT.ChargeWeapon or {}, MBT.WeaponWeight or {}
    return {
        -- General (editable). Debug is intentionally NOT exposed (dev flag → config.lua).
        EnableSling       = b(MBT.EnableSling),
        EnableFlashlight  = b(MBT.EnableFlashlight),
        DropWeaponOnDeath = b(MBT.DropWeaponOnDeath),
        UIPosition        = MBT.UI.Position,
        Language          = MBT.Language,            -- read-only in the UI
        -- Holster & Sounds
        Sounds = {
            Enabled     = b(S.Enabled),
            MaxDistance = num(S.MaxDistance, 8.0),
            Volume      = num(S.Volume, 0.3),
        },
        -- Weapon Drop
        WeaponDrop = {
            WeaponModelProp = b(D.WeaponModelProp),
            OxTargetPickup  = b(D.OxTargetPickup),
            Despawn = { Enabled = b(DD.Enabled), Seconds = num(DD.Seconds, 300), BlinkLastSec = num(DD.BlinkLastSec, 10) },
            Logging = { Enabled = b(DL.Enabled), Webhook = DL.Webhook or '', Console = b(DL.Console) },
        },
        -- Combat / RP
        Jamming = {
            Enabled      = b(J.Enabled),
            Cooldown     = num(J.Cooldown, 5),
            UnjamPresses = num(J.Unjam and J.Unjam.Presses, 5),
        },
        SuppressorHeat = {
            Enabled       = b(SH.Enabled),
            Mode          = SH.Mode or 'glow',
            HeatPerShot   = num(SH.HeatPerShot, 5),
            DecayRate     = num(SH.DecayRate, 16),
            WarmThreshold = num(SH.WarmThreshold, 35),
            HotThreshold  = num(SH.HotThreshold, 75),
        },
        Safety = {
            Enabled      = b(SF.Enabled),
            DefaultOn    = b(SF.DefaultOn),
            PerWeapon    = b(SF.PerWeapon),
            HudIndicator = b(SF.HudIndicator),
        },
        ChargeWeapon = {
            Enabled     = b(CH.Enabled),
            MaxDistance = num(CH.MaxDistance, 20.0),
            Cooldown    = num(CH.Cooldown, 1500),
        },
        WeaponWeight = {
            Enabled    = b(WW.Enabled),
            Mode       = WW.Mode or 'light',
            Threshold  = num(WW.Threshold, 2),
            PerWeapon  = num(WW.PerWeapon, 0.03),
            MaxPenalty = num(WW.MaxPenalty, 0.18),
        },
        -- Overview flags (editable in their own sections later)
        Inspect           = { Enabled = b(MBT.Inspect and MBT.Inspect.Enabled) },
        NoDrawZones       = { Enabled = b(MBT.NoDrawZones and MBT.NoDrawZones.Enabled) },
        TacticalSling     = { Enabled = b(MBT.TacticalSling and MBT.TacticalSling.Enabled) },
    }
end

-- ── Validate only the runtime-safe (editable) fields ─────────────────────────────
local function validate(d)
    if type(d) ~= 'table' then return false end
    -- General
    if type(d.EnableSling) ~= 'boolean' then return false end
    if type(d.EnableFlashlight) ~= 'boolean' then return false end
    if type(d.DropWeaponOnDeath) ~= 'boolean' then return false end
    if type(d.UIPosition) ~= 'string' or not VALID_POSITIONS[d.UIPosition] then return false end
    -- Sounds
    if type(d.Sounds) ~= 'table' then return false end
    if type(d.Sounds.Enabled) ~= 'boolean' then return false end
    if type(d.Sounds.MaxDistance) ~= 'number' or d.Sounds.MaxDistance < 1 or d.Sounds.MaxDistance > 50 then return false end
    if type(d.Sounds.Volume) ~= 'number' or d.Sounds.Volume < 0 or d.Sounds.Volume > 1 then return false end
    -- Weapon Drop
    if type(d.WeaponDrop) ~= 'table' then return false end
    if type(d.WeaponDrop.WeaponModelProp) ~= 'boolean' then return false end
    if type(d.WeaponDrop.OxTargetPickup) ~= 'boolean' then return false end
    local dd = d.WeaponDrop.Despawn
    if type(dd) ~= 'table' or type(dd.Enabled) ~= 'boolean' then return false end
    if type(dd.Seconds) ~= 'number' or dd.Seconds < 5 or dd.Seconds > 3600 then return false end
    if type(dd.BlinkLastSec) ~= 'number' or dd.BlinkLastSec < 0 or dd.BlinkLastSec > 60 then return false end
    local dl = d.WeaponDrop.Logging
    if type(dl) ~= 'table' or type(dl.Enabled) ~= 'boolean' then return false end
    if type(dl.Webhook) ~= 'string' or #dl.Webhook > 300 then return false end
    if type(dl.Console) ~= 'boolean' then return false end
    -- Jamming
    local j = d.Jamming
    if type(j) ~= 'table' or type(j.Enabled) ~= 'boolean' then return false end
    if type(j.Cooldown) ~= 'number' or j.Cooldown < 1 or j.Cooldown > 120 then return false end
    if type(j.UnjamPresses) ~= 'number' or j.UnjamPresses < 1 or j.UnjamPresses > 20 then return false end
    -- Suppressor Heat
    local sh = d.SuppressorHeat
    if type(sh) ~= 'table' or type(sh.Enabled) ~= 'boolean' then return false end
    if sh.Mode ~= 'glow' and sh.Mode ~= 'light' and sh.Mode ~= 'particle' then return false end
    if type(sh.HeatPerShot) ~= 'number' or sh.HeatPerShot < 1 or sh.HeatPerShot > 100 then return false end
    if type(sh.DecayRate) ~= 'number' or sh.DecayRate < 1 or sh.DecayRate > 100 then return false end
    if type(sh.WarmThreshold) ~= 'number' or sh.WarmThreshold < 0 or sh.WarmThreshold > 100 then return false end
    if type(sh.HotThreshold) ~= 'number' or sh.HotThreshold < 0 or sh.HotThreshold > 100 then return false end
    -- Safety
    local sf = d.Safety
    if type(sf) ~= 'table' or type(sf.Enabled) ~= 'boolean' then return false end
    if type(sf.DefaultOn) ~= 'boolean' or type(sf.PerWeapon) ~= 'boolean' or type(sf.HudIndicator) ~= 'boolean' then return false end
    -- Charge Weapon
    local ch = d.ChargeWeapon
    if type(ch) ~= 'table' or type(ch.Enabled) ~= 'boolean' then return false end
    if type(ch.MaxDistance) ~= 'number' or ch.MaxDistance < 1 or ch.MaxDistance > 100 then return false end
    if type(ch.Cooldown) ~= 'number' or ch.Cooldown < 0 or ch.Cooldown > 10000 then return false end
    -- Weapon Weight
    local ww = d.WeaponWeight
    if type(ww) ~= 'table' or type(ww.Enabled) ~= 'boolean' then return false end
    local validModes = { off = true, light = true, medium = true, heavy = true, custom = true }
    if type(ww.Mode) ~= 'string' or not validModes[ww.Mode] then return false end
    if type(ww.Threshold) ~= 'number' or ww.Threshold < 0 or ww.Threshold > 20 then return false end
    if type(ww.PerWeapon) ~= 'number' or ww.PerWeapon < 0 or ww.PerWeapon > 1 then return false end
    if type(ww.MaxPenalty) ~= 'number' or ww.MaxPenalty < 0 or ww.MaxPenalty > 0.9 then return false end
    return true
end

-- ── Apply the editable fields to MBT.* (server side) ─────────────────────────────
local function applyToMBT(d)
    MBT.EnableSling       = d.EnableSling
    MBT.EnableFlashlight  = d.EnableFlashlight
    MBT.DropWeaponOnDeath = d.DropWeaponOnDeath
    MBT.UI.Position       = d.UIPosition
    MBT.Sounds.Enabled     = d.Sounds.Enabled
    MBT.Sounds.MaxDistance = d.Sounds.MaxDistance
    MBT.Sounds.Volume      = d.Sounds.Volume
    MBT.WeaponDrop.WeaponModelProp     = d.WeaponDrop.WeaponModelProp
    MBT.WeaponDrop.OxTargetPickup      = d.WeaponDrop.OxTargetPickup
    MBT.WeaponDrop.Despawn.Enabled     = d.WeaponDrop.Despawn.Enabled
    MBT.WeaponDrop.Despawn.Seconds     = d.WeaponDrop.Despawn.Seconds
    MBT.WeaponDrop.Despawn.BlinkLastSec= d.WeaponDrop.Despawn.BlinkLastSec
    MBT.WeaponDrop.Logging.Enabled     = d.WeaponDrop.Logging.Enabled
    MBT.WeaponDrop.Logging.Webhook     = d.WeaponDrop.Logging.Webhook
    MBT.WeaponDrop.Logging.Console     = d.WeaponDrop.Logging.Console
    -- Combat / RP
    MBT.Jamming.Enabled          = d.Jamming.Enabled
    MBT.Jamming.Cooldown         = d.Jamming.Cooldown
    MBT.Jamming.Unjam.Presses    = d.Jamming.UnjamPresses
    MBT.SuppressorHeat.Enabled       = d.SuppressorHeat.Enabled
    MBT.SuppressorHeat.Mode          = d.SuppressorHeat.Mode
    MBT.SuppressorHeat.HeatPerShot   = d.SuppressorHeat.HeatPerShot
    MBT.SuppressorHeat.DecayRate     = d.SuppressorHeat.DecayRate
    MBT.SuppressorHeat.WarmThreshold = d.SuppressorHeat.WarmThreshold
    MBT.SuppressorHeat.HotThreshold  = d.SuppressorHeat.HotThreshold
    MBT.Safety.Enabled      = d.Safety.Enabled
    MBT.Safety.DefaultOn    = d.Safety.DefaultOn
    MBT.Safety.PerWeapon    = d.Safety.PerWeapon
    MBT.Safety.HudIndicator = d.Safety.HudIndicator
    MBT.ChargeWeapon.Enabled     = d.ChargeWeapon.Enabled
    MBT.ChargeWeapon.MaxDistance = d.ChargeWeapon.MaxDistance
    MBT.ChargeWeapon.Cooldown    = d.ChargeWeapon.Cooldown
    MBT.WeaponWeight.Enabled    = d.WeaponWeight.Enabled
    MBT.WeaponWeight.Mode       = d.WeaponWeight.Mode
    MBT.WeaponWeight.Threshold  = d.WeaponWeight.Threshold
    MBT.WeaponWeight.PerWeapon  = d.WeaponWeight.PerWeapon
    MBT.WeaponWeight.MaxPenalty = d.WeaponWeight.MaxPenalty
end

--- The editable subset that gets persisted (overview-only flags excluded).
local function persistable(d)
    return {
        EnableSling = d.EnableSling, EnableFlashlight = d.EnableFlashlight,
        DropWeaponOnDeath = d.DropWeaponOnDeath, UIPosition = d.UIPosition,
        Sounds = { Enabled = d.Sounds.Enabled, MaxDistance = d.Sounds.MaxDistance, Volume = d.Sounds.Volume },
        WeaponDrop = {
            WeaponModelProp = d.WeaponDrop.WeaponModelProp, OxTargetPickup = d.WeaponDrop.OxTargetPickup,
            Despawn = d.WeaponDrop.Despawn, Logging = d.WeaponDrop.Logging,
        },
        Jamming = d.Jamming,
        SuppressorHeat = d.SuppressorHeat,
        Safety = d.Safety,
        ChargeWeapon = d.ChargeWeapon,
        WeaponWeight = d.WeaponWeight,
    }
end

local function loadRuntimeConfig()
    local raw = LoadResourceFile(GetCurrentResourceName(), CONFIG_FILE)
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or not validate(data) then
        Utils.mbtWarn('runtime_config.json invalid or from an old format, ignoring')
        return
    end
    applyToMBT(data)
    Utils.mbtDebugger('Runtime config loaded from', CONFIG_FILE)
end

--- Send the dashboard to an authorized admin.
local function openFor(src)
    TriggerClientEvent('mbt_malisling:openAdmin', src, {
        config  = snapshot(),
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'v2',
    })
end

-- Command registered SERVER-side (like mbt_elevator) so FiveM auto-registers its
-- ACE — a wildcard admin principal then works with no extra server.cfg lines.
RegisterCommand(adminCommand, function(source)
    if source == 0 then return end  -- console
    if IsPlayerAceAllowed(source, adminPerm) then
        openFor(source)
    else
        TriggerClientEvent('mbt_malisling:notifyLabel', source, 'admin_no_perm')
    end
end, false)

-- Keybind / client request path — server re-validates ACE.
RegisterNetEvent('mbt_malisling:requestConfig', function()
    local src = source
    if IsPlayerAceAllowed(src, adminPerm) then openFor(src) end
end)

RegisterNetEvent('mbt_malisling:adminSave', function(data)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if not validate(data) then
        Utils.mbtWarn('adminSave ~ invalid payload from player', src)
        return
    end
    applyToMBT(data)
    SaveResourceFile(GetCurrentResourceName(), CONFIG_FILE, json.encode(persistable(data)), -1)
    TriggerClientEvent('mbt_malisling:applyConfig', -1, persistable(data))
    Utils.mbtDebugger('Admin config saved by player', src)
end)

-- Clients fetch the current live config when they (re)initialise, so a resource
-- restart or a fresh join picks up runtime_config without needing a save. Returns
-- the editable snapshot the client's applyConfig handler consumes.
lib.callback.register('mbt_malisling:getRuntimeConfig', function()
    return persistable(snapshot())
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadRuntimeConfig()
end)
