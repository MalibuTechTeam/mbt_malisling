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
-- Throw groups are keyed by weapon-group HASH in config; the menu edits them by a
-- stable name. This maps menu name → group hash for round-tripping Allowed flags.
local THROW_GROUPS    = {
    MELEE = `GROUP_MELEE`, PISTOL = `GROUP_PISTOL`, RIFLE = `GROUP_RIFLE`,
    MG = `GROUP_MG`, SMG = `GROUP_SMG`, SHOTGUN = `GROUP_SHOTGUN`,
    STUNGUN = `GROUP_STUNGUN`, SNIPER = `GROUP_SNIPER`, HEAVY = `GROUP_HEAVY`,
}
local adminCommand    = (MBT.Admin and MBT.Admin.Command) or 'mbtconfig'
-- Default to the command's own ACE so a server with the usual
-- `add_ace group.admin command.* allow` (or a wildcard admin principal) works
-- with NO extra server.cfg lines — same as mbt_elevator.
local adminPerm       = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)

-- ox_inventory auto-patch outcome (set by modules/ox_patch/installer.js via a
-- server-local event). 'ok' = patched/present · '<reason>' = failed · nil = n/a
-- (qb-inventory / ox not found → the JS never reports). Surfaced in the sidebar.
local oxPatchStatus = nil

local function b(v) return v and true or false end
local function num(v, default) if type(v) == 'number' then return v end return default end

