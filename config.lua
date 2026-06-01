MBT                    = {}

-- ── General ───────────────────────────────────────────────────────────────────
MBT.Debug              = true
MBT.DropWeaponOnDeath  = true
MBT.EnableSling        = true
MBT.EnableFlashlight   = true

-- Language for all script + NUI text. Loads from locales/<lang>.lua.
-- Available: 'en', 'fr', 'it'. Add your own by creating locales/<lang>.lua.
MBT.Language           = 'en'

-- ── Admin ─────────────────────────────────────────────────────────────────────
MBT.Admin              = {
    Permission = 'command.mbtconfig', -- ACE permission to open the config panel
    -- Grant it in server.cfg:
    --   add_ace group.admin command.mbtconfig allow
}

-- ── UI ────────────────────────────────────────────────────────────────────────
MBT.UI                 = {
    Position = "bottom-center" -- "bottom-center" | "top-center" | "bottom-right"
}

MBT.Notification       = function(data)
    lib.notify(data)
end

-- Notification labels. Text is resolved from locales/<lang>.lua via titleKey/descKey;
-- only presentation (type, icon) lives here. Fired through MBT.NotifyLabel(key).
MBT.Labels             = {
    ["has_jammed"] = {
        ["titleKey"] = "jam_jammed_title",
        ["descKey"]  = "jam_jammed_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-triangle-exclamation",
    },
    ["has_unjammed"] = {
        ["titleKey"] = "jam_unjammed_title",
        ["descKey"]  = "jam_unjammed_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-person-rifle",
    },
    ["no_allowed_throw"] = {
        ["titleKey"] = "throw_not_allowed_title",
        ["descKey"]  = "throw_not_allowed_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-hand-fist",
    },
    ["no_draw_zone"] = {
        ["titleKey"] = "no_draw_zone_title",
        ["descKey"]  = "no_draw_zone_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-ban",
    },
    ["low_ready_none"] = {
        ["titleKey"] = "low_ready_none_title",
        ["descKey"]  = "low_ready_none_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-person-rifle",
    },
    ["safety_no_weapon"] = {
        ["titleKey"] = "safety_no_weapon_title",
        ["descKey"]  = "safety_no_weapon_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-shield-halved",
    },
}

-- ── Sling / Holster ───────────────────────────────────────────────────────────
MBT.Bones              = {
    ["Back"]   = 24816,
    ["LHand"]  = 36029,
    ["LThigh"] = 58271,
}

MBT.HolsterControls    = {
    ["Confirm"] = { ["Label"] = "Confirm Holster", ["Input"] = "MOUSE_BUTTON", ["Key"] = "MOUSE_RIGHT" },
    ["Cancel"]  = { ["Label"] = "Cancel Holster", ["Input"] = "keyboard", ["Key"] = "BACK" },
}

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
        ["Pos"]         = {
            ["male"]   = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
            ["female"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = 0.0, ["y"] = 155.0, ["z"] = 0.0 },
            ["female"] = { ["x"] = 0.0, ["y"] = 155.0, ["z"] = 0.0 },
        },
        ["HolsterAnim"] = {
            ["dict"]     = "reaction@intimidation@1h",
            ["animIn"]   = "intro",
            ["animOut"]  = "outro",
            ["sleep"]    = 1200,
            ["sleepOut"] = 1200,
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
            ["sleep"]    = 1200,
            ["sleepOut"] = 1200,
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
    -- extinguisher etc.) — values from in-game tuning with /mbt_propedit.
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
-- File audio in web/dist/sounds/ (formato .ogg).
-- default: usato quando nessun override specifico è definito per quel tipo.
-- Override per tipo: decommentare e aggiungere il file .ogg corrispondente.
-- MaxDistance: raggio in metri entro cui i player vicini sentono il suono.
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
    ["Key"]       = "K",
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

-- ── Weapon Inspect ────────────────────────────────────────────────────────────
-- Hold the inspect key to examine the held weapon: plays an inspection animation
-- and shows an overlay with serial, condition, custom name and ammo. The animation
-- is visible to nearby players; the overlay is local-only. Purely visual / RP.
MBT.Inspect            = {
    Enabled     = true,
    Key         = 'I',
    MaxDistance = 20.0,   -- nearby players that see the inspect animation
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
-- /mbt_propedit-style in-game tuning. Which types are eligible is config-driven
-- (will be player-selectable from the future admin menu).
MBT.LowReady           = {
    Enabled  = true,
    -- Default keybind. The player can always rebind it from FiveM Settings >
    -- Key Bindings (FiveM/Malibu Tech). 'HOME' is chosen because it's almost
    -- never already bound, unlike X (cover) or other action keys.
    Key      = 'HOME',
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
        -- does NOT auto-align to the grip on the hand bone — tune these with
        --   /mbt_propedit WEAPON_CARBINERIFLE rhand
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
-- DISABLED by default until you ship a strap prop model. Steps:
--   1. Convert a sling model to a prop .ydr (+ .ytd) — see vault guide.
--   2. Drop it in this resource's stream/ folder.
--   3. Set Model below to the prop's name, tune Position with /mbt_slingpos,
--      then flip Enabled = true.
MBT.TacticalSling      = {
    Enabled  = false,
    Model    = 'mbt_sling_strap',   -- prop model name shipped in stream/
    -- Attach point on the torso. Bone 24818 = SKEL_Spine3 (upper chest).
    -- Tune live with /mbt_slingpos (Debug).
    Position = {
        Bone = 24818,
        Pos  = { x = 0.0, y = 0.08, z = 0.0 },
        Rot  = { x = 0.0, y = 0.0, z = 0.0 },
    },
    -- Only show the strap when one of these slung prop types is present.
    Types    = { ['back'] = true, ['back2'] = true },
}

-- ── Weapon Safety Toggle ──────────────────────────────────────────────────────
-- Toggle the safety on the held firearm: with safety ON the weapon can't fire and
-- a metallic click plays; an on-screen SAFE/FIRE indicator shows the state. Purely
-- RP — combat mechanics belong to mbt_shooting, which can read the state via the
-- 'mbt_weaponSafety' statebag / exports.IsWeaponSafetyOn().
MBT.Safety             = {
    Enabled    = true,
    Key        = 'END',        -- rebindable from FiveM Settings > Key Bindings
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
