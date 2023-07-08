MBT = {}
MBT.Debug = false
MBT.DropWeaponOnDeath = true
MBT.EnableSling = true
MBT.EnableFlashlight = true
MBT.Relog = false -- Put this to true if you have a esx_multicharacter and relog enabled!

MBT.Jamming = {
    ["Enabled"] = true,
    ["Cooldown"] = 5,
    ["Animation"] = { ["Dict"] = "anim@weapons@first_person@aim_rng@generic@pistol@singleshot@str", ["Anim"] = "reload_aim" },
    ["Chance"] = {
        [50] = 10,
        [40] = 15,
        [30] = 20,
        [20] = 25,
        [10] = 30
    }
}

MBT.Throw = {
    ["Enabled"] = true,
    ["Animation"] = { ["Dict"] = "melee@unarmed@streamed_variations", ["Anim"] = "plyr_takedown_front_slap" },
    ["Groups"] = {
        [`GROUP_MELEE`] = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 40.0, ["Y"] = 40.0, ["Z"] = 15.0 } },
        [`GROUP_PISTOL`] = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 15.0 } },
        [`GROUP_RIFLE`] = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 10.0, ["Y"] = 10.0, ["Z"] = 5.0 } },
        [`GROUP_MG`] = { ["Allowed"] = false, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_SMG`] = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_SHOTGUN`] = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_STUNGUN`] = { ["Allowed"] = true, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_SNIPER`] = { ["Allowed"] = false, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
        [`GROUP_HEAVY`] = { ["Allowed"] = false, ["Multipliers"] = { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 } },
    },
    ["Key"] = "K",
    ["Command"] = "throwWeapon"
}

MBT.Bones = { ["Back"] = 24816, ["LHand"] = 36029 }

MBT.HolsterControls = {
    ["Confirm"] = { ["Label"] = "Confirm Holster", ["Input"] = "MOUSE_BUTTON", ["Key"] = "MOUSE_RIGHT", },
    ["Cancel"] = { ["Label"] = "Cancel Holster", ["Input"] = "keyboard", ["Key"] = "BACK", }
}

MBT.Notification = function (data)
    lib.notify(data)
end

MBT.Labels = {
    ["has_jammed"] = {
        ["title"] = "Jammed!",
        ["description"] = "Your weapon has jammed! Check its state! ",
        ["type"] = "error",
        ["icon"] = "fa-solid fa-triangle-exclamation",
    },
    ["has_unjammed"] = {
        ["title"] = "Unjammed!",
        ["description"] = "You have unjammed your weapon! ",
        ["type"] = "success",
        ["icon"] = "fa-solid fa-person-rifle",
    },
    ["no_allowed_throw"] = {
        ["title"] = "Ops!",
        ["description"] = "You are not able to throw this weapon! ",
        ["type"] = "error",
        ["icon"] = "fa-solid fa-hand-fist",
    },
    ["Holster_Help"] = "[RMOUSE] - Unholster [BACKSPACE] - Cancel",

}


MBT.PropInfo = {
    ["side"] = {
        ["Bone"] = MBT.Bones["Back"],
        ["Pos"] = { 
            ["male"] = { ["x"] = -0.15, ["y"] = 0.0, ["z"] = -0.23 }, 
            ["female"] = { ["x"] = -0.15, ["y"] = 0.0, ["z"] = -0.23 }
        },
        ["Rot"] = { 
            ["male"] = { ["x"] = 90.0,  ["y"] = 20.0, ["z"] = 180.0 },
            ["female"] = { ["x"] = 90.0,  ["y"] = 20.0, ["z"] = 180.0 }
        },
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
        ["Bone"] = MBT.Bones["Back"],
        ["Pos"] = { 
            ["male"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
            ["female"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 }
        },
        ["Rot"] = { 
            ["male"] = { ["x"] = 0.0,  ["y"] = 155.0, ["z"] = 0.0 },
            ["female"] = { ["x"] = 0.0,  ["y"] = 155.0, ["z"] = 0.0 }
        },
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
        ["Bone"] = MBT.Bones["Back"],
        ["Pos"] = { 
            ["male"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
            ["female"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
        },
        ["Rot"] = { 
            ["male"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
            ["female"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
        },
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
        ["Bone"] = MBT.Bones["Back"],
        ["Pos"] = { 
            ["male"] = { ["x"] = -0.4, ["y"] = -0.1, ["z"] = 0.22 },
            ["female"] = { ["x"] = -0.4, ["y"] = -0.1, ["z"] = 0.22 }
        },
        ["Rot"] = { 
            ["male"] = { ["x"] = 90.0,  ["y"] = -10.0, ["z"] = 120.0 },
            ["female"] = { ["x"] = 90.0,  ["y"] = -10.0, ["z"] = 120.0 }
        },
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
        ["Bone"] = MBT.Bones["Back"],
        ["Pos"] = { 
            ["male"] = { ["x"] = -0.05,   ["y"] = 0.1,  ["z"] = 0.22 },
            ["female"] = { ["x"] = -0.05,   ["y"] = 0.1,  ["z"] = 0.22 }            
        },
        ["Rot"] = { 
            ["male"] = { ["x"] = -90.0,  ["y"] = -10.0, ["z"] = 120.0  },
            ["female"] = { ["x"] = -90.0,  ["y"] = -10.0, ["z"] = 120.0  }  
        },
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
        ["Bone"] = MBT.Bones["Back"],
        ["Pos"] = { 
            ["male"] = { ["x"] = -0.2, ["y"] = -0.18, ["z"] = 0.18 },
            ["female"] = { ["x"] = -0.2, ["y"] = -0.18, ["z"] = 0.18 }   
        },
        ["Rot"] = { 
            ["male"] = { ["x"] = 0.0,  ["y"] = 115.0, ["z"] = 0.0 },
            ["female"] = { ["x"] = 0.0,  ["y"] = 115.0, ["z"] = 0.0 }
        },
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

MBT.CustomPropPosition = {
    --[[ Preset Example
        ["police"] = { 
            ["side"] = {
                ["Bone"] = MBT.Bones["Back"],
                ["isPed"] = false,
                ["RotOrder"] = 2,
                ["FixedRot"] = true,
                ["Pos"] = { 
                    ["male"] = { ["x"] = -0.15, ["y"] = 0.0, ["z"] = -0.23 }, 
                    ["female"] = { ["x"] = -0.15, ["y"] = 0.0, ["z"] = -0.23 }
                },
                ["Rot"] = { 
                    ["male"] = { ["x"] = 90.0,  ["y"] = 20.0, ["z"] = 180.0 },
                    ["female"] = { ["x"] = 90.0,  ["y"] = 20.0, ["z"] = 180.0 }
                },
            },
            ["back"] = {
                ["Bone"] = MBT.Bones["Back"],
                ["isPed"] = false,
                ["RotOrder"] = 2,
                ["FixedRot"] = true,
                ["Pos"] = { 
                    ["male"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1 },
                    ["female"] = { ["x"] = 0.66, ["y"] = -0.18, ["z"] = 0.1 }
                },
                ["Rot"] = { 
                    ["male"] = { ["x"] = 0.0,  ["y"] = 155.0, ["z"] = 0.0 },
                    ["female"] = { ["x"] = 0.0,  ["y"] = 155.0, ["z"] = 0.0 }
                },
            },
        }
    ]]
}
