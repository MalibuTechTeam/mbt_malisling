function debugTrace(t)
    -- assert(type(t) == "string", "Arg is not a string!")
    if Config.Debug then
        if t then
            print("DEBUG | "..t.." [Type: "..type(t).."]") 
        else
            print("Trying to print a nil value!!")
        end 
    end
end

function dumpTable(t)
    if Config.Debug then 
        print(json.encode(t), {indent=true})
    end
end

function loadData (t)
    Config.Weapons = t

    for k, v in pairs(Config) do
        print(k, v)
    end
end

function isWeapon (s)
    return string.sub(s, 1, 7) == "WEAPON_"
end

function requestModel (m)
    RequestModel(m)
	while not HasModelLoaded(m) do Wait(0) end
end

function getTableLength (t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end
  
-- weaponsHolsterData = nil 
-- isInMinigame = false

-- MBT = {}

-- MBT.Holstering = {
--     ["KeepHand"] = true,
--     ["CustomHolster"] = true
-- }

-- WeaponGroup = {
--     ["Unarmed"] = 2685387236,
--     ["Melee"] = 3566412244,
--     ["Pistol"] = 416676503,
--     ["SMG"] = 3337201093,
--     ["AssaultRifle"] = 970310034,
--     ["DigiScanner"] = 3539449195,
--     ["FireExtinguisher"] = 4257178988,
--     ["MG"] = 1159398588,
--     ["NightVision"] = 3493187224,
--     ["Parachute"] = 431593103,
--     ["Shotgun"] = 860033945,
--     ["Sniper"] = 3082541095,
--     ["Stungun"] = 690389602,
--     ["Heavy"] = 2725924767,
--     ["Thrown"] = 1548507267,
--     ["PetrolCan"] = 1595662460
-- }

holsterData = {
    ["side"]   = { 
        ["dict"] = "reaction@intimidation@cop@unarmed", 
        ["animIn"] = "intro" ,
        ["animOut"] = "outro", 
        ["sleep"] = 400,
        ["sleepOut"] = 450 
    },
    ["back"]   = { 
        ["dict"] = "reaction@intimidation@1h", 
        ["animIn"] = "intro",
        ["animOut"] = "outro",
        ["sleep"] = 1200,
        ["sleepOut"] = 1200 
    },
    -- ["back2"]  = { 
    --     ["dict"] = "", 
    --     ["animIn"] = "intro",
    --     ["animOut"] = "" 
    -- },
    ["melee"]  = { 
        ["dict"] = "combat@combat_reactions@pistol_1h_gang", 
        ["animIn"] = "0",
        ["animOut"] = "0",
        ["sleep"] = 500,
        ["sleepOut"] = 500,
    },
    ["melee2"] = { 
        ["dict"] = "combat@combat_reactions@pistol_1h_hillbilly", 
        ["animIn"] = "0",
        ["animOut"] = "0",
        ["sleep"] = 500,
        ["sleepOut"] = 500,
    },
    ["melee3"] = { 
        ["dict"] = "reaction@intimidation@1h", 
        ["animIn"] = "intro",
        ["animOut"] = "outro",
        ["sleep"] = 1200,
        ["sleepOut"] = 1200,
    },
    ["sideleg"] = { 
        ["dict"] = "reaction@male_stand@big_variations@d",
        ["animIn"] = "react_big_variations_m",
        ["animOut"] = "react_big_variations_m",
        ["sleep"] = 500,
        ["sleepOut"] = 500,
    }
}