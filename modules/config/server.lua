-- ─────────────────────────────────────────────────────────────────────────────
-- Admin config — server
--
-- Powers the admin dashboard. On /mbt_malisling: ACE-check, send config snapshot. On
-- save: validate, apply live to MBT.* on every client (broadcast), persist.
-- Built per-section so new sections plug in via snapshot()/apply.
-- ─────────────────────────────────────────────────────────────────────────────

local VALID_POSITIONS = { ['bottom-center'] = true, ['top-center'] = true, ['bottom-right'] = true, ['custom'] = true }
-- Fallback only — the real factory value lives in default.lua (MBT.Accent).
local DEFAULT_ACCENT  = '#00E676'
-- Maps menu name → group hash: config keys throw groups by HASH, the menu by name.
local THROW_GROUPS    = {
    MELEE = `GROUP_MELEE`, PISTOL = `GROUP_PISTOL`, RIFLE = `GROUP_RIFLE`,
    MG = `GROUP_MG`, SMG = `GROUP_SMG`, SHOTGUN = `GROUP_SHOTGUN`,
    STUNGUN = `GROUP_STUNGUN`, SNIPER = `GROUP_SNIPER`, HEAVY = `GROUP_HEAVY`,
}
local adminCommand    = (MBT.Admin and MBT.Admin.Command) or GetCurrentResourceName()
-- Default to the command's own ACE so a wildcard admin principal works with NO
-- extra server.cfg lines — same as mbt_elevator.
local adminPerm       = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)

-- MBT.HiddenByJob as config.lua left it, captured before any DB row lands on top. It seeds
-- a fresh install and it is what "Restore from config.lua" comes back to — copied, because
-- applyToMBT replaces the live table and the seed has to outlive that.
local HIDDEN_BY_JOB_SEED = Utils.tableDeepCopy(MBT.HiddenByJob or {})

-- ox_inventory auto-patch outcome (set by ox_patch/installer.js, server-local event).
-- 'ok' = patched · '<reason>' = failed · nil = n/a. Surfaced in the sidebar.
local oxPatchStatus = nil

-- Keybinds moved to config.lua in 2.0.2, and default.lua now holds '' so that commenting
-- a line out actually unbinds instead of quietly restoring the default. That leaves one
-- trap: updating while KEEPING a config.lua from 2.0.1 or earlier. Those files have no
-- Keybinds block, nothing populates the keys, and every bind lands unassigned — with no
-- error, looking like a broken script.
--
-- Nobody deliberately unbinds all of them, so all-empty means exactly one thing. Server
-- side on purpose: this is for the console the owner reads, not a player's F8.
CreateThread(function()
    Wait(2000)   -- let config.lua and every feature block finish loading
    local blocks = { 'Inspect', 'ConcealedCarry', 'PatDown', 'Handoff', 'AmmoSharing',
                     'Throw', 'LowReady', 'Safety', 'ChargeWeapon' }
    for _, name in ipairs(blocks) do
        local b = MBT[name]
        if b and type(b.Key) == 'string' and b.Key ~= '' then return end   -- at least one bound
    end
    Utils.mbtWarn(
        "No keybinds are set. Since 2.0.2 they live in config.lua — if you kept a " ..
        "config.lua from an older version, copy the Keybinds block out of the new one. " ..
        "Every feature still has its chat command in the meantime."
    )
end)

local function b(v) return v and true or false end
local function num(v, default) if type(v) == 'number' then return v end return default end

-- The classes an offset exists for. NOT 'standard': the slot's tuned position IS the
-- standard, so a standard offset would be a second way to say the same thing — two
-- controls that move the same weapon, and no way to tell from the numbers which one did.
local OFFSET_CLASSES = { 'compact', 'long' }

--- The class offsets as a COMPLETE shape (every slot in default.lua, both classes, Pos and
--- Rot), whatever the live table happens to hold. mergeKnown walks the template, so a key
--- missing here can never be restored from a saved row — and the shipped defaults carry
--- Pos only.
---@param src table?  defaults to the live table; the captured defaults when resetting
local function classOffsetSnapshot(src)
    local out = {}
    for slot, byClass in pairs(src or MBT.WeaponClassOffsets or {}) do
        local s = {}
        for _, class in ipairs(OFFSET_CLASSES) do
            local o = byClass[class] or {}
            local p, r = o.Pos or {}, o.Rot or {}
            s[class] = {
                Pos = { x = num(p.x, 0.0), y = num(p.y, 0.0), z = num(p.z, 0.0) },
                Rot = { x = num(r.x, 0.0), y = num(r.y, 0.0), z = num(r.z, 0.0) },
            }
        end
        out[slot] = s
    end
    return out
