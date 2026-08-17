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

-- Brand accent (dashboard-editable): the ONE interactive colour. Every --mbt-accent-*
-- CSS token (fill, hover, tint, focus glow) is derived from this single value, and it
-- repaints the dashboard AND the in-game prompts — they share one NUI document.
-- Must stay '#rrggbb': the value is interpolated straight into CSS custom properties,
-- so anything else is rejected server-side rather than shipped to a browser.
MBT.Accent             = '#00E676'

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
        -- The shipped clips are FRAGMENTS of longer intimidation animations — this one plays
        -- 400ms of 2067 — and they stay that way. 2.1.0 tried replacing them with the
        -- purpose-built holster dictionaries at their measured length and the draw broke in
        -- game: see the note on MBT.DrawStyles.holster. Until that is understood, the clips
        -- that are known to work are the ones that ship.
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
        -- Male tuned in-world. Female is the seed value, REVIEWED IN GAME and kept for
        -- 2.1.0: it reads correctly on the freemode female skeleton, so a separate pass
        -- would move numbers without changing what anyone sees. Not a leftover TODO.
        ["Pos"]         = {
            ["male"]   = { ["x"] = 0.2, ["y"] = -0.21, ["z"] = -0.055 },
            ["female"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = 0.0, ["y"] = 145.0, ["z"] = 0.0 },
            ["female"] = { ["x"] = 0.0, ["y"] = 155.0, ["z"] = 0.0 },
        },
        -- sleep/sleepOut are how long ox blocks before the weapon is in hand: they land
        -- in Items[name].anim via the ox patch, and ox reads them as `anim[3]`. Tune them
        -- against the CLIP, not the clock — go too low and the rifle appears in your hands
        -- while the arm is still reaching behind your back.
        --
        -- 2000 was the original; 1200 matches melee3 and reads snappier. A 2.1.0 attempt to move
        -- this to weapons@holster_2h at its measured 867ms broke the draw in game and was
        -- reverted — the reasoning and what to test is on MBT.DrawStyles.holster.
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
        -- Slower than a rifle, which is right for a launcher.
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
        -- Clip "0" is not a placeholder: combat@combat_reactions@* names its clips after the
        -- ANGLE a threat comes from (-180/-90/0/90/180), so this is "react to someone in front
        -- of you", played for 500ms of its 3000. A reaction rather than a draw, and the most
        -- truncated thing in this file — but it is what works today. melee@holster is one
        -- selection away in the picker.
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
        -- Same shape as `melee` above: a combat reaction, clip named after an angle.
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
        -- Even if the holster clips are adopted one day, this slot has nowhere to go: melee3
        -- holds bats, pool cues and golf clubs together with grenades, molotovs, proximity
        -- mines, a flashlight, a metal detector and a snowball. A two-handed draw over the
        -- shoulder is right for a bat and absurd for a grenade, and `melee@holster` is a weapon
        -- gesture for a slot that is half gadgets. The vague reach-behind of the intimidation
        -- fragment is the only thing that suits all eighteen.
        ["HolsterAnim"] = {
            ["dict"]     = "reaction@intimidation@1h",
            ["animIn"]   = "intro",
            ["animOut"]  = "outro",
            ["sleep"]    = 1200,
            ["sleepOut"] = 1200,
        },
    },
    -- SECOND RIFLE LANE — a slot key like any other, and getAttachInfo prefers it over the
    -- base position plus a lane offset. Tuned in-world, not seed numbers. isPed and the -180
    -- roll are deliberate: the second rifle hangs the other way round so the two do not read
    -- as one weapon drawn twice.
    ["back#2"] = {
        ["Bone"]        = MBT.Bones["Back"],
        ["isPed"]       = true,
        ["RotOrder"]    = 2,
        ["FixedRot"]    = true,
        ["Pos"]         = {
            ["male"]   = { ["x"] = 0.24,  ["y"] = -0.185, ["z"] = -0.075 },
            ["female"] = { ["x"] = 0.385, ["y"] = -0.22,  ["z"] = -0.035 },
        },
        ["Rot"]         = {
            ["male"]   = { ["x"] = -180.0, ["y"] = 155.0, ["z"] = 0.0 },
            ["female"] = { ["x"] = -180.0, ["y"] = 155.0, ["z"] = 0.0 },
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

--- DRAW STYLE — which clip set a slot's `HolsterAnim` is swapped for. Server-wide, set from
--- the dashboard (Placement → DRAW STYLE), applies hot. A style overrides only the slots it
--- names; `standard` names none, so it IS PropInfo.
---
--- A style CANNOT set `sleep`/`sleepOut` and the resolver drops them if it tries. `sleep` is
--- how long the player stands with empty hands, so a style undercutting the base by 200ms is
--- Quick Draw wearing the word "cosmetic" — and Quick Draw is mbt_shooting's.
MBT.DrawStyle = 'standard'

--- Per-job override of the style above. Sparse, same shape as MBT.HiddenByJob. Safe to vary
--- by job ONLY because a style cannot change `sleep` — otherwise this would hand one job a
--- combat advantage over another.
---   ["police"] = "police",
MBT.DrawStyleByJob = {}

--- The clips the in-game gesture picker offers. A SEED, not a gate: the picker always lets
--- an owner type a dict and clip of their own, because this list can never know about a dict
--- they installed themselves.
---
--- Full gesture entries and not clip names, because a slot uses two — `dict`/`animIn` to draw,
--- `dictOut`/`animOut` to put away — and the Police style already needs them to differ.
MBT.DrawStyleCandidates = {
    { id = 'holster_1h',   label = 'Holster — one-handed',  fits = 'side',
      dict = 'weapons@holster_1h',       animIn = 'unholster', animOut = 'holster' },
    { id = 'holster_2h',   label = 'Holster — two-handed',  fits = 'back',
      dict = 'weapons@holster_2h',       animIn = 'unholster', animOut = 'holster' },
    { id = 'holster_fat',  label = 'Holster — bulky',       fits = 'back2',
      dict = 'weapons@holster_fat_2h',   animIn = 'unholster', animOut = 'holster' },
    { id = 'melee',        label = 'Melee',                 fits = 'melee',
      dict = 'melee@holster',            animIn = 'unholster', animOut = 'holster' },
    { id = 'melee_low',    label = 'Melee — from the hip',  fits = 'melee',
      dict = 'melee@holster',            animIn = 'low_r_unholster', animOut = 'holster' },
    { id = 'switchblade',  label = 'Switchblade',           fits = 'melee2',
      dict = 'anim@melee@switchblade@holster', animIn = 'unholster', animOut = 'holster' },
    { id = 'melee_low_l',  label = 'Melee — from the hip, left', fits = 'melee',
      dict = 'melee@holster',            animIn = 'low_l_unholster', animOut = 'holster' },
    { id = 'switchblade_w', label = 'Switchblade — wide',    fits = 'melee2',
      dict = 'anim@melee@switchblade@holster', animIn = 'w_unholster', animOut = 'w_holster' },
    { id = 'rpg',          label = 'Launcher',              fits = 'back2',
      dict = 'weapons@heavy@rpg',        animIn = 'unholster', animOut = 'holster' },
    { id = 'minigun',      label = 'Minigun',               fits = 'back2',
      dict = 'weapons@heavy@minigun',    animIn = 'unholster', animOut = 'holster' },
    { id = 'jerrycan',     label = 'Jerrycan / bulky item', fits = 'extinguisher',
      dict = 'weapon@w_sp_jerrycan',     animIn = 'unholster', animOut = 'holster' },
    { id = 'unarmed',      label = 'Bare hands',
      dict = 'weapons@unarmed',          animIn = 'unholster', animOut = 'holster' },
    -- The superfat dict has NO holster clip, only unholster: pair it with the bulky one for
    -- putting away, which is what `dictOut` is for.
    { id = 'holster_superfat', label = 'Holster — heaviest', fits = 'back2',
      dict = 'weapons@holster_superfat_2h', animIn = 'unholster',
      dictOut = 'weapons@holster_fat_2h',   animOut = 'holster' },
    -- Intimidation gestures. What every slot shipped with UNTIL 2.1.0, and they are not holster
    -- animations: `intro`/`outro`/`step_fwd`/`step_bwd` is somebody threatening someone. They
    -- run 2-4 seconds and were always played as a one-second fragment. Kept so the old look is
    -- one click away (or one selection, via the Legacy style).
    { id = 'intimidate_1h',label = 'Intimidation — one-handed (pre-2.1 default)',
      dict = 'reaction@intimidation@1h', animIn = 'intro', animOut = 'outro' },
    { id = 'intimidate_cop', label = 'Intimidation — police (pre-2.1 default, pistol)',
      dict = 'reaction@intimidation@cop@unarmed', animIn = 'intro', animOut = 'outro' },
    { id = 'cop_leadout',  label = 'Police lead-out',       fits = 'side',
      dict = 'rcmjosh4', animIn = 'josh_leadout_cop2',
      dictOut = 'reaction@intimidation@cop@unarmed', animOut = 'outro' },
    { id = 'cop_leadout_1', label = 'Police lead-out — variant', fits = 'side',
      dict = 'rcmjosh4', animIn = 'josh_leadout_cop1',
      dictOut = 'reaction@intimidation@cop@unarmed', animOut = 'outro' },

    -- ── Aim transitions, by weapon class ──────────────────────────────────────────
    -- GTA's own holstered↔aiming transitions, one dict per weapon class. They end on the weapon
    -- RAISED rather than at rest, so they may read as a draw or as snapping to a target —
    -- audition before picking one.
    { id = 'aim_pistol',   label = 'Aim transition — pistol',    fits = 'side',
      dict = 'weapons@pistol@',              animIn = 'holster_2_aim', animOut = 'aim_2_holster' },
    { id = 'aim_rifle',    label = 'Aim transition — rifle',     fits = 'back',
      dict = 'weapons@rifle@',               animIn = 'holster_2_aim', animOut = 'aim_2_holster' },
    { id = 'aim_mg',       label = 'Aim transition — MG',        fits = 'back',
      dict = 'weapons@machinegun@',          animIn = 'holster_2_aim', animOut = 'aim_2_holster' },
    { id = 'aim_smg',      label = 'Aim transition — SMG',       fits = 'back',
      dict = 'weapons@submg@',               animIn = 'holster_2_aim', animOut = 'aim_2_holster' },
    { id = 'aim_microsmg', label = 'Aim transition — micro SMG', fits = 'side',
      dict = 'weapons@submg@micro_smg',      animIn = 'holster_2_aim', animOut = 'aim_2_holster' },
    { id = 'aim_gl',       label = 'Aim transition — launcher',  fits = 'back2',
      dict = 'weapons@heavy@grenade_launcher', animIn = 'holster_2_aim', animOut = 'aim_2_holster' },
    -- The extinguisher slot's own dict, found the same way. Draw only, so the put-away borrows
    -- the jerrycan's — the two are the same shape of object held the same way.
    { id = 'fire_ext',     label = 'Fire extinguisher',          fits = 'extinguisher',
      dict = 'weapons@misc@fire_ext',        animIn = 'unholster',
      dictOut = 'weapon@w_sp_jerrycan',      animOut = 'holster' },
}

--- Built from the DurtyFree dump (20.179 dicts / 269.414 clips). A prefix filter on
--- holster/unholster/draw/stash found 36 dicts; matching `holster` ANYWHERE found 68 — the
--- whole `holster_2_aim` / `aim_2_holster` family was invisible to the first sweep. Search on
--- the motion, not the name, if this ever needs to grow.
---
--- Deliberately excluded: `weapons@first_person@…` (viewmodel arms, wrong on a full ped),
--- `toolstest@` and `anim@weapons@heavy@space_cannon` (dev dict / DLC-gated),
--- `weapons@projectile@ pull_pin` (arming a grenade, not drawing it). Emote packs yield
--- nothing — mbt_emotes' 639 clips gave zero.

--- Per-style, per-slot clips the owner chose in the picker. Sparse, DB-backed, and separate
--- from MBT.DrawStyles because that catalogue is re-derived from this file every snapshot:
--- persisting it would freeze today's list into the config row for good.
---
--- Resolution order in Utils.holsterAnim: PropInfo base → shipped style → this.
---   ["police"] = { ["side"] = { dict = "...", animIn = "...", animOut = "..." } }
MBT.DrawStyleOverrides = {}

--- Per-slot draw timing, overriding PropInfo's `sleep`/`sleepOut`. Sparse, DB-backed, written
--- by the gesture picker: `sleep` is both the clip's playback length and the gate before the
--- weapon reaches the hand, so a clip picked without it plays a fraction of itself and stops.
---
--- NOT Quick Draw, where a per-style timing would be: this is per SLOT and server-wide, so it
--- moves every player by the same amount. Per-job timing is one job drawing faster than
--- another, and that stays in mbt_shooting. Enforced by shape — the resolver reads timing from
--- here and from PropInfo, nowhere else.
---
--- Clamped 400-4000ms server-side; the floor is the fastest draw this file ships.
---   ["side"] = { sleep = 900, sleepOut = 800 },
MBT.SlotTiming = {}

MBT.DrawStyles = {
    ["standard"] = {
        ["label"] = "Standard",
        -- No overrides: the animations tuned per slot in PropInfo above.
    },
    ["police"] = {
        ["label"] = "Police",
        -- Draws with a different clip and puts away with the base one — the two-dict case
        -- `dictOut` exists for. `rcmjosh4` is a mission dict; the clip is proven in use by
        -- ND_GunAnims, which is where this pairing comes from.
        ["side"] = {
            ["dict"]    = "rcmjosh4",                          ["animIn"]  = "josh_leadout_cop2",
            ["dictOut"] = "reaction@intimidation@cop@unarmed", ["animOut"] = "outro",
        },
        -- melee and melee2 ship a combat REACTION rather than a draw (see PropInfo above). A
        -- style is the safe place to try a real one: opt-in, base untouched.
        ["melee"]  = { ["dict"] = "melee@holster", ["animIn"] = "unholster", ["animOut"] = "holster" },
        ["melee2"] = { ["dict"] = "melee@holster", ["animIn"] = "unholster", ["animOut"] = "holster" },
    },
    ["street"] = {
        ["label"] = "Street",
        -- The pistol drawn with the long-gun gesture instead of the police one. ND_GunAnims
        -- calls this pairing "gang" and uses it as its DEFAULT for GROUP_PISTOL, so it is the
        -- other half of the only two-way choice the base game really offers here.
        ["side"]   = { ["dict"] = "reaction@intimidation@1h", ["animIn"] = "intro", ["animOut"] = "outro" },
        ["melee"]  = { ["dict"] = "melee@holster", ["animIn"] = "unholster", ["animOut"] = "holster" },
        ["melee2"] = { ["dict"] = "melee@holster", ["animIn"] = "unholster", ["animOut"] = "holster" },
    },
}

--- No style ships for GTA's purpose-built holster dictionaries, though every slot above plays
--- a FRAGMENT of a longer clip (19% of it for the pistol, 28% for the rifle). They were tried
--- as the default and the draw broke; retried as a style — same clips, slot's own timing — and
--- it worked. The clips are not the problem; the TIMING is where to look. Nobody has proven it.
---
---   side 800/500 · back and back2 867/500 · melee 833/667 · extinguisher 1067/1067
---   weapons@holster_1h / _2h / _fat_2h · melee@holster · weapon@w_sp_jerrycan
---
--- They are all in MBT.DrawStyleCandidates, so an owner can audition and keep them per slot.

-- Hide sling props per job — seeded from config.lua at install, then owned by the dashboard
-- (Core → HIDDEN BY JOB, stored in the mbt_malisling_config row). Declared here only so the
-- table always exists; there is nothing to fill in at this end.
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
    -- Glow colour, interpolated cold → hot. REJECTED 2026-08-12 after looking at it in game:
    -- a white-hot ramp (physically correct for steel) with radius 0.03 / intensity 0.1 read
    -- worse in every light. Daylight testing misleads here — t = (heat - Warm) / (Max - Warm),
    -- so heat 40 is a twelfth up the ramp, not the midpoint it looks like.
    ColdColour     = { r = 255, g = 110, b = 0 },   -- just past WarmThreshold
    HotColour      = { r = 255, g = 0,   b = 0 },   -- at MaxHeat
    -- Where the glow sits WHEN A SUPPRESSOR IS FITTED. The 'gun_muzzle' bone stays at the
    -- barrel's mouth, while the suppressor is a component bolted further forward — without
    -- this the heat glows at its base instead of on its body. Expressed in the weapon's own
    -- axes, so it follows the gun whether it's in hand or slung, and it is applied ONLY when
    -- a suppressor is really mounted (the companion combat resource glows bare barrels too,
    -- and those must not be shifted).
    -- Tune it in-world with /mbt_muzzletune (debug builds), then paste the numbers here.
    -- y is "down the barrel" on GTA weapon models; x/z are there for the odd model that
    -- doesn't follow that convention.
    SuppressorOffset = { x = 0.0, y = 0.10, z = 0.0 },
    GlowSphere     = {
        -- Retuned to 0.03 / 0.1 on 2026-08-12 and put back: tight and subtle at night, but
        -- gone in daylight, and daylight is where the shot that heats the barrel happens.
        -- Live-tune with /mbt_muzzletune (debug) before changing these.
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
-- Store a weapon on a fixed world rack and retrieve it later. The weapon never lives in a
-- stash: its {name,count,metadata} is held server-side and re-minted on retrieve, like the
-- Trunk Rack. Persisted in mbt_malisling_racks; without oxmysql the racks still work but
-- reset on restart. Props render LOCALLY from GlobalState — never networked objects.
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
    -- Use the rack ITEM: the ped carries the locker, ←/→ rotates, E installs and persists.
    -- An EMPTY rack can be picked back up. Needs oxmysql; without it item placement is off
    -- and config/admin racks keep working.
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
-- Hide the holster prop, IF the clothes can cover it. Server-validated. Clothing sets the
-- quality: none (bare torso, refused) · poor (light top, frequent obvious tells) · good
-- (jacket, rare subtle tells). Quality drives tells and pat-down flavour only, never combat.
-- A weapon in hand is always visible; changing clothes re-checks and force-reveals.
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
-- Firing leaves recoverable casings linked to the weapon's SERIAL: examine one for weapon
-- family, masked serial and age, or collect it to clean the scene. With Chain of Custody a
-- recovered serial reaches the holder ledger. Ephemeral by design — in-memory, capped, no DB.
-- GTA's own brass is a particle, so the persistent layer is ours: a ground glint by default,
-- or a streamed model via Prop.
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
-- A visible strap on the torso while a long gun is slung. A PROP on a bone, not a clothing
-- component: clothing would need a per-server drawable index and clash with the server's own
-- addons. Three straps ship in stream/belt/.
--
-- Your own variant: convert to a prop .ydr (+ .ytd) in stream/belt/, declare the archetype in
-- mbt_m4_prop.ytyp, add a row to Variants, place it in the dashboard as type 'sling:<id>'.
-- ── Multi-Weapon Visibility ───────────────────────────────────────────────────
-- More than one weapon in the same body slot. Up to MaxPerType DISTINCT weapons: copies of
-- the same model share a prop, since two identical rifles side by side read as a fault. A
-- distinct weapon always outranks another variant of one already shown.
--
-- OFF by default — existing servers see exactly what they saw before.
MBT.MultiWeaponVisibility = {
    Enabled    = false,
    MaxPerType = 2,     -- distinct weapons DRAWN per slot; the rest are still tracked
    -- Which slots get an extra lane, and where it starts from. A slot absent here has no
    -- second lane, so a second weapon is tracked but not drawn — deliberate, since the only
    -- alternative is drawing it on top of the first. Lane 1 is never offset.
    --
    -- `back` prefers MBT.PropInfo['back#2'] above, a placed position; this offset is the
    -- fallback for a job that moved the base without placing its own lane. `side` has no
    -- placed lane on purpose — the derived one was judged in game and accepted.
    LaneOffsets = {
        ['back'] = {
            [2] = { Pos = { x = 0.0, y = -0.10, z = 0.0 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } },
        },
        ['side'] = {
            [2] = { Pos = { x = 0.0, y = 0.0, z = 0.14 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } },
        },
    },
}

-- ── Length classes ───────────────────────────────────────────────────────────
-- `back` alone maps 40 weapons sharing one tuned position, so a sawn-off floats where a
-- heavy sniper runs through the shoulder. A class is a SHIFT applied on top, not a position —
-- which is why classes do not multiply lanes: the same shifts apply to every lane.
--
-- Unlisted weapons are `standard` and shift by nothing. The shipped shifts are ZERO: the
-- mechanism is here, the tuning is not.
MBT.WeaponLengthClass = {
    -- compact — short enough that a position tuned for a rifle leaves them hanging
    ['WEAPON_SMG']            = 'compact', ['WEAPON_ASSAULTSMG']  = 'compact',
    ['WEAPON_COMBATPDW']      = 'compact', ['WEAPON_SAWNOFFSHOTGUN'] = 'compact',
    ['WEAPON_DBSHOTGUN']      = 'compact', ['WEAPON_COMPACTLAUNCHER'] = 'compact',
    ['WEAPON_GADGETPISTOL']   = 'compact', ['WEAPON_MACHINEPISTOL'] = 'compact',
    ['WEAPON_MICROSMG']       = 'compact',

    -- long — sticks out past the shoulder at a rifle's position
    ['WEAPON_SNIPERRIFLE']    = 'long', ['WEAPON_HEAVYSNIPER']     = 'long',
    ['WEAPON_HEAVYSNIPER_MK2']= 'long', ['WEAPON_MARKSMANRIFLE']   = 'long',
    ['WEAPON_MARKSMANRIFLE_MK2'] = 'long', ['WEAPON_MUSKET']       = 'long',
    ['WEAPON_MINIGUN']        = 'long', ['WEAPON_RAYMINIGUN']      = 'long',
    ['WEAPON_RAILGUN']        = 'long', ['WEAPON_RAILGUNXM3']      = 'long',
}

-- Per-slot shift for each class, applied on top of whatever position the lane resolved to.
-- Tune 'y' first: on GTA weapon models it is conventionally the axis along the barrel, so it
-- is the one that slides a weapon back into place rather than moving it off the body.
MBT.WeaponClassOffsets = {
    ['back']  = { compact = { Pos = { x = 0.0, y = 0.0, z = 0.0 } },
                  long    = { Pos = { x = 0.0, y = 0.0, z = 0.0 } } },
    ['back2'] = { compact = { Pos = { x = 0.0, y = 0.0, z = 0.0 } },
                  long    = { Pos = { x = 0.0, y = 0.0, z = 0.0 } } },
    ['side']  = { compact = { Pos = { x = 0.0, y = 0.0, z = 0.0 } },
                  long    = { Pos = { x = 0.0, y = 0.0, z = 0.0 } } },
}

-- Seed each extra lane as a prop type of its OWN, keyed '<slot>#<lane>'. From here it is an
-- ordinary position: editable, per-job overridable, persisted. Trade-off: retuning lane 1 no
-- longer drags lane 2 along.
--
-- The offset survives seeding as the fallback for a job that overrode the base without
-- writing its own lane — falling back to the global lane would place the two off different
-- bases and they would intersect.
do
    for slot, byLane in pairs(MBT.MultiWeaponVisibility.LaneOffsets) do
        local base = MBT.PropInfo[slot]
        if base then
            for lane, off in pairs(byLane) do
                local dp, dr = off.Pos or {}, off.Rot or {}
                local out = {
                    Bone = base.Bone, isPed = base.isPed,
                    RotOrder = base.RotOrder, FixedRot = base.FixedRot,
                    Pos = {}, Rot = {},
                }
                for _, sex in ipairs({ 'male', 'female' }) do
                    local bp, br = base.Pos[sex], base.Rot[sex]
                    out.Pos[sex] = { x = bp.x + (dp.x or 0.0), y = bp.y + (dp.y or 0.0), z = bp.z + (dp.z or 0.0) }
                    out.Rot[sex] = { x = br.x + (dr.x or 0.0), y = br.y + (dr.y or 0.0), z = br.z + (dr.z or 0.0) }
                end
                MBT.PropInfo[slot .. '#' .. lane] = out
            end
        end
    end
end

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
    -- Male tuned in-world; female is the seed, reviewed in game and kept — same call as
    -- the back slot above.
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
-- Condition (durability tier 1-5) as muted pips in the SAME pill as Safety's SAFE/FIRE, to
-- keep it one HUD element. Colour signals a PROBLEM only: grey good, orange worn, red damaged
-- — green stays exclusive to the FIRE label. Shown while a firearm is held if this or
-- Safety.HudIndicator is on. Reads the same durability the jamming does.
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