-- ── Snapshot: the config the dashboard reads (full state, incl. overview flags) ──
local function snapshot()
    local S, D = MBT.Sounds or {}, MBT.WeaponDrop or {}
    local DD, DL = D.Despawn or {}, D.Logging or {}
    local J, SH = MBT.Jamming or {}, MBT.SuppressorHeat or {}
    local SF, CH, WW = MBT.Safety or {}, MBT.ChargeWeapon or {}, MBT.WeaponWeight or {}
    local IN, WN = MBT.Inspect or {}, MBT.WeaponName or {}
    local SP, ND, VH, TS = MBT.ShowcasePoses or {}, MBT.NoDrawZones or {}, MBT.VehicleHiding or {}, MBT.TacticalSling or {}
    local VTR = MBT.VehicleTrunkRack or {}
    local CC = MBT.ChainOfCustody or {}
    local WR = MBT.WeaponRack or {}
    local SC = MBT.ShellCasings or {}
    local HO = MBT.Handoff or {}
    local SR = MBT.Serials or {}
    local CCY = MBT.ConcealedCarry or {}
    local cct = CCY.Tell or {}
    local PD = MBT.PatDown or {}
    local pdl = PD.Logging or {}
    local AS = MBT.AmmoSharing or {}
    local vat = VTR.AllowedTypes or {}
    local war = WR.AllowedTypes or {}
    local TH, INS = MBT.Throw or {}, IN.Show or {}
    local thg = TH.Groups or {}
    local throwGroups = {}
    for name, hash in pairs(THROW_GROUPS) do
        throwGroups[name] = b(thg[hash] and thg[hash].Allowed)
    end
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
            Logging = { Enabled = b(DL.Enabled), Webhook = DL.Webhook or '' },
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
        ConditionHUD = { Enabled = b(MBT.ConditionHUD and MBT.ConditionHUD.Enabled) },
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
        -- Interaction
        Inspect = {
            Enabled     = b(IN.Enabled),
            MaxDistance = num(IN.MaxDistance, 20.0),
            AmmoMode    = IN.AmmoMode or 'exact',
            Show        = {
                Serial = b(INS.Serial), Condition = b(INS.Condition),
                Name = b(INS.Name), Ammo = b(INS.Ammo),
            },
        },
        WeaponName = {
            Enabled       = b(WN.Enabled),
            MaxLength     = num(WN.MaxLength, 24),
            Permission    = WN.Permission or 'everyone',
            OncePerWeapon = b(WN.OncePerWeapon),
        },
        ShowcasePoses = {
            Enabled = b(SP.Enabled),
            Sync    = b(SP.Sync),
        },
        Throw = {
            Enabled = b(TH.Enabled),
            Groups  = throwGroups,
        },
        ChainOfCustody = {
            Enabled       = b(CC.Enabled),
            MaxEntries    = num(CC.MaxEntries, 10),
            ShowInInspect = b(CC.ShowInInspect),
        },
        -- World
        NoDrawZones = {
            Enabled        = b(ND.Enabled),
            AllowMelee     = b(ND.AllowMelee),
            HudIndicator   = b(ND.HudIndicator),
            NotifyCooldown = num(ND.NotifyCooldown, 3000),
        },
        VehicleHiding = {
            Enabled      = b(VH.Enabled),
            UseRoofCheck = b(VH.UseRoofCheck),
        },
        VehicleTrunkRack = {
            Enabled             = b(VTR.Enabled),
            Capacity            = num(VTR.Capacity, 2),
            InteractionDistance = num(VTR.InteractionDistance, 2.5),
            EquipOnRetrieve     = b(VTR.EquipOnRetrieve),
            AllowedTypes        = { back = b(vat['back']), back2 = b(vat['back2']) },
        },
        WeaponRack = {
            Enabled             = b(WR.Enabled),
            Capacity            = num(WR.Capacity, 4),
            InteractionDistance = num(WR.InteractionDistance, 2.0),
            EquipOnRetrieve     = b(WR.EquipOnRetrieve),
            AllowedTypes        = { back = b(war['back']), back2 = b(war['back2']), side = b(war['side']) },
            Logging             = { Enabled = b(WR.Logging and WR.Logging.Enabled),
                                    Webhook = (WR.Logging and WR.Logging.Webhook) or '' },
            Placement           = {
                Enabled      = b(WR.Placement and WR.Placement.Enabled),
                MaxPerPlayer = num(WR.Placement and WR.Placement.MaxPerPlayer, 2),
                AllowPickup  = b(WR.Placement and WR.Placement.AllowPickup),
                Access       = (WR.Placement and WR.Placement.Access) == 'owner' and 'owner' or 'everyone',
            },
        },
        TacticalSling = { Enabled = b(TS.Enabled) },
        ShellCasings = {
            Enabled       = b(SC.Enabled),
            Chance        = num(SC.Chance, 0.5),
            ExpireMinutes = num(SC.ExpireMinutes, 30),
            MaxCasings    = num(SC.MaxCasings, 150),
            SerialReveal  = (SC.SerialReveal == 'full' or SC.SerialReveal == 'none')
                            and SC.SerialReveal or 'partial',
            AllowCollect  = b(SC.AllowCollect),
        },
        Handoff = {
            Enabled       = b(HO.Enabled),
            MaxDistance   = num(HO.MaxDistance, 2.5),
            EquipOnAccept = b(HO.EquipOnAccept),
        },
        Serials = {
            EnsureGeneration = b(SR.EnsureGeneration),
            Format           = (SR.Format == 'oxlike') and 'oxlike' or 'marked',
            SweepOnLoad      = b(SR.SweepOnLoad),
        },
        ConcealedCarry = {
            Enabled          = b(CCY.Enabled),
            ToggleCooldownMs = num(CCY.ToggleCooldownMs, 3000),
            Tell = {
                Enabled     = cct.Enabled ~= false,
                RollSeconds = num(cct.RollSeconds, 25),
                ChanceGood  = num(cct.ChanceGood, 0.15),
                ChancePoor  = num(cct.ChancePoor, 0.45),
            },
        },
        PatDown = {
            Enabled        = b(PD.Enabled),
            RequireConsent = b(PD.RequireConsent),
            CuffedBypass   = b(PD.CuffedBypass),
            ShowAmmo       = b(PD.ShowAmmo),
            MaxDistance    = num(PD.MaxDistance, 2.0),
            Logging        = { Enabled = b(pdl.Enabled), Webhook = pdl.Webhook or '' },
        },
        AmmoSharing = {
            Enabled     = b(AS.Enabled),
            ShareAmount = num(AS.ShareAmount, 30),
            MaxDistance = num(AS.MaxDistance, 2.5),
        },
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
    -- Condition HUD
    if type(d.ConditionHUD) ~= 'table' or type(d.ConditionHUD.Enabled) ~= 'boolean' then return false end
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
    -- Inspect
    local ins = d.Inspect
    if type(ins) ~= 'table' or type(ins.Enabled) ~= 'boolean' then return false end
    if type(ins.MaxDistance) ~= 'number' or ins.MaxDistance < 1 or ins.MaxDistance > 50 then return false end
    if ins.AmmoMode ~= 'exact' and ins.AmmoMode ~= 'vague' then return false end
    if type(ins.Show) ~= 'table' then return false end
    if type(ins.Show.Serial) ~= 'boolean' or type(ins.Show.Condition) ~= 'boolean'
        or type(ins.Show.Name) ~= 'boolean' or type(ins.Show.Ammo) ~= 'boolean' then return false end
    -- Weapon Name
    local wn = d.WeaponName
    if type(wn) ~= 'table' or type(wn.Enabled) ~= 'boolean' then return false end
    if type(wn.MaxLength) ~= 'number' or wn.MaxLength < 1 or wn.MaxLength > 64 then return false end
    if wn.Permission ~= 'everyone' and wn.Permission ~= 'job' and wn.Permission ~= 'ace' then return false end
    if type(wn.OncePerWeapon) ~= 'boolean' then return false end
    -- Showcase Poses
    local sp = d.ShowcasePoses
    if type(sp) ~= 'table' or type(sp.Enabled) ~= 'boolean' or type(sp.Sync) ~= 'boolean' then return false end
    -- Throw
    local th = d.Throw
    if type(th) ~= 'table' or type(th.Enabled) ~= 'boolean' or type(th.Groups) ~= 'table' then return false end
    for name in pairs(THROW_GROUPS) do
        if type(th.Groups[name]) ~= 'boolean' then return false end
    end
    -- Chain of Custody
    local cc = d.ChainOfCustody
    if type(cc) ~= 'table' or type(cc.Enabled) ~= 'boolean' or type(cc.ShowInInspect) ~= 'boolean' then return false end
    if type(cc.MaxEntries) ~= 'number' or cc.MaxEntries < 2 or cc.MaxEntries > 50 then return false end
    -- No-Draw Zones
    local nd = d.NoDrawZones
    if type(nd) ~= 'table' or type(nd.Enabled) ~= 'boolean' then return false end
    if type(nd.AllowMelee) ~= 'boolean' or type(nd.HudIndicator) ~= 'boolean' then return false end
    if type(nd.NotifyCooldown) ~= 'number' or nd.NotifyCooldown < 500 or nd.NotifyCooldown > 30000 then return false end
    -- Vehicle Hiding
    local vh = d.VehicleHiding
    if type(vh) ~= 'table' or type(vh.Enabled) ~= 'boolean' or type(vh.UseRoofCheck) ~= 'boolean' then return false end
    -- Vehicle Trunk Rack
    local vtr = d.VehicleTrunkRack
    if type(vtr) ~= 'table' or type(vtr.Enabled) ~= 'boolean' then return false end
    if type(vtr.Capacity) ~= 'number' or vtr.Capacity < 1 or vtr.Capacity > 10 then return false end
    if type(vtr.InteractionDistance) ~= 'number' or vtr.InteractionDistance < 1 or vtr.InteractionDistance > 10 then return false end
    if type(vtr.EquipOnRetrieve) ~= 'boolean' then return false end
    if type(vtr.AllowedTypes) ~= 'table'
        or type(vtr.AllowedTypes.back) ~= 'boolean' or type(vtr.AllowedTypes.back2) ~= 'boolean' then return false end
    -- Weapon Rack
    local wr = d.WeaponRack
    if type(wr) ~= 'table' or type(wr.Enabled) ~= 'boolean' then return false end
    if type(wr.Capacity) ~= 'number' or wr.Capacity < 1 or wr.Capacity > 12 then return false end
    if type(wr.InteractionDistance) ~= 'number' or wr.InteractionDistance < 1 or wr.InteractionDistance > 10 then return false end
    if type(wr.EquipOnRetrieve) ~= 'boolean' then return false end
    if type(wr.AllowedTypes) ~= 'table'
        or type(wr.AllowedTypes.back) ~= 'boolean' or type(wr.AllowedTypes.back2) ~= 'boolean'
        or type(wr.AllowedTypes.side) ~= 'boolean' then return false end
    if type(wr.Logging) ~= 'table' or type(wr.Logging.Enabled) ~= 'boolean' then return false end
    if type(wr.Logging.Webhook) ~= 'string' or #wr.Logging.Webhook > 300 then return false end
    local wrp = wr.Placement
    if type(wrp) ~= 'table' or type(wrp.Enabled) ~= 'boolean' or type(wrp.AllowPickup) ~= 'boolean' then return false end
    if type(wrp.MaxPerPlayer) ~= 'number' or wrp.MaxPerPlayer < 1 or wrp.MaxPerPlayer > 20 then return false end
    if wrp.Access ~= 'everyone' and wrp.Access ~= 'owner' then return false end
    -- Tactical Sling
    local ts = d.TacticalSling
    if type(ts) ~= 'table' or type(ts.Enabled) ~= 'boolean' then return false end
    -- Shell Casings
    local sc = d.ShellCasings
    if type(sc) ~= 'table' or type(sc.Enabled) ~= 'boolean' or type(sc.AllowCollect) ~= 'boolean' then return false end
    if type(sc.Chance) ~= 'number' or sc.Chance < 0 or sc.Chance > 1 then return false end
    if type(sc.ExpireMinutes) ~= 'number' or sc.ExpireMinutes < 1 or sc.ExpireMinutes > 720 then return false end
    if type(sc.MaxCasings) ~= 'number' or sc.MaxCasings < 10 or sc.MaxCasings > 1000 then return false end
    if sc.SerialReveal ~= 'partial' and sc.SerialReveal ~= 'full' and sc.SerialReveal ~= 'none' then return false end
    -- Handoff
    local ho = d.Handoff
    if type(ho) ~= 'table' or type(ho.Enabled) ~= 'boolean' or type(ho.EquipOnAccept) ~= 'boolean' then return false end
    if type(ho.MaxDistance) ~= 'number' or ho.MaxDistance < 1 or ho.MaxDistance > 10 then return false end
    -- Serials
    local sr = d.Serials
    if type(sr) ~= 'table' or type(sr.EnsureGeneration) ~= 'boolean' or type(sr.SweepOnLoad) ~= 'boolean' then return false end
    if sr.Format ~= 'marked' and sr.Format ~= 'oxlike' then return false end
    -- Concealed Carry
    local ccy = d.ConcealedCarry
    if type(ccy) ~= 'table' or type(ccy.Enabled) ~= 'boolean' then return false end
    if type(ccy.ToggleCooldownMs) ~= 'number' or ccy.ToggleCooldownMs < 0 or ccy.ToggleCooldownMs > 60000 then return false end
    if type(ccy.Tell) ~= 'table' or type(ccy.Tell.Enabled) ~= 'boolean' then return false end
    if type(ccy.Tell.RollSeconds) ~= 'number' or ccy.Tell.RollSeconds < 5 or ccy.Tell.RollSeconds > 600 then return false end
    if type(ccy.Tell.ChanceGood) ~= 'number' or ccy.Tell.ChanceGood < 0 or ccy.Tell.ChanceGood > 1 then return false end
    if type(ccy.Tell.ChancePoor) ~= 'number' or ccy.Tell.ChancePoor < 0 or ccy.Tell.ChancePoor > 1 then return false end
    -- Pat-down
    local pd = d.PatDown
    if type(pd) ~= 'table' or type(pd.Enabled) ~= 'boolean' or type(pd.RequireConsent) ~= 'boolean'
        or type(pd.CuffedBypass) ~= 'boolean' or type(pd.ShowAmmo) ~= 'boolean' then return false end
    if type(pd.MaxDistance) ~= 'number' or pd.MaxDistance < 1 or pd.MaxDistance > 10 then return false end
    if type(pd.Logging) ~= 'table' or type(pd.Logging.Enabled) ~= 'boolean' then return false end
    if type(pd.Logging.Webhook) ~= 'string' or #pd.Logging.Webhook > 300 then return false end
    -- Ammo Sharing
    local as = d.AmmoSharing
    if type(as) ~= 'table' or type(as.Enabled) ~= 'boolean' then return false end
    if type(as.ShareAmount) ~= 'number' or as.ShareAmount < 1 or as.ShareAmount > 1000 then return false end
    if type(as.MaxDistance) ~= 'number' or as.MaxDistance < 1 or as.MaxDistance > 10 then return false end
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
    MBT.ConditionHUD.Enabled = d.ConditionHUD.Enabled
    MBT.ChargeWeapon.Enabled     = d.ChargeWeapon.Enabled
    MBT.ChargeWeapon.MaxDistance = d.ChargeWeapon.MaxDistance
    MBT.ChargeWeapon.Cooldown    = d.ChargeWeapon.Cooldown
    MBT.WeaponWeight.Enabled    = d.WeaponWeight.Enabled
    MBT.WeaponWeight.Mode       = d.WeaponWeight.Mode
    MBT.WeaponWeight.Threshold  = d.WeaponWeight.Threshold
    MBT.WeaponWeight.PerWeapon  = d.WeaponWeight.PerWeapon
    MBT.WeaponWeight.MaxPenalty = d.WeaponWeight.MaxPenalty
    -- Interaction
    MBT.Inspect.Enabled        = d.Inspect.Enabled
    MBT.Inspect.MaxDistance    = d.Inspect.MaxDistance
    MBT.Inspect.AmmoMode       = d.Inspect.AmmoMode
    MBT.Inspect.Show.Serial    = d.Inspect.Show.Serial
    MBT.Inspect.Show.Condition = d.Inspect.Show.Condition
    MBT.Inspect.Show.Name      = d.Inspect.Show.Name
    MBT.Inspect.Show.Ammo      = d.Inspect.Show.Ammo
    MBT.WeaponName.Enabled       = d.WeaponName.Enabled
    MBT.WeaponName.MaxLength     = d.WeaponName.MaxLength
    MBT.WeaponName.Permission    = d.WeaponName.Permission
    MBT.WeaponName.OncePerWeapon = d.WeaponName.OncePerWeapon
    MBT.ShowcasePoses.Enabled = d.ShowcasePoses.Enabled
    MBT.ShowcasePoses.Sync    = d.ShowcasePoses.Sync
    MBT.Throw.Enabled = d.Throw.Enabled
    for name, hash in pairs(THROW_GROUPS) do
        if MBT.Throw.Groups[hash] then
            MBT.Throw.Groups[hash].Allowed = d.Throw.Groups[name]
        end
    end
    if MBT.ChainOfCustody then
        MBT.ChainOfCustody.Enabled       = d.ChainOfCustody.Enabled
        MBT.ChainOfCustody.MaxEntries    = d.ChainOfCustody.MaxEntries
        MBT.ChainOfCustody.ShowInInspect = d.ChainOfCustody.ShowInInspect
    end
    -- World
    MBT.NoDrawZones.Enabled        = d.NoDrawZones.Enabled
    MBT.NoDrawZones.AllowMelee     = d.NoDrawZones.AllowMelee
    MBT.NoDrawZones.HudIndicator   = d.NoDrawZones.HudIndicator
    MBT.NoDrawZones.NotifyCooldown = d.NoDrawZones.NotifyCooldown
    MBT.VehicleHiding.Enabled      = d.VehicleHiding.Enabled
    MBT.VehicleHiding.UseRoofCheck = d.VehicleHiding.UseRoofCheck
    if MBT.VehicleTrunkRack then
        MBT.VehicleTrunkRack.Enabled             = d.VehicleTrunkRack.Enabled
        MBT.VehicleTrunkRack.Capacity            = d.VehicleTrunkRack.Capacity
        MBT.VehicleTrunkRack.InteractionDistance = d.VehicleTrunkRack.InteractionDistance
        MBT.VehicleTrunkRack.EquipOnRetrieve     = d.VehicleTrunkRack.EquipOnRetrieve
        MBT.VehicleTrunkRack.AllowedTypes        = {
            ['back']  = d.VehicleTrunkRack.AllowedTypes.back,
            ['back2'] = d.VehicleTrunkRack.AllowedTypes.back2,
        }
    end
    if MBT.WeaponRack then
        MBT.WeaponRack.Enabled             = d.WeaponRack.Enabled
        MBT.WeaponRack.Capacity            = d.WeaponRack.Capacity
        MBT.WeaponRack.InteractionDistance = d.WeaponRack.InteractionDistance
        MBT.WeaponRack.EquipOnRetrieve     = d.WeaponRack.EquipOnRetrieve
        MBT.WeaponRack.AllowedTypes        = {
            ['back']  = d.WeaponRack.AllowedTypes.back,
            ['back2'] = d.WeaponRack.AllowedTypes.back2,
            ['side']  = d.WeaponRack.AllowedTypes.side,
        }
        MBT.WeaponRack.Logging = MBT.WeaponRack.Logging or {}
        MBT.WeaponRack.Logging.Enabled = d.WeaponRack.Logging.Enabled
        MBT.WeaponRack.Logging.Webhook = d.WeaponRack.Logging.Webhook
        MBT.WeaponRack.Placement = MBT.WeaponRack.Placement or {}
        MBT.WeaponRack.Placement.Enabled      = d.WeaponRack.Placement.Enabled
        MBT.WeaponRack.Placement.MaxPerPlayer = d.WeaponRack.Placement.MaxPerPlayer
        MBT.WeaponRack.Placement.AllowPickup  = d.WeaponRack.Placement.AllowPickup
        MBT.WeaponRack.Placement.Access       = d.WeaponRack.Placement.Access
    end
    MBT.TacticalSling.Enabled = d.TacticalSling.Enabled
    if MBT.ShellCasings then
        MBT.ShellCasings.Enabled       = d.ShellCasings.Enabled
        MBT.ShellCasings.Chance        = d.ShellCasings.Chance
        MBT.ShellCasings.ExpireMinutes = d.ShellCasings.ExpireMinutes
        MBT.ShellCasings.MaxCasings    = d.ShellCasings.MaxCasings
        MBT.ShellCasings.SerialReveal  = d.ShellCasings.SerialReveal
        MBT.ShellCasings.AllowCollect  = d.ShellCasings.AllowCollect
    end
    if MBT.Handoff then
        MBT.Handoff.Enabled       = d.Handoff.Enabled
        MBT.Handoff.MaxDistance   = d.Handoff.MaxDistance
        MBT.Handoff.EquipOnAccept = d.Handoff.EquipOnAccept
    end
    if MBT.Serials then
        MBT.Serials.EnsureGeneration = d.Serials.EnsureGeneration
        MBT.Serials.Format           = d.Serials.Format
        MBT.Serials.SweepOnLoad      = d.Serials.SweepOnLoad
    end
    if MBT.ConcealedCarry then
        MBT.ConcealedCarry.Enabled          = d.ConcealedCarry.Enabled
        MBT.ConcealedCarry.ToggleCooldownMs = d.ConcealedCarry.ToggleCooldownMs
        MBT.ConcealedCarry.Tell = MBT.ConcealedCarry.Tell or {}
        MBT.ConcealedCarry.Tell.Enabled     = d.ConcealedCarry.Tell.Enabled
        MBT.ConcealedCarry.Tell.RollSeconds = d.ConcealedCarry.Tell.RollSeconds
        MBT.ConcealedCarry.Tell.ChanceGood  = d.ConcealedCarry.Tell.ChanceGood
        MBT.ConcealedCarry.Tell.ChancePoor  = d.ConcealedCarry.Tell.ChancePoor
    end
    if MBT.PatDown then
        MBT.PatDown.Enabled        = d.PatDown.Enabled
        MBT.PatDown.RequireConsent = d.PatDown.RequireConsent
        MBT.PatDown.CuffedBypass   = d.PatDown.CuffedBypass
        MBT.PatDown.ShowAmmo       = d.PatDown.ShowAmmo
        MBT.PatDown.MaxDistance    = d.PatDown.MaxDistance
        MBT.PatDown.Logging = MBT.PatDown.Logging or {}
        MBT.PatDown.Logging.Enabled = d.PatDown.Logging.Enabled
        MBT.PatDown.Logging.Webhook = d.PatDown.Logging.Webhook
    end
    if MBT.AmmoSharing then
        MBT.AmmoSharing.Enabled     = d.AmmoSharing.Enabled
        MBT.AmmoSharing.ShareAmount = d.AmmoSharing.ShareAmount
        MBT.AmmoSharing.MaxDistance = d.AmmoSharing.MaxDistance
    end
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
        ConditionHUD = d.ConditionHUD,
        ChargeWeapon = d.ChargeWeapon,
        WeaponWeight = d.WeaponWeight,
        Inspect = d.Inspect,
        WeaponName = d.WeaponName,
        ShowcasePoses = d.ShowcasePoses,
        Throw = d.Throw,
        NoDrawZones = d.NoDrawZones,
        VehicleHiding = d.VehicleHiding,
        VehicleTrunkRack = d.VehicleTrunkRack,
        ChainOfCustody = d.ChainOfCustody,
        WeaponRack = d.WeaponRack,
        TacticalSling = d.TacticalSling,
        ShellCasings = d.ShellCasings,
        Handoff = d.Handoff,
        Serials = d.Serials,
        ConcealedCarry = d.ConcealedCarry,
        PatDown = d.PatDown,
        AmmoSharing = d.AmmoSharing,
    }
