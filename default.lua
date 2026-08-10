-- ============================================================================
-- mbt_malisling -- DEFAULT feature values (loaded BEFORE config.lua)
--
-- Factory defaults for every feature. These are what the admin dashboard starts
-- from; tune gameplay LIVE from the dashboard (/mbt_malisling), persisted to oxmysql,
-- NOT by editing this file. Edit here only for baselines the dashboard can't
-- reach (weapon-type maps, world Locations, asset/model names, keybinds, anim
-- clips). To hard-override a default, re-declare it in config.lua (loaded after).
-- ============================================================================

MBT = MBT or {}

-- General (dashboard-editable)
MBT.DropWeaponOnDeath  = true
MBT.EnableSling        = true
MBT.EnableFlashlight   = true
-- Drawing a sidearm asks you to confirm before the weapon reaches your hand. Turn this
-- off and the draw animation still plays, it just doesn't wait for an answer.
-- Worth knowing if your host blocks resources from writing files: the ox_inventory patch
-- exists so this prompt can hook the equip flow, so with the prompt off a failed patch
-- costs you nothing. The patch is still applied when it can be — the switch is read at
-- the moment you draw, not at startup, which is what lets the dashboard flip it live.
MBT.HolsterConfirm     = true

-- UI
MBT.UI                 = {
    Position = "bottom-center" -- "bottom-center" | "top-center" | "bottom-right"
}
-- ── Sling / Holster ───────────────────────────────────────────────────────────
-- Named bone ids for the PropInfo blocks below (readable > magic numbers).
MBT.Bones              = {
    ["Back"]   = 24816,
}

MBT.HolsterControls    = {
    ["Confirm"] = { ["Label"] = "Confirm Holster", ["Input"] = "MOUSE_BUTTON", ["Key"] = "MOUSE_RIGHT" },  -- set in config.lua
    ["Cancel"]  = { ["Label"] = "Cancel Holster", ["Input"] = "keyboard", ["Key"] = "BACK" },  -- set in config.lua
}

-- UI style (dashboard-editable): 'standard' = the classic pills, 'cinematic' =
-- filmic overlays anchored near the weapon. Applies to the weapon-moment overlays.
MBT.UIStyle            = 'standard'