end

--- Body slots a hide rule can target, from the LIVE MBT.PropInfo so a custom type a server
--- added is covered without a second whitelist to keep in sync.
--- The strap ('sling' / 'sling:<id>') and the multi-weapon lanes ('<slot>#<n>') are dropped:
--- neither is a policy target. The strap is owned by TacticalSling.Types, and hiding a slot
--- already takes every lane sitting on it — offering them would be an option that does nothing.
---@return string[]
local function bodySlots()
    local out = {}
    for wtype in pairs(MBT.PropInfo or {}) do
        if type(wtype) == 'string' and wtype ~= 'sling'
            and not wtype:match('^sling:') and not wtype:match('#%d+$') then
            out[#out + 1] = wtype
        end
    end
    table.sort(out)
    return out
end

--- Hide rules as a complete, normalised map: { [job] = { [slot] = true } }, false/absent
--- slots dropped and rows that hide nothing left out entirely.
---@param src table?
---@return table<string, table<string, boolean>>
local function hiddenByJob(src)
    local out = {}
    for job, slots in pairs(src or {}) do
        if type(job) == 'string' and type(slots) == 'table' then
            local row, n = {}, 0
            for slot, on in pairs(slots) do
                if on == true and type(slot) == 'string' then
                    row[slot] = true
                    n = n + 1
                end
            end
            if n > 0 then out[job] = row end
        end
    end
    return out
end

-- Captured at load, BEFORE any saved row is applied, so "reset" means default.lua and not
-- "whatever was in the database when we started".
local CLASS_OFFSET_DEFAULTS = json.decode(json.encode(MBT.WeaponClassOffsets or {}))

--- Write validated class offsets onto the live table. Only slots default.lua already
--- declares are touched: a saved row is data, and data does not get to invent body slots.
--- The client has its own copy of this in modules/config/client.lua — same rule as every
--- other block here, each VM applies the snapshot to its own MBT.
local function applyClassOffsets(src)
    if type(src) ~= 'table' or type(MBT.WeaponClassOffsets) ~= 'table' then return end
    for slot, byClass in pairs(MBT.WeaponClassOffsets) do
        local s = src[slot]
        if type(s) == 'table' then
            for _, class in ipairs(OFFSET_CLASSES) do
                local o = s[class]
                if type(o) == 'table' and type(o.Pos) == 'table' and type(o.Rot) == 'table' then
                    byClass[class] = {
                        Pos = { x = o.Pos.x + 0.0, y = o.Pos.y + 0.0, z = o.Pos.z + 0.0 },
                        Rot = { x = o.Rot.x + 0.0, y = o.Rot.y + 0.0, z = o.Rot.z + 0.0 },
                    }
                end
            end
        end
    end
end

--- Same policy? json.encode can't answer it — two maps holding the same rules serialise in
--- whatever order pairs() hands them out, and a false "it changed" costs every player in the
--- world a delete-and-respawn of their props. Both sides must be normalised (hiddenByJob).
---@param a table<string, table<string, boolean>>
---@param b_ table<string, table<string, boolean>>
---@return boolean
local function sameHidden(a, b_)
    for job, slots in pairs(a) do
        local other = b_[job]
        if not other then return false end
        for slot in pairs(slots) do if not other[slot] then return false end end
    end
    for job, slots in pairs(b_) do
        local other = a[job]
        if not other then return false end
        for slot in pairs(slots) do if not other[slot] then return false end end
    end
    return true
end

-- ── Snapshot: full config the dashboard reads (incl. overview flags) ──
local function snapshot()
    local S, D = MBT.Sounds or {}, MBT.WeaponDrop or {}
    local DD = D.Despawn or {}   -- Logging.Webhook is a server-only secret set in config.lua; not in the snapshot
    local J, SH = MBT.Jamming or {}, MBT.SuppressorHeat or {}
    local SF, CH, WW = MBT.Safety or {}, MBT.ChargeWeapon or {}, MBT.WeaponWeight or {}
    local LR  = MBT.LowReady or {}
    local lrt = LR.Types or {}
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
    local AS = MBT.AmmoSharing or {}
    local vat = VTR.AllowedTypes or {}
    local war = WR.AllowedTypes or {}
    local TH, INS = MBT.Throw or {}, IN.Show or {}
    local thg = TH.Groups or {}
    local throwGroups = {}
    for name, hash in pairs(THROW_GROUPS) do
        throwGroups[name] = b(thg[hash] and thg[hash].Allowed)
    end
    -- Strap variant options for the NUI dropdown (id + label only; model names stay Lua-side).
    local slingVariants = {}
    for _, v in ipairs(TS.Variants or {}) do slingVariants[#slingVariants + 1] = { id = v.id, label = v.label or v.id } end
    return {
        -- General (editable). Debug is intentionally NOT exposed (dev flag → config.lua).
        EnableSling       = b(MBT.EnableSling),
        EnableFlashlight  = b(MBT.EnableFlashlight),
        HolsterConfirm    = b(MBT.HolsterConfirm),
        DropWeaponOnDeath = b(MBT.DropWeaponOnDeath),
        UIPosition        = MBT.UI.Position,
        UIStyle           = MBT.UIStyle or 'standard',
        Accent            = MBT.Accent or DEFAULT_ACCENT,
        Language          = MBT.Language,            -- read-only in the UI
        -- Which body slots stay off which job (see MBT.HiddenByJob in config.lua). BodySlots
        -- rides along read-only: the dashboard builds its slot chips from the types this
        -- server actually has, instead of a list frozen into the NUI bundle.
        HiddenByJob       = hiddenByJob(MBT.HiddenByJob),
        BodySlots         = bodySlots(),
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
        LowReady = {
            Enabled = b(LR.Enabled),
            Types   = { back = b(lrt.back), back2 = b(lrt.back2) },
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
            Charge  = { Enabled       = b(TH.Charge and TH.Charge.Enabled),
                        ChargeMs      = num(TH.Charge and TH.Charge.ChargeMs, 900),
                        MaxMultiplier = num(TH.Charge and TH.Charge.MaxMultiplier, 1.25),
                        ShowUI        = b(TH.Charge and TH.Charge.ShowUI) },
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
            Placement           = {
                Enabled      = b(WR.Placement and WR.Placement.Enabled),
                MaxPerPlayer = num(WR.Placement and WR.Placement.MaxPerPlayer, 2),
                AllowPickup  = b(WR.Placement and WR.Placement.AllowPickup),
                Access       = (WR.Placement and WR.Placement.Access) == 'owner' and 'owner' or 'everyone',
            },
        },
        MultiWeaponVisibility = {
            Enabled    = b(MBT.MultiWeaponVisibility and MBT.MultiWeaponVisibility.Enabled),
            MaxPerType = num(MBT.MultiWeaponVisibility and MBT.MultiWeaponVisibility.MaxPerType, 2),
        },
        WeaponClassOffsets = classOffsetSnapshot(),
        TacticalSling = {
            Enabled        = b(TS.Enabled),
            DefaultVariant = TS.DefaultVariant or 'normal',
            Variants       = slingVariants,
            JobVariants    = TS.JobVariants or {},
            Types          = { back = b(TS.Types and TS.Types.back), back2 = b(TS.Types and TS.Types.back2) },
        },
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
        },
        AmmoSharing = {
            Enabled     = b(AS.Enabled),
            ShareAmount = num(AS.ShareAmount, 30),
            MaxDistance = num(AS.MaxDistance, 2.5),
        },
    }
end

-- ── Validate the runtime-safe (editable) fields ──
local function validate(d)
    if type(d) ~= 'table' then return false end
    -- General
    if type(d.EnableSling) ~= 'boolean' then return false end
    if type(d.EnableFlashlight) ~= 'boolean' then return false end
    if type(d.HolsterConfirm) ~= 'boolean' then return false end
    if type(d.DropWeaponOnDeath) ~= 'boolean' then return false end
    if type(d.UIPosition) ~= 'string' or not VALID_POSITIONS[d.UIPosition] then return false end
    if d.UIStyle ~= 'standard' and d.UIStyle ~= 'cinematic' then return false end
    -- The accent is interpolated into CSS custom properties in the NUI, so the shape is
    -- the security boundary: exactly '#rrggbb', nothing else. Readability is NOT checked
    -- here — the dashboard warns on low contrast and still lets the owner save it.
    if type(d.Accent) ~= 'string' or not d.Accent:match('^#%x%x%x%x%x%x$') then return false end
    -- Hide rules. Optional on purpose: a payload from a UI that predates this block must not
    -- fail the whole save and take every other setting down with it. Keys are the server's own
    -- job names and its own slot names, so all we can check is shape and size.
    if d.HiddenByJob ~= nil then
        if type(d.HiddenByJob) ~= 'table' then return false end
        local rows = 0
        for job, slots in pairs(d.HiddenByJob) do
            rows = rows + 1
            if rows > 64 or type(job) ~= 'string' or #job > 48 or type(slots) ~= 'table' then return false end
            local n = 0
            for slot, on in pairs(slots) do
                n = n + 1
                if n > 64 or type(slot) ~= 'string' or #slot > 48 or type(on) ~= 'boolean' then return false end
            end
        end
    end
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
    -- Low Ready
    local lr = d.LowReady
    if type(lr) ~= 'table' or type(lr.Enabled) ~= 'boolean' then return false end
    if type(lr.Types) ~= 'table' then return false end
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
    if type(th.Charge) ~= 'table' or type(th.Charge.Enabled) ~= 'boolean' or type(th.Charge.ShowUI) ~= 'boolean' then return false end
    if type(th.Charge.ChargeMs) ~= 'number' or th.Charge.ChargeMs < 200 or th.Charge.ChargeMs > 3000 then return false end
    if type(th.Charge.MaxMultiplier) ~= 'number' or th.Charge.MaxMultiplier < 1.0 or th.Charge.MaxMultiplier > 3.0 then return false end
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
    local wrp = wr.Placement
    if type(wrp) ~= 'table' or type(wrp.Enabled) ~= 'boolean' or type(wrp.AllowPickup) ~= 'boolean' then return false end
    if type(wrp.MaxPerPlayer) ~= 'number' or wrp.MaxPerPlayer < 1 or wrp.MaxPerPlayer > 20 then return false end
    if wrp.Access ~= 'everyone' and wrp.Access ~= 'owner' then return false end
    -- Multi-Weapon Visibility. OPTIONAL on purpose: the dashboard has no control for it
    -- yet, and a payload from an older UI must not be rejected wholesale — that would take
    -- every other setting down with it.
    local mw = d.MultiWeaponVisibility
    if mw ~= nil then
        if type(mw) ~= 'table' or type(mw.Enabled) ~= 'boolean' then return false end
        -- Cap: props scale with MaxPerType x slots x players in scope, and 4 lanes on a
        -- 64-slot server already reaches the engine's per-frame limits elsewhere.
        if type(mw.MaxPerType) ~= 'number' or mw.MaxPerType < 1 or mw.MaxPerType > 4 then return false end
    end

    -- Class offsets. Optional for the same reason as the block above. The limits are what a
    -- SHIFT can plausibly be: past ~30cm you are not correcting for a weapon's length any
    -- more, you are moving it somewhere else, and that belongs in the position.
    local co = d.WeaponClassOffsets
    if co ~= nil then
        if type(co) ~= 'table' then return false end
        local slots = 0
        for slot, byClass in pairs(co) do
            slots = slots + 1
            if slots > 32 or type(slot) ~= 'string' or #slot > 32 or type(byClass) ~= 'table' then return false end
            for class, o in pairs(byClass) do
                if class ~= 'compact' and class ~= 'long' then return false end
                if type(o) ~= 'table' or type(o.Pos) ~= 'table' or type(o.Rot) ~= 'table' then return false end
                for _, axis in ipairs({ 'x', 'y', 'z' }) do
                    local p, r = o.Pos[axis], o.Rot[axis]
                    if type(p) ~= 'number' or p ~= p or p < -0.3 or p > 0.3 then return false end
                    if type(r) ~= 'number' or r ~= r or r < -180 or r > 180 then return false end
                end
            end
        end
    end

    -- Tactical Sling
    local ts = d.TacticalSling
    if type(ts) ~= 'table' or type(ts.Enabled) ~= 'boolean' then return false end
    if ts.DefaultVariant ~= nil and type(ts.DefaultVariant) ~= 'string' then return false end
    if ts.JobVariants ~= nil then
        if type(ts.JobVariants) ~= 'table' then return false end
        local n = 0
        for k, v in pairs(ts.JobVariants) do
            n = n + 1
            if n > 64 or type(k) ~= 'string' or #k > 48 or type(v) ~= 'string' or #v > 48 then return false end
        end
    end
    if ts.Types ~= nil then
        if type(ts.Types) ~= 'table' then return false end
        local n = 0
        for k, v in pairs(ts.Types) do
            n = n + 1
            if n > 32 or type(k) ~= 'string' or #k > 32 or type(v) ~= 'boolean' then return false end
        end
    end
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
    -- Ammo Sharing
    local as = d.AmmoSharing
    if type(as) ~= 'table' or type(as.Enabled) ~= 'boolean' then return false end
    if type(as.ShareAmount) ~= 'number' or as.ShareAmount < 1 or as.ShareAmount > 1000 then return false end
    if type(as.MaxDistance) ~= 'number' or as.MaxDistance < 1 or as.MaxDistance > 10 then return false end
    return true
end

-- ── Apply the editable fields to MBT.* (server side) ──
local function applyToMBT(d)
    MBT.EnableSling       = d.EnableSling
    MBT.EnableFlashlight  = d.EnableFlashlight
    MBT.HolsterConfirm    = d.HolsterConfirm
    MBT.DropWeaponOnDeath = d.DropWeaponOnDeath
    MBT.UI.Position       = d.UIPosition
    MBT.UIStyle           = d.UIStyle
    MBT.Accent            = d.Accent
    -- Guarded like validate(): absent means "this UI doesn't know about hide rules", not
    -- "the owner cleared them".
    if d.HiddenByJob ~= nil then MBT.HiddenByJob = hiddenByJob(d.HiddenByJob) end
    MBT.Sounds.Enabled     = d.Sounds.Enabled
    MBT.Sounds.MaxDistance = d.Sounds.MaxDistance
    MBT.Sounds.Volume      = d.Sounds.Volume
    MBT.WeaponDrop.WeaponModelProp     = d.WeaponDrop.WeaponModelProp
    MBT.WeaponDrop.OxTargetPickup      = d.WeaponDrop.OxTargetPickup
    MBT.WeaponDrop.Despawn.Enabled     = d.WeaponDrop.Despawn.Enabled
    MBT.WeaponDrop.Despawn.Seconds     = d.WeaponDrop.Despawn.Seconds
    MBT.WeaponDrop.Despawn.BlinkLastSec= d.WeaponDrop.Despawn.BlinkLastSec
    -- WeaponDrop.Logging is server-only (config.lua) — never touched from the dashboard
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
    MBT.LowReady.Enabled = d.LowReady.Enabled
    MBT.LowReady.Types   = { ['back'] = d.LowReady.Types.back and true or false, ['back2'] = d.LowReady.Types.back2 and true or false }
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
    if d.Throw.Charge then
        MBT.Throw.Charge = MBT.Throw.Charge or {}
        MBT.Throw.Charge.Enabled       = d.Throw.Charge.Enabled
        MBT.Throw.Charge.ChargeMs      = d.Throw.Charge.ChargeMs
        MBT.Throw.Charge.MaxMultiplier = d.Throw.Charge.MaxMultiplier
        MBT.Throw.Charge.ShowUI        = d.Throw.Charge.ShowUI
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
        MBT.WeaponRack.Placement = MBT.WeaponRack.Placement or {}
        MBT.WeaponRack.Placement.Enabled      = d.WeaponRack.Placement.Enabled
        MBT.WeaponRack.Placement.MaxPerPlayer = d.WeaponRack.Placement.MaxPerPlayer
        MBT.WeaponRack.Placement.AllowPickup  = d.WeaponRack.Placement.AllowPickup
        MBT.WeaponRack.Placement.Access       = d.WeaponRack.Placement.Access
    end
    if d.MultiWeaponVisibility and MBT.MultiWeaponVisibility then
        MBT.MultiWeaponVisibility.Enabled    = d.MultiWeaponVisibility.Enabled
        MBT.MultiWeaponVisibility.MaxPerType = math.floor(d.MultiWeaponVisibility.MaxPerType)
    end
    applyClassOffsets(d.WeaponClassOffsets)
    MBT.TacticalSling.Enabled = d.TacticalSling.Enabled
    if d.TacticalSling.DefaultVariant then MBT.TacticalSling.DefaultVariant = d.TacticalSling.DefaultVariant end
    if d.TacticalSling.JobVariants then
        local jv = {}
        for job, vid in pairs(d.TacticalSling.JobVariants) do
            if type(job) == 'string' and type(vid) == 'string' and vid ~= '' then jv[job] = vid end
        end
        MBT.TacticalSling.JobVariants = jv
    end
    if d.TacticalSling.Types then
        MBT.TacticalSling.Types = { ['back'] = d.TacticalSling.Types.back and true or false, ['back2'] = d.TacticalSling.Types.back2 and true or false }
    end
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
        HolsterConfirm = d.HolsterConfirm,
        DropWeaponOnDeath = d.DropWeaponOnDeath, UIPosition = d.UIPosition, UIStyle = d.UIStyle,
        Accent = d.Accent,
        -- BodySlots is deliberately absent: it's derived from MBT.PropInfo every time, and a
        -- stored copy would go stale the moment a server adds a type.
        HiddenByJob = d.HiddenByJob,
        Sounds = { Enabled = d.Sounds.Enabled, MaxDistance = d.Sounds.MaxDistance, Volume = d.Sounds.Volume },
        WeaponDrop = {
            WeaponModelProp = d.WeaponDrop.WeaponModelProp, OxTargetPickup = d.WeaponDrop.OxTargetPickup,
            Despawn = d.WeaponDrop.Despawn,
        },
        Jamming = d.Jamming,
        SuppressorHeat = d.SuppressorHeat,
        Safety = d.Safety,
        ConditionHUD = d.ConditionHUD,
        ChargeWeapon = d.ChargeWeapon,
        WeaponWeight = d.WeaponWeight,
        LowReady = d.LowReady,
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
        MultiWeaponVisibility = d.MultiWeaponVisibility,
        WeaponClassOffsets = d.WeaponClassOffsets,
        ShellCasings = d.ShellCasings,
        Handoff = d.Handoff,
        Serials = d.Serials,
        ConcealedCarry = d.ConcealedCarry,
        PatDown = d.PatDown,
        AmmoSharing = d.AmmoSharing,
    }