end

--- Deep-merge SAVED values onto the live template: only keys present in the
--- template are read from the file (type-checked); anything missing — e.g. a
--- feature block added after the file was saved — keeps its config.lua default.
--- Schema auto-migration: an older runtime_config can never wipe the whole
--- saved state again, it just gains the new defaults.
local function mergeKnown(template, saved)
    if type(saved) ~= 'table' then return template end
    local out = {}
    for k, tv in pairs(template) do
        local sv = saved[k]
        if type(tv) == 'table' then
            out[k] = mergeKnown(tv, sv)
        elseif sv ~= nil and type(sv) == type(tv) then
            out[k] = sv
        else
            out[k] = tv
        end
    end
    return out
end

local function loadRuntimeConfig()
    local raw = LoadResourceFile(GetCurrentResourceName(), CONFIG_FILE)
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        Utils.mbtWarn('runtime_config.json unreadable, ignoring')
        return
    end
    -- Merge over the current live snapshot (config.lua defaults + any feature
    -- blocks the file predates), then validate the COMPLETE result.
    local merged = mergeKnown(snapshot(), data)
    if not validate(merged) then
        Utils.mbtWarn('runtime_config.json failed validation after merge, ignoring')
        return
    end
    applyToMBT(merged)
    Utils.mbtDebugger('Runtime config loaded from', CONFIG_FILE)