-- Sling prop positions and holster animations per weapon type.
-- Each key maps to a weapon type defined in data/weapons.lua.
MBT.PropInfo           = {
    ["side"] = {
        ["Bone"]        = MBT.Bones["Back"],
        ["isPed"]       = false,
        ["RotOrder"]    = 2,
        ["FixedRot"]    = true,
        ["Pos"]         = {
            ["male"]   = { ["x"] = -0.15, ["y"] = 0.0, ["z"] = -0.23 },
            ["female"] = { ["x"] = -0.15, ["y"] = 0.0, ["z"] = -0.23 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = 90.0, ["y"] = 20.0, ["z"] = 180.0 },
            ["female"] = { ["x"] = 90.0, ["y"] = 20.0, ["z"] = 180.0 },
        },
        ["HolsterAnim"] = {
            ["dict"]     = "reaction@intimidation@cop@unarmed",
            ["animIn"]   = "intro",
            ["animOut"]  = "outro",
            ["sleep"]    = 400,
            ["sleepOut"] = 450,
        },
    },
    ["back"] = {
        ["Bone"]        = MBT.Bones["Back"],
        ["isPed"]       = false,
        ["RotOrder"]    = 2,
        ["FixedRot"]    = true,
        -- male tuned in-world; female is still the original seed, not tuned.
        ["Pos"]         = {
            ["male"]   = { ["x"] = 0.2, ["y"] = -0.21, ["z"] = -0.055 },
            ["female"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = 0.0, ["y"] = 145.0, ["z"] = 0.0 },
            ["female"] = { ["x"] = 0.0, ["y"] = 155.0, ["z"] = 0.0 },
        },
        -- sleep/sleepOut are how long ox blocks before the weapon is in hand: they land
        -- in Items[name].anim via the ox patch, and ox reads them as `anim[3]`. They are
        -- the FEEL of drawing a long gun, so tune them against the clip, not the clock —
        -- go too low and the rifle appears in your hands while the arm is still reaching
        -- behind your back. 2000 was the original; 1200 matches melee3 and reads snappier.
        ["HolsterAnim"] = {
            ["dict"]     = "reaction@intimidation@1h",
            ["animIn"]   = "intro",
            ["animOut"]  = "outro",
            ["sleep"]    = 1200,
            ["sleepOut"] = 1600,
        },
    },
    ["back2"] = {
        ["Bone"]        = MBT.Bones["Back"],
        ["isPed"]       = false,
        ["RotOrder"]    = 2,
        ["FixedRot"]    = true,
        ["Pos"]         = {
            ["male"]   = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
            ["female"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
            ["female"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
        },
        ["HolsterAnim"] = {
            ["dict"]     = "reaction@intimidation@1h",
            ["animIn"]   = "intro",
            ["animOut"]  = "outro",
            ["sleep"]    = 2000,
            ["sleepOut"] = 1600,
        },
    },
    ["melee"] = {
        ["Bone"]        = MBT.Bones["Back"],
        ["isPed"]       = false,
        ["RotOrder"]    = 2,
        ["FixedRot"]    = true,
        ["Pos"]         = {
            ["male"]   = { ["x"] = -0.4, ["y"] = -0.1, ["z"] = 0.22 },
            ["female"] = { ["x"] = -0.4, ["y"] = -0.1, ["z"] = 0.22 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = 90.0, ["y"] = -10.0, ["z"] = 120.0 },
            ["female"] = { ["x"] = 90.0, ["y"] = -10.0, ["z"] = 120.0 },
        },
        ["HolsterAnim"] = {
            ["dict"]     = "combat@combat_reactions@pistol_1h_gang",
            ["animIn"]   = "0",
            ["animOut"]  = "0",
            ["sleep"]    = 500,
            ["sleepOut"] = 500,
        },
    },
    ["melee2"] = {
        ["Bone"]        = MBT.Bones["Back"],
        ["isPed"]       = false,
        ["RotOrder"]    = 2,
        ["FixedRot"]    = true,
        ["Pos"]         = {
            ["male"]   = { ["x"] = -0.05, ["y"] = 0.1, ["z"] = 0.22 },
            ["female"] = { ["x"] = -0.05, ["y"] = 0.1, ["z"] = 0.22 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = -90.0, ["y"] = -10.0, ["z"] = 120.0 },
            ["female"] = { ["x"] = -90.0, ["y"] = -10.0, ["z"] = 120.0 },
        },
        ["HolsterAnim"] = {
            ["dict"]     = "combat@combat_reactions@pistol_1h_hillbilly",
            ["animIn"]   = "0",
            ["animOut"]  = "0",
            ["sleep"]    = 500,
            ["sleepOut"] = 500,
        },
    },
    ["melee3"] = {
        ["Bone"]        = MBT.Bones["Back"],
        ["isPed"]       = false,
        ["RotOrder"]    = 2,
        ["FixedRot"]    = true,
        ["Pos"]         = {
            ["male"]   = { ["x"] = 0.0, ["y"] = -0.13, ["z"] = 0.1 },
            ["female"] = { ["x"] = 0.0, ["y"] = -0.13, ["z"] = 0.1 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = 0.0, ["y"] = 90.0, ["z"] = 0.0 },
            ["female"] = { ["x"] = 0.0, ["y"] = 90.0, ["z"] = 0.0 },
        },
        ["HolsterAnim"] = {
            ["dict"]     = "reaction@intimidation@1h",
            ["animIn"]   = "intro",
            ["animOut"]  = "outro",
            ["sleep"]    = 1200,
            ["sleepOut"] = 1200,
        },
    },
    -- Bulky canister tools strapped vertically across the upper back (fire
    -- extinguisher etc.) — values tuned in-game via the Positions editor (/mbt_malisling).
    ["extinguisher"] = {
        ["Bone"]        = MBT.Bones["Back"],
        ["isPed"]       = false,
        ["RotOrder"]    = 2,
        ["FixedRot"]    = true,
        ["Pos"]         = {
            ["male"]   = { ["x"] = 0.432, ["y"] = -0.228, ["z"] = 0.032 },
            ["female"] = { ["x"] = 0.432, ["y"] = -0.228, ["z"] = 0.032 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = 2.0, ["y"] = 92.0, ["z"] = 0.0 },
            ["female"] = { ["x"] = 2.0, ["y"] = 92.0, ["z"] = 0.0 },
        },
        ["HolsterAnim"] = {
            ["dict"]     = "reaction@intimidation@1h",
            ["animIn"]   = "intro",
            ["animOut"]  = "outro",
            ["sleep"]    = 1200,
            ["sleepOut"] = 1200,
        },
    },
}

-- Hide sling props per job — FILL IT IN config.lua, next to the keybinds. Job names are
-- your server's own strings and this can't be tuned from the dashboard, so it belongs
-- with the things you decide at install. Declared here only so the table always exists.
MBT.HiddenByJob = {}

-- Job-specific prop overrides. Uncomment and fill to override positions per job.
MBT.CustomPropPosition = {
    --[[ Example:
    ["police"] = {
        ["side"] = {
            ["Bone"] = MBT.Bones["Back"], ["isPed"] = false, ["RotOrder"] = 2, ["FixedRot"] = true,
            ["Pos"] = {
                ["male"]   = { ["x"] = -0.15, ["y"] = 0.0, ["z"] = -0.23 },
                ["female"] = { ["x"] = -0.15, ["y"] = 0.0, ["z"] = -0.23 },
            },
            ["Rot"] = {
                ["male"]   = { ["x"] = 90.0, ["y"] = 20.0, ["z"] = 180.0 },
                ["female"] = { ["x"] = 90.0, ["y"] = 20.0, ["z"] = 180.0 },
            },
        },
    },
    ]]
}

-- ── Holster / Unholster Sounds ────────────────────────────────────────────────
-- Audio files in web/dist/sounds/ (.ogg format).
-- default: used when no per-type override is defined for that type.
-- Per-type override: uncomment and add the matching .ogg file.
-- MaxDistance: radius in metres within which nearby players hear the sound.
-- Volume: 0.0 - 1.0
MBT.Sounds             = {
    Enabled     = true,
    MaxDistance = 8.0,
    Volume      = 0.3,
    Holster = {
        default  = 'holster',
        ["side"]  = 'holster_pistol',
        ["back"]  = 'holster_rifle',
        ["back2"] = 'holster_rifle',
        ["melee2"] = 'holster_blade',   -- knife / machete / dagger / switchblade slot
        -- ["melee"]  = 'holster_blade',
        -- ["melee3"] = 'holster_melee',
    },
    Unholster = {
        default  = 'unholster',
        ["side"]  = 'unholster_pistol',
        ["back"]  = 'unholster_rifle',
        ["back2"] = 'unholster_rifle',
        ["melee2"] = 'unholster_blade', -- knife / machete / dagger / switchblade slot
        -- ["melee"]  = 'unholster_blade',
        -- ["melee3"] = 'unholster_melee',
    },
}

-- ── Weapon Jamming ────────────────────────────────────────────────────────────
MBT.Jamming            = {
    ["Enabled"]   = true,
    ["Cooldown"]  = 5,
    ["Animation"] = {
        ["Dict"] = "anim@weapons@first_person@aim_rng@generic@pistol@singleshot@str",
        ["Anim"] = "reload_aim",
    },
    -- Jam chance (%) per durability threshold. Key = durability %, Value = chance %
    ["Chance"]    = {
        [50] = 10,
        [40] = 15,
        [30] = 20,
        [20] = 25,
        [10] = 30,
    },
    -- Unjam mechanic: press the key N times to clear the jam
    ["Unjam"]     = {
        ["Control"] = 45,  -- FiveM control ID (45 = R / INPUT_RELOAD)
        ["Display"] = "R", -- label shown in the UI
        ["Presses"] = 5,   -- number of presses required
    },
}

-- ── Weapon Throw ──────────────────────────────────────────────────────────────
MBT.Throw              = {
    ["Enabled"]   = true,
    ["Command"]   = "throwWeapon",
    ["Key"]       = '',  -- set in config.lua
    ["Animation"] = {
        ["Dict"] = "melee@unarmed@streamed_variations",
        ["Anim"] = "plyr_takedown_front_slap",
    },
    -- Per weapon group: Allowed = can be thrown, Multipliers = force vector
    ["Groups"]    = {
        [`GROUP_MELEE`]   = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 40.0, ["Y"] = 40.0, ["Z"] = 15.0 } },
        [`GROUP_PISTOL`]  = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 15.0 } },
        [`GROUP_RIFLE`]   = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 10.0, ["Y"] = 10.0, ["Z"] = 5.0 } },
        [`GROUP_MG`]      = { ["Allowed"] = false, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_SMG`]     = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_SHOTGUN`] = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_STUNGUN`] = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_SNIPER`]  = { ["Allowed"] = false, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_HEAVY`]   = { ["Allowed"] = false, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
    },
    -- EXPERIMENTAL, default OFF. Charge-power throw: HOLD the throw key to charge power, RELEASE to
    -- throw forward (where the player faces). A tap (< TapThresholdMs) is the exact legacy throw at
    -- 1.0×; holding ramps the per-group impulse 1.0× → MaxMultiplier over ChargeMs. No raycast, no
    -- aim jitter. With Enabled=false the key throws immediately on press (the original behaviour).
    ["Charge"] = {
        Enabled        = false,
        ChargeMs       = 900,      -- time held (after the tap threshold) to reach full power
        MinMultiplier  = 1.0,      -- a hold is never weaker than a tap; tap is always exactly 1.0
        MaxMultiplier  = 1.25,     -- impulse at full charge (× the per-group Multipliers above)
        TapThresholdMs = 150,      -- release under this = a tap = the legacy 1.0× throw
        ShowUI         = true,     -- show the radial charge meter around the reticle while charging
    },
}

-- ── Suppressor Heat Glow ──────────────────────────────────────────────────────
-- The suppressor of the held weapon heats up as rounds are fired and visibly
-- glows orange -> red, cooling back down over a few seconds. Purely visual.
-- Heat accumulates per shot (detected via clip-ammo decrement).
MBT.SuppressorHeat     = {
    Enabled        = true,
    MaxHeat        = 100,
    HeatPerShot    = 5,     -- heat gained per round fired (~7 shots to glow, ~15 to red)
    MaxShotsPerTick = 4,    -- max clip-drop per tick that counts as gunfire. A real
                            -- shot drops the clip by ~1/tick; a holster/reload/unequip
                            -- drops it by a whole magazine at once — ignore those so
                            -- holstering a loaded weapon doesn't spuriously heat it.
    DecayRate      = 16,    -- heat lost per second while cooling (~6s to fully cool)
    DecayDelayMs   = 600,   -- delay after the last shot before cooling starts
    WarmThreshold  = 35,    -- heat at which the glow appears        (tier 1 — orange)
    HotThreshold   = 75,    -- heat at which the glow turns deep red (tier 2 — red, throbbing)
    -- Visual mode:
    --   'glow'     → DrawGlowSphere at the muzzle: a glow that does NOT illuminate
    --                the environment (no reflection on nearby walls). Default.
    --   'light'    → DrawLightWithRange: a real light, brighter but spills onto walls.
    --   'particle' → looped ptfx (Particle below) — use a ptfx tester to find a fx.
    Mode           = 'glow',
    GlowSphere     = {
        Radius    = 0.06,   -- small = tight glow on the suppressor
        Intensity = 8.0,
    },
    Light          = {
        -- Range = how far the light reaches (lower = less spill onto nearby walls).
        -- Intensity = brightness at the source (higher = more visible on the gun).
        Range     = 0.4,
        Intensity = 10.0,
    },
    Particle       = {
        Dict  = 'scr_ornate_heist',
        Name  = 'scr_heist_ornate_thermal_burn',
        Scale = 0.1,
    },
}

-- ── Weapon Drop ───────────────────────────────────────────────────────────────
-- Controls how a dropped weapon looks and is picked up, on the ox_inventory
-- path (native drag-drop, death drop, throw). The native walk-in pickup is
-- always available — it is the ox drop itself. The qb-inventory fallback path
-- ignores these toggles (it always renders the weapon model + ox_target).
MBT.WeaponDrop         = {
    -- Render the dropped weapon's real model instead of ox_inventory's default
    -- drop prop (the bag). When false, ox's normal drop visual is kept.
    WeaponModelProp = true,
    -- Add an ox_target option to pick the weapon up, on top of walk-in.
    OxTargetPickup  = true,
    -- Despawn timer for the rendered weapon prop. After Seconds the malisling
    -- weapon prop + its ox_target zone are removed; in the last BlinkLastSec the
    -- prop blinks as a warning. ox path: only OUR rendered prop is removed — the
    -- underlying ox drop follows ox's own cleanup. qb path: the whole drop is ours.
    Despawn = {
        Enabled     = true,
        Seconds     = 300,   -- 5 min on the ground before it disappears
        BlinkLastSec = 10,   -- blink during the final N seconds (0 = no blink)
    },
    -- Logging: Discord webhook for every weapon drop/throw/death-drop — who, weapon,
    -- serial, coords. Server-side admin audit / anti-abuse. The Webhook URL is a
    -- server-only secret → set it in config.lua (NOT here, NOT the dashboard).
    -- No webhook = no logging.
    Logging = {
        Enabled  = true,
        Webhook  = '',       -- filled server-side in config.lua (IsDuplicityVersion guard)
        BotName  = 'MBT Malisling',
    },
}

-- ── Vehicle Smart Hiding ──────────────────────────────────────────────────────
-- The slung weapon prop is hidden inside ENCLOSED vehicles (the barrel would clip
-- through the roof). On roofless vehicles (bikes, quads, buggies, convertibles
-- with the top down) the weapon stays visible — it looks better and nothing
-- clips. When Enabled = false the legacy behaviour is kept (hide in any vehicle).
MBT.VehicleHiding      = {
    -- NOTE: this flag is smart-vs-legacy, NOT on/off. The slung weapon is ALWAYS
    -- hidden inside enclosed vehicles (the barrel clipping through the roof is a
    -- bug, not a feature). Enabled = true → "smart": stays visible on roofless
    -- vehicles (bikes/quads/convertibles). Enabled = false → legacy: hide in ANY
    -- vehicle, including bikes. There is intentionally no "never hide" option.
    Enabled            = true,
    -- Vehicle classes that ALWAYS keep the weapon visible (checked first). Bikes
    -- need this because DoesVehicleHaveRoof is unreliable on two-wheelers — it can
    -- report a roof on a motorcycle, which would wrongly hide the weapon.
    -- See GetVehicleClass: 8 = Motorcycles, 13 = Cycles.
    KeepVisibleClasses = { [8] = true, [13] = true },
    -- Then, keep visible on any other roofless vehicle (DoesVehicleHaveRoof):
    -- quads, buggies, convertibles with the top down. Convertibles count as
    -- "having a roof" even with the top down, so those stay hidden.
    UseRoofCheck       = true,
}

-- ── Vehicle Trunk Weapon Rack ───────────────────────────────────────────────────
-- Stow a long gun in a vehicle's trunk (boot opens, anim, weapon prop racked in
-- the trunk, synced to nearby players) and retrieve it later. Persisted in a
-- dedicated oxmysql table (mbt_malisling_trunk) keyed by plate, so racked weapons
-- survive restarts/despawn. NOTE: this is the ONE documented exception to the
-- "no database" rule — oxmysql is soft/feature-gated (off if oxmysql isn't started).
MBT.VehicleTrunkRack   = {
    Enabled             = true,
    -- Allowed weapon 'type' values from data/weapons.lua. Long guns by default
    -- (back = rifles/shotguns/smg/sniper/mg, back2 = launchers/heavy).
    AllowedTypes        = { ['back'] = true, ['back2'] = true },
    Capacity            = 2,        -- max racked weapons per vehicle (per plate)
    InteractionDistance = 2.5,      -- reach at the rear of the vehicle
    EquipOnRetrieve     = false,    -- true = take the weapon straight into hand on retrieve (ox + qb)
    -- Animations (config-driven so server owners can swap to custom clips).
    -- Player anims (config-driven, swap freely). Place = bend & put the weapon in;
    -- Take = bend & lift it out; Close = the ox 'return_case' hands-closing gesture
    -- (played positioned, like ox_inventory's closeTrunk).
    Animation = {
        PlaceDict       = 'pickup_object',
        PlaceAnim       = 'putdown_low',
        PlaceMs         = 1000,
        TakeDict        = 'pickup_object',
        TakeAnim        = 'pickup_low',
        TakeMs          = 1000,
        CloseDict       = 'anim@heists@fleeca_bank@scope_out@return_case',
        CloseAnim       = 'trevor_action',
        CloseMs         = 900,
        BootOpenDelayMs = 250,
    },
    -- Prop attach offset. The 'boot' bone already sits at each vehicle's trunk, so
    -- the offset stays SMALL (it auto-scales per vehicle). Optional per-class
    -- overrides (GetVehicleClass index) fine-tune specific classes; vehicles with
    -- no 'boot' bone fall back to a model-dimensions rear position.
    PropOffset = {
        -- Resolution order: ByModel (exact) > ByClass > Default. Tune with /mbt_trunktune
        -- (ENTER saves the model). Offsets are in 'boot'-bone space (visible at the trunk).
        Default = { Pos = { x = 0.0, y = -0.10, z = -0.30 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } },
        -- Per-MODEL (precise). Key = lowercase model name. Paste tuner output here.
        ByModel = {
            -- ['sultan'] = { Pos = { x = 0.0, y = -0.10, z = -0.30 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } },
        },
        -- Per-CLASS (rough fallback). GetVehicleClass: 12 = Vans, 2 = SUVs, 20 = Commercial…
        ByClass = {
            -- [12] = { Pos = { x = 0.0, y = -0.20, z = 0.05 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } }, -- Vans
        },
    },
}

-- ── Weapon Rack / Gun Locker ────────────────────────────────────────────────────
-- Place a weapon onto a fixed world rack and retrieve it later. Like the Trunk Rack
-- but anchored to a config-defined world prop instead of a vehicle: racks are STATIC
-- (defined in Locations), so they always work with no DB. The weapon never lives in a
-- stash — its {name,count,metadata} is held server-side and re-minted into the
-- inventory on retrieve via the ox/qb Inventory bridge, exactly like the Trunk Rack.
--
-- Stored weapons are persisted in a self-managed oxmysql table (mbt_malisling_racks),
-- keyed by rack id, so they survive restarts. oxmysql is SOFT/feature-gated: without
-- it the racks still work but their contents reset on restart (in-memory only) — the
-- rest of the script stays DB-free. Weapon props are rendered LOCALLY by every client
-- from replicated GlobalState (never networked objects → no weapon-object sync jitter).
MBT.WeaponRack         = {
    Enabled             = true,
    Capacity            = 4,        -- max weapons per rack
    InteractionDistance = 2.0,
    EquipOnRetrieve     = false,    -- take the weapon straight into hand on retrieve (ox + qb)
    -- Allowed weapon 'type' values from data/weapons.lua (side = pistols, back =
    -- rifles/shotguns/smg/sniper, back2 = heavy/launcher, melee = melee).
    AllowedTypes        = { ['back'] = true, ['back2'] = true, ['side'] = true },
    -- Default rack prop. Per-location may override via Locations[].prop. The Offsets
    -- below are tuned to THIS prop — swapping the prop means re-tuning. A live in-world
    -- offset editor (per prop, per type) lands in v1.1; until then tune here.
    -- NOTE: verify the prop exists on your build; replace with your rack/locker model.
    DefaultProp         = `xm_prop_xm_gunlocker_01a`,
    -- Per-type placement on the rack prop, in the rack's LOCAL space (rack forward = +y,
    -- up = +z). Each successive slot is shifted by SlotSpacing along SlotAxis so weapons
    -- don't overlap. Rot is a local Euler applied on top of the rack's heading.
    Offsets             = {
        ['back']  = { Pos = { x = -0.400, y = 0.025, z = 0.905 }, Rot = { x = 0.0, y = 93.0, z = 88.0 } },
        ['back2'] = { Pos = { x = -0.400, y = 0.025, z = 0.905 }, Rot = { x = 0.0, y = 93.0, z = 88.0 } },
        ['side']  = { Pos = { x = -0.235, y = 0.075, z = 1.070 }, Rot = { x = 0.0, y = 78.0, z = 90.0 } },
    },
    SlotAxis            = 'x',       -- spread slots along this LOCAL axis of the rack
    SlotSpacing         = 0.22,      -- metres between adjacent slots
    -- Premium interaction feel, works out of the box — no tuning needed:
    --   • FaceRack: the ped turns to face the rack before the gesture.
    --   • Place/Take: an anim SEQUENCE (list of steps, played in order). The default
    --     is a chest-height handling gesture that reads as "hanging / lifting a gun
    --     off a rack". Add/replace steps to compose your own sequence.
    --   • Sound: plays the holster (place) / unholster (take) weapon sound, synced
    --     to nearby players via the existing sounds module.
    Animation           = {
        FaceRack = true,
        Sound    = true,
        Place    = {
            { Dict = 'mp_common', Anim = 'givetake1_a', Ms = 850 },
        },
        Take     = {
            { Dict = 'mp_common', Anim = 'givetake2_a', Ms = 850 },
        },
    },
    -- Optional map blip per rack location.
    Blip                = { Enabled = false, Sprite = 110, Color = 1, Scale = 0.8, Label = 'Armory' },
    -- Armory audit log → Discord webhook: who stored/took which weapon (serial included)
    -- at which rack, with their job. Webhook URL is a server-only secret → set it in
    -- config.lua (NOT here, NOT the dashboard). Empty URL = logging off.
    Logging             = {
        Enabled = true,
        Webhook = '',       -- filled server-side in config.lua
        BotName = 'MBT Armory',
    },
    -- ── Player placement (inventory item) ──────────────────────────────────────────
    -- Use the rack ITEM → the ped physically carries the locker (box-carry anim, you
    -- walk around with it), rotate it with ←/→, confirm with E → the install gesture
    -- plays and the rack is installed + persisted (oxmysql). The owner can
    -- pick an EMPTY rack back up and get the item returned. Needs oxmysql; without it
    -- item placement is disabled (config/admin racks keep working).
    --
    -- ox_inventory item definition (add to ox_inventory/data/items.lua — the export
    -- name must match the item name):
    --   ['gunrack'] = {
    --       label = 'Gun Rack', weight = 8000, stack = false,
    --       server = { export = 'mbt_malisling.gunrack' },
    --   },
    -- qb-core (shared/items.lua): ['gunrack'] = { name = 'gunrack', label = 'Gun Rack',
    --   weight = 8000, type = 'item', image = 'gunrack.png', unique = true, useable = true,
    --   shouldClose = true, description = 'Wall-mountable weapon rack' },
    Placement           = {
        Enabled         = true,
        Item            = 'gunrack',
        MaxPerPlayer    = 2,            -- max item-placed racks per player (identifier)
        AllowPickup     = true,         -- owner can pick an EMPTY rack back up (item returned)
        Access          = 'everyone',   -- who can use item-placed racks: 'everyone' | 'owner'
        Label           = 'Gun Rack',
        Prop            = nil,          -- nil = DefaultProp
        MinSpacing      = 1.5,          -- min distance from any other rack (m)
        -- Placement gestures — raw anim clips (more controlled than ambient scenarios: no tool
        -- props, no odd posture, mount/pickup split cleanly). Tune Dict/Anim/Ms/Flag live to taste.
        --   Flag: 49 = upper-body loop (fits the give/take handling gestures); 2 = full-body
        --   hold-last-frame (fits the kneel-and-place install). Swap clips freely.
        CarryAnim       = { Dict = 'anim@heists@box_carry@', Anim = 'idle', Flag = 50 },
        -- Mount: plant / fix the rack on the wall (full-body kneel-and-place).
        InstallAnim     = { Dict = 'anim@heists@ornate_bank@thermal_charge', Anim = 'thermal_charge', Ms = 3500, Flag = 2 },
        -- Pickup: a quick lift-off gesture (same handling dict as stow / retrieve).
        PickupAnim      = { Dict = 'mp_common', Anim = 'givetake1_a', Ms = 1200, Flag = 49 },
    },
    -- ── Conversion seam — RESERVED, not wired yet. Leave false. ───────────────────
    -- Intent: with a companion combat resource installed, retrieving a weapon class
    -- would require the matching certification (the companion decides). This build
    -- never blocks and shows nothing about it.
    -- Not just inert for lack of a companion: the check in weapon_rack/server.lua reads
    -- a client-side table from the server, so it cannot fire at all. Wiring it needs a
    -- server-side bridge — see the vault contract before switching this on.
    RequireCert         = false,
    -- Static rack locations (always work, no DB). v1.1 adds in-world item placement.
    -- id  = stable unique key (used as the persistence/sync key — keep it unique & stable).
    -- job = nil/false → anyone; a job string → only that job may use the rack.
    Locations           = {
        -- { id = 'mrpd_armory', coords = vec4(452.6, -980.0, 30.7, 90.0),
        --   prop = `xm_prop_xm_gunlocker_01a`, job = 'police', label = 'MRPD Armory' },
    },
}

-- ── Weapon Inspect ────────────────────────────────────────────────────────────
-- Hold the inspect key to examine the held weapon: plays an inspection animation
-- and shows an overlay with serial, condition, custom name and ammo. The animation
-- is visible to nearby players; the overlay is local-only. Purely visual / RP.
MBT.Inspect            = {
    Enabled     = true,
    Key         = '',  -- set in config.lua
    MaxDistance = 20.0,   -- nearby players that see the inspect animation
    -- Safety net for a hold that never gets released. Inspect starts on key down and
    -- ends on key UP, and if another resource takes NUI focus the moment you press —
    -- which is what happens when this key is also your inventory key — the release
    -- never reaches the game and the overlay stays up until you press again. We can't
    -- intercept another resource's key-up, so instead it gives up after this long.
    -- Nobody looks at a weapon for fifteen seconds, so it costs honest use nothing.
    MaxHoldSeconds = 15,
    -- Inspection animation. This is the base-game weapon "fidget" idle (the ped
    -- manipulates / looks over the held weapon) — the same clip the popular free
    -- weapon-inspect scripts use; it plays fine in third person despite the
    -- "first_person" dict name. Swap Dict/Anim for a custom streamed .ycd for a
    -- fancier inspect. Flag 48 = upper-body + secondary loop, so the player can
    -- still move/look while inspecting.
    Animation   = {
        Dict = 'weapons@first_person@aim_idle@p_m_zero@pistol@shared@fidgets@c',
        Anim = 'fidget_med_loop',
        Flag = 48,
    },
    -- Which fields the overlay shows.
    Show        = { Serial = true, Condition = true, Name = true, Ammo = true },
    -- Ammo display: 'exact' = round count (e.g. 18); 'vague' = a "look at the mag"
    -- estimate (Full / Half / Low / Empty) for no-HUD / hardcore servers.
    AmmoMode    = 'exact',
    -- durability (0-100) -> condition label (locale key). First tier whose Min the
    -- durability meets, scanned high → low.
    ConditionTiers = {
        { Min = 85, Key = 'cond_pristine' },
        { Min = 60, Key = 'cond_good' },
        { Min = 35, Key = 'cond_worn' },
        { Min = 10, Key = 'cond_poor' },
        { Min = 0,  Key = 'cond_damaged' },
    },
}

-- ── Concealed Carry ───────────────────────────────────────────────────────────
-- Carry small weapons CONCEALED: the holster prop is hidden from everyone — IF
-- your clothes can cover it. Toggle with a key; the server validates everything
-- (the client only requests). Clothing decides the concealment QUALITY:
--   none (bare torso → refused) · poor (light top → frequent, obvious waistband
--   tells) · good (jacket → rare, subtle tells). Quality only affects tells and
--   the future pat-down flavor — never combat stats (free tier = visual/RP).
-- A weapon IN HAND is always visible by nature (concealment covers the holstered
-- prop only). Changing clothes re-checks and force-reveals with a notification.
MBT.ConcealedCarry     = {
    Enabled          = true,
    Key              = '',          -- toggle key (concealable weapon must be holstered) · set in config.lua
    -- NOTE: FiveM caches keybinds per player — if you change this after first
    -- join, rebind it in GTA Settings → Key Bindings → FiveM.
    ConcealableTypes = { ['side'] = true },
    ToggleCooldownMs = 1200,         -- anti flicker/spam (server-enforced)
    -- Gesture played when concealing/revealing — the same waistband draw/stow clip
    -- the pistol holster uses, full length so it completes. Config-driven (swap
    -- freely; Dict=false disables).
    ActionAnim       = { Dict = 'reaction@intimidation@1h', Anim = 'intro', Ms = 1200 },
    -- The waistband-adjust TELL: random cadence, more likely after sprint/jump,
    -- naturally visible only to nearby players (the anim is networked).
    Tell             = {
        Enabled       = true,
        -- Seconds between tell ROLLS; chance per roll by quality.
        RollSeconds   = 25,
        ChanceGood    = 0.15,
        ChancePoor    = 0.45,
        MoveBoost     = 2.0,         -- chance multiplier while sprinting/jumping
        Dict          = 'clothingtie',
        Anim          = 'try_tie_negative_a',
        Ms            = 1600,
    },
    -- Clothing evaluation (component 11 = top/jacket on freemode peds).
    -- BLOCKLIST approach (whitelists rot): drawables here = bare/uncoverable torso
    -- → cannot conceal. LightTops = can conceal but poorly. Anything else = good.
    -- These are STARTERS — use /mbt_concealdebug in-game to read your outfit's
    -- drawable IDs and extend per your clothing pack.
    Clothing         = {
        BareTorsoMale   = { [15] = true },
        BareTorsoFemale = { [15] = true },
        LightTopsMale   = { [5] = true, [16] = true },
        LightTopsFemale = { [2] = true, [14] = true },
        -- Per-drawable overrides win over everything: [drawableId] = 'good'|'poor'|'none'
        OverridesMale   = {},
        OverridesFemale = {},
    },
}

-- ── Pat-down (LEO frisk) ──────────────────────────────────────────────────────
-- Police physically frisk a nearby person for weapons. NOT an inventory search:
-- it answers "what weapons are on this body, and were they hidden?" — the truth
-- only malisling has (open vs concealed). The target consents (or not); the
-- result lists each weapon with how it was carried (visible / concealed-poor /
-- concealed-good / back-carried) + serial → feeds forensics. Poor concealment is
-- found instantly; good concealment needs a short search. Every frisk → webhook.
MBT.PatDown            = {
    Enabled       = true,
    Key           = '',          -- frisk key (hold near a person, allowed job only) · set in config.lua
    Jobs          = { ['police'] = true, ['sheriff'] = true, ['bcso'] = true },
    MaxDistance   = 2.0,
    RequireConsent = true,        -- target must accept; false = always allowed (hard RP)
    CuffedBypass  = true,         -- skip consent if the target is cuffed
    RequestTimeoutMs = 8000,
    SearchMsPoor  = 600,          -- frisk time before a poorly-hidden weapon is found
    SearchMsGood  = 2600,         -- well-hidden weapon takes longer
    ShowAmmo      = false,        -- include loaded-ammo count in the result (off = weapon + status only)
    Animation     = {
        CopDict = 'mp_arresting', CopAnim = 'a_uncuff', CopMs = 2600,   -- officer frisking gesture
    },
    -- Audit webhook (officer · suspect · weapons · serials · concealment). Server-only
    -- secret → set the URL in config.lua (NOT the dashboard). Empty = off.
    Logging       = { Enabled = true, Webhook = '', BotName = 'MBT Pat-Down' },
}

-- ── Weapon Serials (forensic identity backbone) ────────────────────────────────
-- ox_inventory generates a serial for weapons IT creates — but admin-given,
-- legacy/imported or custom-shop weapons can lack one, silently skipping the
-- whole forensic loop (Custody, Shell Casings, rack picker). EnsureGeneration
-- guarantees every weapon gets a serial the first time the system touches it
-- (rack stow, handoff, drop/throw, an optional on-join sweep, custody repair) —
-- written ONCE, on safe inventory transitions only (never while firing).
MBT.Serials            = {
    EnsureGeneration = true,
    -- 'marked'  = MBT-XXXXXXXX → field-assigned serials are auditable and tell an RP
    --             story (undocumented weapon registered by forensics). Recommended.
    -- 'oxlike'  = indistinguishable from factory ox serials.
    Format           = 'marked',
    SweepOnLoad      = true,    -- scan a player's weapons shortly after they join
}

-- ── Physical Weapon Handoff ───────────────────────────────────────────────────
-- Hand your drawn weapon to a nearby player, hand-to-hand — no dropping it on the
-- ground. Press the handoff key while holding a weapon near someone: they get a
-- key-driven prompt (accept/decline); on accept both play a synced give/take
-- gesture and the weapon moves atomically WITH its metadata (serial, condition,
-- custom name — and Chain of Custody records the new holder on equip).
MBT.Handoff            = {
    Enabled          = true,
    Key              = '',      -- handoff key (hold a weapon, face a nearby player) · set in config.lua
    MaxDistance      = 2.5,      -- how close the receiver must be
    RequestTimeoutMs = 8000,     -- offer expires if not answered
    EquipOnAccept    = false,    -- receiver takes the weapon straight into hand (ox)
    Animation        = {
        GiveDict = 'mp_common', GiveAnim = 'givetake1_a', GiveMs = 900,
        TakeDict = 'mp_common', TakeAnim = 'givetake2_a', TakeMs = 900,
    },
}

-- ── Ammo Sharing ──────────────────────────────────────────────────────────────
-- Hand a portion of your ammo to a nearby player, same flow as the weapon
-- handoff (offer → consent → synced give/take). The ammo type is resolved from
-- the weapon you're holding (its ox ammo item), or your largest ammo stack.
MBT.AmmoSharing        = {
    Enabled          = true,
    Key              = '',      -- share key (hold a weapon, face a nearby player) · set in config.lua
    ShareAmount      = 30,       -- default rounds pre-selected in the amount picker
    Step             = 5,        -- picker adjust step (←/→; SHIFT = ×3)
    MaxDistance      = 2.5,
    RequestTimeoutMs = 8000,
    Animation        = {
        GiveDict = 'mp_common', GiveAnim = 'givetake1_a', GiveMs = 900,
        TakeDict = 'mp_common', TakeAnim = 'givetake2_a', TakeMs = 900,
    },
}

-- ── Forensic Shell Casings ────────────────────────────────────────────────────
-- Firing leaves recoverable shell casings on the ground, linked to the weapon's
-- SERIAL. Anyone can examine a casing (weapon family + masked serial + how long
-- ago it was fired — configurable) and, if allowed, collect it to clean the scene.
-- Pairs with Chain of Custody: a recovered serial → the holder ledger = a full
-- free forensics loop. Casings are ephemeral by design (in-memory, capped,
-- expiring) — no DB. GTA's own ejected brass is a particle effect (not an
-- entity), so the persistent layer is ours: a subtle ground glint by default;
-- servers with a streamed casing model can set Prop to spawn physical casings.
MBT.ShellCasings       = {
    Enabled       = true,
    Chance        = 0.5,      -- probability (0-1, rolled server-side) a shot leaves a casing
    MinIntervalMs = 1200,     -- per-player throttle between casings (burst-proof)
    ExpireMinutes = 30,       -- casings disappear after this long
    MaxCasings    = 150,      -- global cap (oldest removed first)
    GlintRange    = 12.0,     -- distance at which the ground glint is drawn
    InteractRange = 1.2,      -- examine/collect reach
    -- What the examine card reveals of the serial: 'partial' (A7••••9Q) | 'full' | 'none'
    SerialReveal  = 'partial',
    -- Who can EXAMINE: false = everyone; or a job whitelist { ['police'] = true }
    ExamineJobs   = false,
    AllowCollect  = true,     -- pick casings up (criminals cleaning the scene)
    -- Optional physical casing prop (streamed custom model, e.g. from your stream/
    -- folder). nil = ground glint (no asset needed).
    Prop          = nil,
    -- Weapon types that never leave casings (data/weapons.lua types).
    ExcludeTypes  = { ['melee'] = true, ['melee2'] = true, ['melee3'] = true, ['extinguisher'] = true },
    -- Areas where NO casing is generated — shooting ranges, armories, any legal/supervised
    -- fire where forensic brass makes no sense. A shot within radius of a zone leaves nothing
    -- (3D sphere). Grab coords in-world with /mbt_casingzone (prints a ready-to-paste line).
    ExcludeZones  = {
        { coords = vec3(824.97, -2162.98, 29.62), radius = 20.0 },   -- shooting range
    },
}

-- ── Chain of Custody (Forensics) ──────────────────────────────────────────────
-- Each weapon remembers everyone who has carried it, in a SERVER-SIDE ledger keyed by
-- serial — deliberately not in item metadata, because writing metadata on the equip path
-- re-fires ox_inventory's updateInventory and re-spawns the slung prop mid-handling.
-- A holder is appended when they equip it, so ox and qb behave the same. Shown in Inspect.
MBT.ChainOfCustody     = {
    Enabled       = true,
    MaxEntries    = 10,      -- chain cap: origin is always kept + the most recent (MaxEntries-1)
    ShowInInspect = true,    -- show the chain in the weapon Inspect overlay (the holder's own weapon)
    -- Days before an untouched serial's row is dropped at boot. This is the only table with
    -- no natural delete path — a weapon can be destroyed or lost without telling us — so
    -- without a cutoff the ledger only ever grows and is fully read into memory each start.
    -- 0 disables pruning: keep every serial forever, and accept the growth.
    PruneAfterDays = 180,
    -- A "police can read the chain off a dropped/other weapon" view is a future
    -- add-on (lands with Forensic Shell Casings) — not in this build.
}

-- ── No-Draw Zones ─────────────────────────────────────────────────────────────
-- Areas where weapons can't be drawn (hospital, courthouse, bank...). Inside a
-- zone the player's firing is disabled and any drawn weapon is put away again,
-- with a notification. Detection is client-side via ox_lib zones (a determined
-- cheater could bypass it — server-side enforcement is future hardening).
MBT.NoDrawZones        = {
    Enabled        = true,
    AllowMelee     = true,    -- melee weapons stay usable (block firearms only)
    NotifyCooldown = 3000,    -- ms between "can't draw here" notifications
    HudIndicator   = true,    -- show an ox_lib textUI banner while inside a zone
    -- Each zone uses ox_lib zones. type = 'sphere' | 'box' | 'poly'.
    --   sphere: coords + radius
    --   box:    coords + size (vec3) + rotation (deg)
    --   poly:   points (array of vec3) + thickness
    -- Replace these examples with your server's locations.
    Zones          = {
        {
            label  = 'Pillbox Hospital',
            type   = 'sphere',
            coords = vec3(307.7, -1433.4, 29.9),
            radius = 45.0,
        },
        {
            label  = 'Mission Row PD',
            type   = 'sphere',
            coords = vec3(441.0, -982.0, 30.7),
            radius = 40.0,
        },
    },
}

-- ── Low Ready (chest carry) ───────────────────────────────────────────────────
-- Toggle a slung long gun between its back position and a "low ready" chest sling
-- (hands free, gun across the chest). Purely a different attach position for the
-- already-spawned sling prop — no held weapon, no core sling-flow changes. The
-- chest position is tuned per weapon type; values are placeholders to refine with
-- in-game position tuning. Which types are eligible is config-driven
-- (will be player-selectable from the future admin menu).
MBT.LowReady           = {
    Enabled  = true,
    -- Default keybind. The player can always rebind it from FiveM Settings >
    -- Key Bindings (FiveM/Malibu Tech). 'HOME' is chosen because it's almost
    -- never already bound, unlike X (cover) or other action keys.
    Key      = '',  -- set in config.lua
    Command  = 'mbtLowReady',
    -- Sling-prop types eligible for chest carry. Long guns by default — short
    -- weapons (side/melee) keep their own positions.
    Types    = { ['back'] = true, ['back2'] = true },
    -- Chest attach position per type. Bone 24818 = SKEL_Spine3 (upper chest).
    -- Pos/Rot are gender-shared here; split per male/female if needed.
    Position = {
        ['back'] = {
            Bone     = 24818,  -- SKEL_Spine3 (upper chest)
            isPed    = false,
            RotOrder = 2,
            FixedRot = true,
            Pos      = { x = 0.060, y = 0.196, z = -0.004 },
            Rot      = { x = 180.0, y = 142.0, z = -5.0 },
        },
        ['back2'] = {
            Bone     = 24818,
            isPed    = false,
            RotOrder = 2,
            FixedRot = true,
            Pos      = { x = 0.060, y = 0.196, z = -0.004 },
            Rot      = { x = 180.0, y = 142.0, z = -5.0 },
        },
    },
    -- Transition choreography. The prop is re-parented across the body as the
    -- animation plays: back → hand → chest (and reverse), instead of teleporting.
    -- Each step: { dict, anim, duration(ms), place = 'hand'|'chest'|'back',
    -- placeAt = ms into the step when the prop snaps to that spot }.
    Transition = {
        Enabled    = true,
        HandBone   = 57005,  -- SKEL_R_Hand
        -- Grip alignment of the weapon prop while "in hand". A CreateWeaponObject
        -- does NOT auto-align to the grip on the hand bone — the values below are
        -- pre-tuned for the hand bone.
        HandOffset = {
            Pos = { x = 0.076, y = 0.136, z = 0.084 },
            Rot = { x = -43.0, y = 0.0, z = 0.0 },
        },
        -- Back → chest: bring it off the back into the hand, then stow to chest.
        -- mask=true on phase 1 hides the back→hand teleport (prop appears in-hand).
        ToChest = {
            { dict = 'reaction@intimidation@1h', anim = 'intro',     duration = 1900, place = 'hand',  placeAt = 1250, mask = true },
            { dict = 'melee@holster',            anim = 'holster',   duration = 1000, place = 'chest', placeAt = 620, speed = 0.6 },
        },
        -- Chest → back: draw it off the chest into the hand, then put on the back.
        ToBack = {
            { dict = 'melee@holster',            anim = 'unholster', duration = 600,  place = 'hand', placeAt = 260 },
            { dict = 'reaction@intimidation@1h', anim = 'outro',     duration = 1400, place = 'back', placeAt = 1180, mask = true },
        },
    },
}

-- ── Tactical Sling Prop (visible strap) ───────────────────────────────────────
-- Shows a visible sling/strap on the torso while a long gun is slung. Implemented
-- as a PROP attached to a bone (like the weapon-on-back props), NOT a clothing
-- component: clothing would need a per-server drawable index and clash with the
-- server's own addons, making the script non-distributable. A prop only depends
-- on the model shipped in stream/, so it works identically on every server.
--
-- On by default: three strap props ship in stream/belt/, and their offsets below are
-- tuned. To add your own variant: convert the model to a prop .ydr (+ .ytd), drop it in
-- stream/belt/, declare its archetype in mbt_m4_prop.ytyp, add a row to Variants, then
-- place it with the dashboard's Position editor (it appears there as type 'sling:<id>').
MBT.TacticalSling      = {
    Enabled  = true,    -- toggle live from the admin dashboard (NUI), no restart needed
    -- Strap prop variants, shipped in stream/ and declared in mbt_m4_prop.ytyp. Add as many
    -- as you like — each one appears in the NUI's Variant dropdown automatically.
    --   id    = stored/selected value   model = prop model name   label = NUI text
    DefaultVariant = 'normal',   -- variant id used when a job has no override below
    Variants = {
        { id = 'normal', model = 'mbt_belt_prop_b', label = 'Belt — Standard' },
        { id = 'camo',   model = 'mbt_belt_prop_a', label = 'Belt — Camo' },
        { id = 'm4',     model = 'mbt_m4_prop',     label = 'M4 Rig' },
    },
    -- Per-job variant override (editable from the dashboard). e.g. ['police'] = 'camo'.
    -- A job not listed here uses DefaultVariant. Each variant has its own attach position.
    JobVariants = {},
    -- Only show the strap when one of these slung prop types is present.
    Types    = { ['back'] = true, ['back2'] = true },
    -- NOTE: the attach offset lives in MBT.PropInfo.sling (below) so it can be tuned
    -- live from the NUI Positions editor (type 'sling'), per gender, like a weapon.
}

-- Tactical sling attach offset — editable from the NUI Positions editor (type 'sling')
-- and persisted in mbt_malisling_positions. Per-gender (default male = female).
MBT.PropInfo.sling = {
    ["Bone"]     = 24816,   -- Upper back
    ["isPed"]    = false,
    ["RotOrder"] = 2,
    ["FixedRot"] = true,
    -- male tuned in-world; female is still the original seed, not tuned.
    ["Pos"] = {
        ["male"]   = { ["x"] = 0.200, ["y"] = -0.120, ["z"] = -0.115 },
        ["female"] = { ["x"] = 0.252, ["y"] = -0.028, ["z"] = -0.420 },
    },
    ["Rot"] = {
        ["male"]   = { ["x"] = 0.0, ["y"] = 0.0, ["z"] = -25.0 },
        ["female"] = { ["x"] = 0.0, ["y"] = 0.0, ["z"] = -25.0 },
    },
}

-- Seed a per-variant attach offset for every sling variant (key 'sling:<id>'), copied from the
-- shared default above, so the NUI editor can tune each prop separately. The runtime falls back
-- to MBT.PropInfo.sling if a variant has no specific position yet.
do
    local s = MBT.PropInfo.sling
    local function cv(v) return { x = v.x, y = v.y, z = v.z } end
    for _, variant in ipairs(MBT.TacticalSling.Variants) do
        MBT.PropInfo['sling:' .. variant.id] = {
            Bone = s.Bone, isPed = s.isPed, RotOrder = s.RotOrder, FixedRot = s.FixedRot,
            Pos = { male = cv(s.Pos.male), female = cv(s.Pos.female) },
            Rot = { male = cv(s.Rot.male), female = cv(s.Rot.female) },
        }
    end

    -- Offsets tuned in-world for the shipped variants, applied over the seed above.
    -- Guarded by `p`: removing a variant from Variants must not break startup.
    local tuned = {
        ['sling:normal'] = { Pos = { x = 0.175, y = -0.110, z = -0.135 } },
        ['sling:m4']     = { Pos = { x = 0.185, y =  0.405, z = -0.055 },
                             Rot = { x = 89.0,  y = 46.0,   z = -25.0  } },
    }
    for key, offset in pairs(tuned) do
        local p = MBT.PropInfo[key]
        if p then
            if offset.Pos then p.Pos.male = offset.Pos end
            if offset.Rot then p.Rot.male = offset.Rot end
        end
    end
end

-- ── Weapon Safety Toggle ──────────────────────────────────────────────────────
-- Toggle the safety on the held firearm: with safety ON the weapon can't fire and
-- a metallic click plays; an on-screen SAFE/FIRE indicator shows the state. Purely
-- RP — combat mechanics belong to a companion combat resource, which can read the state
-- via the 'mbt_weaponSafety' statebag / exports.IsWeaponSafetyOn().
MBT.Safety             = {
    Enabled    = true,
    Key        = '',        -- rebindable from FiveM Settings > Key Bindings · set in config.lua
    Command    = 'mbtSafety',
    DefaultOn  = false,        -- a freshly drawn weapon starts ready to fire (safety OFF)
    PerWeapon  = true,         -- remember safety per weapon (by serial); false = single global flag
    -- Metallic click on toggle. 'native' = GTA sound, 'nui' = custom .ogg.
    -- WEAPON_SELECT_SHADOW is a short mechanical weapon-wheel click; swap for a
    -- custom .ogg via Mode='nui' (drop web/dist/sounds/safety_click.ogg) later.
    Sound      = {
        Enabled = true,
        Mode    = 'native',
        Native  = { Name = 'WEAPON_SELECT', Set = 'HUD_FRONTEND_WEAPONS_SELECT_SOUNDSET' },
        Nui     = { File = 'safety_click', Volume = 0.5 },
    },
    HudIndicator = true,       -- show the SAFE/FIRE pill while a firearm is in hand
    -- Toggle animation: a truncated, slowed pistol-reload partial — the hand goes
    -- to the weapon as if working the safety selector. Plays on both pistols and
    -- long guns (cosmetic). speed<1 slows it; dur cuts it before the mag swap.
    Animation  = {
        Enabled = true,
        Dict    = 'anim@weapons@first_person@aim_rng@generic@pistol@singleshot@str',
        Anim    = 'reload_aim',
        Flag    = 48,
        Speed   = 0.6,
        Dur     = 750,   -- ~450ms clip / 0.6 speed
    },
}

-- ── Weapon Condition HUD ──────────────────────────────────────────────────────
-- Passive at-a-glance indicator of the held weapon's condition (durability tier
-- 1-5, 5 = pristine). Rendered as muted pips in the SAME "weapon status" pill as
-- the Safety SAFE/FIRE indicator (one element, less HUD clutter). The pip colour
-- only signals a PROBLEM: good = neutral grey (the default, not flagged), worn =
-- orange, damaged = red — green stays exclusive to the Safety FIRE label.
-- The pill shows whenever a firearm is in hand and Safety.HudIndicator OR this is
-- enabled; if both are off it is hidden. Purely visual (data is the same
-- durability the jamming reads).
MBT.ConditionHUD       = {
    Enabled = true,
}

-- ── Custom Weapon Name ────────────────────────────────────────────────────────
-- Engrave a custom name on the held firearm (stored in metadata.label, shown by
-- Weapon Inspect). WHO can do it is fully configurable for the future admin menu.
MBT.WeaponName         = {
    Enabled    = true,
    Command    = 'weaponname',
    Key        = '',            -- '' = command only; set a key to also bind it · set in config.lua
    MaxLength  = 24,            -- name length cap (sanitized: trims + strips control chars)
    -- Permission model:
    --   'everyone' → any player can rename their own weapon
    --   'job'      → only players whose job is in Jobs below
    --   'ace'      → only players with the AcePermission below
    Permission = 'everyone',
    Jobs       = { ['weapon'] = true, ['gunsmith'] = true },  -- used when Permission = 'job'
    AcePermission = 'mbt.weaponname',                          -- used when Permission = 'ace'
    -- OncePerWeapon: once a weapon has a custom name, block re-naming it (only a
    -- gunsmith/admin path could change it later). false = rename freely.
    OncePerWeapon = false,
}

-- ── Weapon Weight / Carry Penalty ─────────────────────────────────────────────
-- Carrying many weapons slightly slows the player (SetPedMoveRateOverride),
-- scaling with how many count toward the penalty above a threshold, up to a cap.
-- Purely RP/immersive — no combat impact. Which weapon GROUPS count is fully
-- configurable. Weapon count is resolved server-side (works on ox + qb).
MBT.WeaponWeight       = {
    Enabled       = true,
    -- How marked the penalty is. Pick a named preset (ready for an admin-menu
    -- dropdown) or 'custom' to use the raw Threshold/PerWeapon/MaxPenalty below.
    --   off    → no penalty
    --   light  → barely noticeable
    --   medium → clearly felt
    --   heavy  → milsim, punishing
    --   custom → use the Threshold/PerWeapon/MaxPenalty fields directly
    Mode          = 'light',
    Presets       = {
        light  = { Threshold = 2, PerWeapon = 0.03, MaxPenalty = 0.18 },  -- down to 82%
        medium = { Threshold = 2, PerWeapon = 0.06, MaxPenalty = 0.30 },  -- down to 70%
        heavy  = { Threshold = 1, PerWeapon = 0.10, MaxPenalty = 0.45 },  -- down to 55%
    },
    -- Used only when Mode = 'custom'.
    Threshold     = 2,      -- no penalty up to this many counted weapons
    PerWeapon     = 0.03,   -- move-rate reduction per weapon beyond the threshold
    MaxPenalty    = 0.18,   -- cap on total reduction (0.18 = down to 82% speed)
    RefreshMs     = 5000,   -- how often the weapon count is re-checked
    -- Weapon GROUPS that count toward the penalty. Add/remove to taste — heavy
    -- long guns by default; pistols and melee don't weigh you down.
    CountGroups   = {
        [`GROUP_RIFLE`]   = true,
        [`GROUP_SMG`]     = true,
        [`GROUP_MG`]      = true,
        [`GROUP_SHOTGUN`] = true,
        [`GROUP_SNIPER`]  = true,
        [`GROUP_HEAVY`]   = true,
        -- [`GROUP_PISTOL`] = true,   -- uncomment to count pistols
        -- [`GROUP_MELEE`]  = true,   -- uncomment to count melee
    },
}

-- ── Charge Weapon (rack the slide) ────────────────────────────────────────────
-- An RP intimidation gesture: rack the slide / charge the weapon with a marked
-- animation + mechanical "clack" sound. No HUD, no ammo readout — purely the
-- gesture, broadcast to nearby players (they see the anim + hear the sound). All
-- firearm groups by default; the admin can disable some.
MBT.ChargeWeapon       = {
    Enabled     = true,
    Key         = '',   -- rebindable from FiveM Settings > Key Bindings · set in config.lua
    Command     = 'mbtcharge',
    MaxDistance = 20.0,        -- nearby players who see/hear the rack
    Cooldown    = 1500,        -- ms between racks (anti-spam)
    -- Animation (truncated/slowed reload partial — the hand works the slide).
    -- Slower = more deliberate/readable as an intimidation rack.
    Animation   = {
        Dict  = 'anim@weapons@first_person@aim_rng@generic@pistol@singleshot@str',
        Anim  = 'reload_aim',
        Flag  = 48,
        Speed = 0.45,
        Dur   = 1100,
    },
    -- Mechanical sound. 'native' = GTA sound, 'nui' = custom .ogg.
    Sound       = {
        Enabled = true,
        Mode    = 'native',
        Native  = { Name = 'Cock_Gun', Set = 'PHONEUI_FAKE_PLAYER_INPUT_SOUNDS' },
        Nui     = { File = 'charge', Volume = 0.6 },
    },
    -- Firearm GROUPS allowed to charge. All firearms on by default; admin trims.
    Groups      = {
        [`GROUP_PISTOL`]  = true,
        [`GROUP_RIFLE`]   = true,
        [`GROUP_SMG`]     = true,
        [`GROUP_MG`]      = true,
        [`GROUP_SHOTGUN`] = true,
        [`GROUP_SNIPER`]  = true,
        [`GROUP_HEAVY`]   = true,
        [`GROUP_STUNGUN`] = true,
    },
}

-- ── Showcase Poses ────────────────────────────────────────────────────────────
-- Static "display" poses to show off the player + their slung weapons (for
-- screenshots, gunshop windows, RP marketplaces). The command enters a looped
-- idle pose; running it again (or /pose <n>) cycles to the next pose; moving,
-- shooting or entering a vehicle exits. Purely cosmetic, local-only (slung props
-- are already visible to others via the scope system).
MBT.ShowcasePoses      = {
    Enabled = true,
    Sync    = true,        -- show your pose to nearby players (group photos); needs a
                           -- replicated statebag, also covers players who arrive later
    Command = 'pose',
    Key     = '',          -- '' = command only; set a key to also bind it · set in config.lua
    -- Pose list. Cycled in order with the command / chosen with /pose <n>.
    -- Base-game idle clips; swap for custom .ycd if desired. Flag 1 = looped.
    Poses   = {
        { label = 'Crossed arms', dict = 'anim@amb@business@bgen@bgen_no_work@', anim = 'idle_a', flag = 1 },
        { label = 'Lean back',    dict = 'amb@world_human_leaning@male@wall@back@foot_up@idle_a', anim = 'idle_a', flag = 1 },
        { label = 'Hands on hips', dict = 'amb@world_human_cop_idles@male@idle_a', anim = 'idle_a', flag = 1 },
        { label = 'Guard stance', dict = 'amb@world_human_guard_stand@male@idle_a', anim = 'idle_a', flag = 1 },
        { label = 'Smoke idle',   dict = 'amb@world_human_aa_smoke@male@idle_a', anim = 'idle_a', flag = 1 },
    },
}