end

--- Nodes whose keys are the SERVER'S OWN strings — job names — rather than ours.
--- mergeKnown walks the TEMPLATE, so for these the saved keys get filtered against a
--- table that is normally empty and simply vanish: an owner sets a per-job sling variant
--- in the dashboard, it saves, and the next restart drops it without a word. Here the
--- saved map replaces the template wholesale. Safe, because validate() runs on the merged
--- result and already caps these maps by key count, type and string length.
--- Add a path here for every free-key map exposed in the dashboard.
local DYNAMIC_MAPS = {
    ['TacticalSling.JobVariants'] = true,
    ['HiddenByJob']               = true,   -- { [job] = { [slot] = true } } — job names again
}

--- Deep-merge SAVED values onto the live template: only template keys are read (type-checked), missing ones keep their config.lua default — so an older saved config auto-migrates to new defaults, never wiping state.
local function mergeKnown(template, saved, path)
    if type(saved) ~= 'table' then return template end
    local out = {}
    for k, tv in pairs(template) do
        local sv = saved[k]
        local kpath = path and (path .. '.' .. k) or k
        if DYNAMIC_MAPS[kpath] then
            out[k] = type(sv) == 'table' and sv or tv
        elseif type(tv) == 'table' then
            out[k] = mergeKnown(tv, sv, kpath)
        elseif sv ~= nil and type(sv) == type(tv) then
            out[k] = sv
        else
            out[k] = tv
        end
    end
    return out
