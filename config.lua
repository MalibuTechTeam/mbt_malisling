Config = {}
Config.Debug = true

Config.DropWeaponOnDeath = true
Config.EnableSling = true

Config.Bones = { ["Back"] = 24816, ["LHand"] = 36029 }

Config.Labels = {
    ["Holster_Help"] = "[RMOUSE] - Unholster [BACKSPACE] - Cancel",
}

Config.HolsterControls = {
    ["Confirm"] = { ["Label"] = "Confirm Holster", ["Input"] = "MOUSE_BUTTON", ["Key"] = "MOUSE_RIGHT", },
    ["Cancel"] = { ["Label"] = "Cancel Holster", ["Input"] = "keyboard", ["Key"] = "BACK", }
}

Config.PropInfo = {
    ["side"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = -0.09, ["y"] = 0.0, ["z"] = -0.23  },
        ["Rot"] = { ["x"] = 90.0,  ["y"] = 20.0, ["z"] = 180.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true,
        ["HolsterAnim"] = {
            ["dict"] = "reaction@intimidation@cop@unarmed", 
            ["animIn"] = "intro" ,
            ["animOut"] = "outro", 
            ["sleep"] = 400,
            ["sleepOut"] = 450
        }
        
    },
    ["back"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1  },
        ["Rot"] = { ["x"] = 0.0,  ["y"] = 155.0, ["z"] = 0.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true,
        ["HolsterAnim"] = {
            ["dict"] = "reaction@intimidation@1h", 
            ["animIn"] = "intro",
            ["animOut"] = "outro",
            ["sleep"] = 1200,
            ["sleepOut"] = 1200 
        }
    },
    ["back2"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1  },
        ["Rot"] = { ["x"] = 0.0,  ["y"] = -20.0, ["z"] = 0.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true,
        ["HolsterAnim"] = {
            ["dict"] = "reaction@intimidation@1h", 
            ["animIn"] = "intro",
            ["animOut"] = "outro",
            ["sleep"] = 1200,
            ["sleepOut"] = 1200 
        }
    },
    ["melee"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = -0.4, ["y"] = -0.1, ["z"] = 0.22  },
        ["Rot"] = { ["x"] = 90.0,  ["y"] = -10.0, ["z"] = 120.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true,
        ["HolsterAnim"] = {
            ["dict"] = "combat@combat_reactions@pistol_1h_gang", 
            ["animIn"] = "0",
            ["animOut"] = "0",
            ["sleep"] = 500,
            ["sleepOut"] = 500
        }
    },
    ["melee2"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = -0.05,   ["y"] = 0.1,  ["z"] = 0.22  },
        ["Rot"] = { ["x"] = -90.0,  ["y"] = -10.0, ["z"] = 120.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true,
        ["HolsterAnim"] = {
            ["dict"] = "combat@combat_reactions@pistol_1h_hillbilly", 
            ["animIn"] = "0",
            ["animOut"] = "0",
            ["sleep"] = 500,
            ["sleepOut"] = 500
        }
    },
    ["melee3"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = -0.2, ["y"] = -0.18, ["z"] = 0.18  },
        ["Rot"] = { ["x"] = 0.0,  ["y"] = 115.0, ["z"] = 0.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true,
        ["HolsterAnim"] = {
            ["dict"] = "reaction@intimidation@1h", 
            ["animIn"] = "intro",
            ["animOut"] = "outro",
            ["sleep"] = 1200,
            ["sleepOut"] = 1200,
        }
    }
    -- ["sideleg"] = { 
    --     ["dict"] = "reaction@male_stand@big_variations@d",
    --     ["animIn"] = "react_big_variations_m",
    --     ["animOut"] = "react_big_variations_m",
    --     ["sleep"] = 500,
    --     ["sleepOut"] = 500,
    -- }
}