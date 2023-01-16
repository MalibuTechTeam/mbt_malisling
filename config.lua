Config = {}
Config.Debug = false

Config.Bones = { ["Back"] = 24816, ["LHand"] = 36029 }

Config.PropInfo = {
    ["side"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = -0.09, ["y"] = 0.0, ["z"] = -0.23  },
        ["Rot"] = { ["x"] = 90.0,  ["y"] = 20.0, ["z"] = 180.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true
        
    },
    ["back"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1  },
        ["Rot"] = { ["x"] = 0.0,  ["y"] = 155.0, ["z"] = 0.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true
    },
    ["back2"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = 0.4, ["y"] = -0.18, ["z"] = 0.1  },
        ["Rot"] = { ["x"] = 0.0,  ["y"] = -20.0, ["z"] = 0.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true
    },
    ["melee"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = -0.4, ["y"] = -0.1, ["z"] = 0.22  },
        ["Rot"] = { ["x"] = 90.0,  ["y"] = -10.0, ["z"] = 120.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true
    },
    ["melee2"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = -0.05,   ["y"] = 0.1,  ["z"] = 0.22  },
        ["Rot"] = { ["x"] = -90.0,  ["y"] = -10.0, ["z"] = 120.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true
    },
    ["melee3"] = {
        ["Bone"] = Config.Bones["Back"],
        ["Pos"] = { ["x"] = -0.2, ["y"] = -0.18, ["z"] = 0.18  },
        ["Rot"] = { ["x"] = 0.0,  ["y"] = 115.0, ["z"] = 0.0 },
        ["isPed"] = false,
        ["RotOrder"] = 2,
        ["FixedRot"] = true
    }
}