end

-- ── Persistence: one self-managed oxmysql row (mbt_malisling_config / 'dashboard').
-- DB-canonical: oxmysql is guaranteed (ox/qb inventory depend on it) and a DB row
-- survives resource-folder replacement on update, unlike a JSON file. No migration /
-- fallback (pre-release). Auto-created on start; no .sql to import.
local DB_ROW = 'dashboard'
local function hasDb() return GetResourceState('oxmysql') == 'started' end

-- Apply a saved JSON config string over the live snapshot, validate, then apply.
local function applySaved(raw)
    local ok, data = pcall(json.decode, raw or '')
    if not ok or type(data) ~= 'table' then
        Utils.mbtWarn('config ~ saved row unreadable, keeping config.lua defaults')
        return
    end
    -- Merge over the live snapshot (defaults fill blocks the saved row predates), then
    -- validate the COMPLETE result.
    local merged = mergeKnown(snapshot(), data)
    if not validate(merged) then
        Utils.mbtWarn('config ~ saved row failed validation after merge, keeping defaults')
        return
    end
    applyToMBT(merged)
    Utils.mbtDebugger('config: loaded from database (mbt_malisling_config)')
end

local function loadRuntimeConfig()
    CreateThread(function()
        -- Load-order: oxmysql can start a beat after us. Wait up to ~10s, else fall
        -- back to config.lua defaults (no persistence).
        local tries = 0
        while not hasDb() and tries < 40 do Wait(250); tries = tries + 1 end
        if not hasDb() then
            Utils.mbtWarn('config ~ oxmysql not started; using config.lua defaults (config will NOT persist)')
            return
        end
        exports.oxmysql:execute([[
            CREATE TABLE IF NOT EXISTS mbt_malisling_config (
                id VARCHAR(64) NOT NULL,
                value LONGTEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {}, function()
            Utils.mbtDebugger('config ~ mbt_malisling_config table ready (oxmysql)')
            exports.oxmysql:execute('SELECT value FROM mbt_malisling_config WHERE id = ?', { DB_ROW }, function(rows)
                local row = rows and rows[1]
                if row and row.value then
                    applySaved(row.value)
                else
                    Utils.mbtDebugger('config: no saved row yet — using default.lua defaults')
                end
            end)
        end)
    end)
end

--- Send the dashboard to an authorized admin.
local function openFor(src)
    -- Non-critical integration warnings → chips in the dashboard overview. Providers
    -- are registered at runtime by the bridges. pcall so a faulty one can't block the
    -- dashboard.
    local warnings = {}
    for _, provider in ipairs(MBT.IntegrationWarnings or {}) do
        local ok, w = pcall(provider)
        if ok and w then warnings[#warnings + 1] = w end
    end

    TriggerClientEvent('mbt_malisling:openAdmin', src, {
        config   = snapshot(),
        version  = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'v2',
        update   = MBT.UpdateInfo,          -- {current, latest, url} when a newer release exists, else nil
        oxPatch  = oxPatchStatus or false,   -- 'ok' | reason | false → sidebar status
        warnings = warnings,
    })
end

-- Registered SERVER-side (like mbt_elevator) so FiveM auto-registers its ACE — a
-- wildcard admin principal then works with no extra server.cfg lines.
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

-- ox_inventory auto-patch outcome from the JS patcher. Server-local event (not a net
-- event) → clients cannot spoof it. Shown in the dashboard sidebar.
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
    local payload = persistable(data)
    if hasDb() then
        -- Single-row upsert. DB is canonical → no dual-write drift.
        exports.oxmysql:execute(
            'INSERT INTO mbt_malisling_config (id, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
            { DB_ROW, json.encode(payload) }
        )
    else
        Utils.mbtWarn('config ~ oxmysql not started; save applied live but NOT persisted')
    end
    TriggerClientEvent('mbt_malisling:applyConfig', -1, payload)   -- no secrets in payload (webhooks live in config.lua)
    -- Two settings here change what OBSERVERS decide to draw, and observers only re-decide
    -- when a fresh syncSling reaches them: multi-weapon lanes, and hide rules. Without this
    -- either one shows up on the next job change or relog and nowhere else. Unconditional
    -- rather than gated on which of the two moved — a dashboard save is a rare, deliberate
    -- act, and getting the gate subtly wrong costs a setting that silently does nothing.
    -- Defined in core/server.lua, absent if that bailed at startup.
    if MBT.RefreshAllSling then MBT.RefreshAllSling() end
    Utils.mbtDebugger('Admin config saved by player', src)
end)

-- ── Class offsets from the position editor ───────────────────────────────────
-- Saved from the 3D editor rather than the dashboard, because that is where you can SEE
-- the weapon you are shifting — but persisted here, through the config row, because an
-- offset is global: not per-job and not per-gender, since a weapon's length is the same
-- whoever carries it. Going through this file keeps ONE writer for the row; a second one
-- reading-modifying-writing the same JSON would lose whichever save landed first.
local lastOffsetSave = {}

RegisterNetEvent('mbt_malisling:classOffset:save', function(p)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if type(p) ~= 'table' or type(p.slot) ~= 'string' or type(p.offset) ~= 'table' then return end
    if p.class ~= 'compact' and p.class ~= 'long' then return end
    -- One write per second per admin: the panel saves on a click, so anything faster is
    -- not a person, and each save is a DB round-trip plus a broadcast.
    local now = GetGameTimer()
    if lastOffsetSave[src] and now - lastOffsetSave[src] < 1000 then return end
    lastOffsetSave[src] = now

    -- Patch the ONE offset onto the live snapshot and re-validate the whole thing, so this
    -- path cannot write a config the dashboard's own save would have rejected.
    local data = snapshot()
    local slot = data.WeaponClassOffsets and data.WeaponClassOffsets[p.slot]
    if not slot then return end            -- not a slot default.lua declares
    -- Rebuilt field by field rather than assigned: whatever else the payload carried does
    -- not belong in a row that gets read back and applied on every restart.
    local ip, ir = p.offset.Pos or {}, p.offset.Rot or {}
    slot[p.class] = {
        Pos = { x = num(ip.x, 0.0), y = num(ip.y, 0.0), z = num(ip.z, 0.0) },
        Rot = { x = num(ir.x, 0.0), y = num(ir.y, 0.0), z = num(ir.z, 0.0) },
    }

    if not validate(data) then
        Utils.mbtWarn('classOffset ~ invalid payload from player', src)
        return
    end
    applyToMBT(data)
    local payload = persistable(data)
    if hasDb() then
        exports.oxmysql:execute(
            'INSERT INTO mbt_malisling_config (id, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
            { DB_ROW, json.encode(payload) }
        )
    else
        Utils.mbtWarn('config ~ oxmysql not started; class offset applied live but NOT persisted')
    end
    TriggerClientEvent('mbt_malisling:applyConfig', -1, payload)
    Utils.mbtDebugger('class offset saved by player', src, p.slot, p.class)
end)

AddEventHandler('playerDropped', function() lastOffsetSave[source] = nil end)

--- Put every length-class shift back to default.lua and persist it. Called by the position
--- editor's "reset all", because a shift is placement: a reset that left them behind would
--- put the weapons back and still draw the long ones somewhere else.
---@param src number  the admin who asked; re-checked here, not trusted from the caller
function MBT.ResetClassOffsets(src)
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    local data = snapshot()
    -- Through the same shape builder: default.lua ships Pos only, and validate wants both.
    data.WeaponClassOffsets = classOffsetSnapshot(CLASS_OFFSET_DEFAULTS)
    if not validate(data) then
        Utils.mbtWarn('config ~ class offset defaults failed validation; not resetting')
        return
    end
    applyToMBT(data)
    local payload = persistable(data)
    if hasDb() then
        exports.oxmysql:execute(
            'INSERT INTO mbt_malisling_config (id, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
            { DB_ROW, json.encode(payload) }
        )
    end
    TriggerClientEvent('mbt_malisling:applyConfig', -1, payload)
    -- The admin who asked may have the dashboard open, and its draft is holding the OLD
    -- offsets: the draft round-trips the whole config, so the next ordinary Save would send
    -- them straight back and undo this reset — minutes later, from an unrelated click.
    -- applyConfig cannot do it: that updates MBT.* on the Lua side, not the open panel.
    TriggerClientEvent('mbt_malisling:patchDraft', src, { WeaponClassOffsets = data.WeaponClassOffsets })
    Utils.mbtDebugger('class offsets reset by player', src)
end

-- "Restore from config.lua" — DROP the saved rules rather than overwrite them with today's
-- file value: the row is rewritten WITHOUT the key, so mergeKnown falls back to the config.lua
-- seed on every later start and editing that file is once again the thing that decides.
-- The dashboard is re-sent afterwards because the admin's draft still holds the rules we just
-- dropped, and saving it would put them straight back.
RegisterNetEvent('mbt_malisling:hiddenByJob:restore', function()
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then
        Utils.mbtWarn('hiddenByJob:restore ~ ACE denied for', src)
        return
    end
    if MBT.NetThrottle and not MBT.NetThrottle(src, 'hiddenRestore', 2000) then return end

    local hiddenBefore = hiddenByJob(MBT.HiddenByJob)
    MBT.HiddenByJob = Utils.tableDeepCopy(HIDDEN_BY_JOB_SEED)

    local payload = persistable(snapshot())
    if hasDb() then
        local stored = {}
        for k, v in pairs(payload) do stored[k] = v end
        stored.HiddenByJob = nil   -- json.encode omits a nil field → nothing left to merge back
        exports.oxmysql:execute(
            'INSERT INTO mbt_malisling_config (id, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
            { DB_ROW, json.encode(stored) }
        )
    else
        Utils.mbtWarn('config ~ oxmysql not started; hide rules restored live but NOT persisted')
    end
    TriggerClientEvent('mbt_malisling:applyConfig', -1, payload)
    if MBT.RefreshAllSling and not sameHidden(hiddenBefore, MBT.HiddenByJob) then
        MBT.RefreshAllSling()
    end
    openFor(src)
    Utils.mbtDebugger('HiddenByJob restored from config.lua by player', src)
end)

-- Clients fetch the live config on (re)init so a restart or fresh join picks it up
-- without needing a save. Returns the editable snapshot applyConfig consumes.
lib.callback.register('mbt_malisling:getRuntimeConfig', function()
    return persistable(snapshot())
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadRuntimeConfig()
end)