end

--- Send the dashboard to an authorized admin.
local function openFor(src)
    -- Non-critical integration warnings → discreet chips in the dashboard overview.
    -- Providers are registered at runtime by the bridges (e.g. the qb bridge detects
    -- qb-weapons' weapdraw), so there's no user config here. Critical failures use the
    -- centered alert instead. pcall so a faulty provider can't block the dashboard.
    local warnings = {}
    for _, provider in ipairs(MBT.IntegrationWarnings or {}) do
        local ok, w = pcall(provider)
        if ok and w then warnings[#warnings + 1] = w end
    end

    TriggerClientEvent('mbt_malisling:openAdmin', src, {
        config   = snapshot(),
        version  = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'v2',
        oxPatch  = oxPatchStatus or false,   -- 'ok' | failure reason | false (n/a) → sidebar status
        warnings = warnings,                 -- non-critical integration chips
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

-- ox_inventory auto-patch outcome from the JS patcher (server-local event, not a
-- net event → clients cannot spoof it). Stored and shown in the dashboard sidebar
-- to admins (openFor includes it in the openAdmin payload).
AddEventHandler('mbt_malisling:oxPatchResult', function(ok, reason)
    if ok then oxPatchStatus = 'ok' return end
    oxPatchStatus = (type(reason) == 'string' and reason ~= '') and reason or 'see server console'
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
