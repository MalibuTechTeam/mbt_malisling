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
