ox_inventory = exports["ox_inventory"]
GetEntityCoords = assert(GetEntityCoords)
RequestModel = assert(RequestModel)
HasModelLoaded = assert(HasModelLoaded)
Wait = assert(Wait)
GetCurrentResourceName = assert(GetCurrentResourceName)
NetworkIsPlayerActive = assert(NetworkIsPlayerActive)
DeleteObject = assert(DeleteObject)
GetPedBoneIndex = assert(GetPedBoneIndex)
AttachEntityToEntity = assert(AttachEntityToEntity)


local isESX = GetResourceState("es_extended") ~= "missing"
local isQB = GetResourceState("qb-core") ~= "missing"
local isOX = GetResourceState("ox_core") ~= "missing"
local isOXInventory = GetResourceState("ox_inventory") ~= "missing"
local isOXLib = GetResourceState("ox_lib") ~= "missing"
local FrameworkObj = {}

local lastWeapon = {}
local equippedWeapon
local equippedWeaponSlot
local firstSpawn = true
local weaponNames = {}

local attachedWeapons = {
    ["side"] = false,
    ["back"] = false,
    ["back2"] = false,
    ["melee"] = false,
    ["melee2"] = false,
    ["melee3"] = false
}

local playerState = LocalPlayer.state


if isESX then
	FrameworkObj = exports["es_extended"]:getSharedObject()
elseif isQB then
	FrameworkObj = exports["qb-core"]:GetCoreObject()
elseif isOX then
	local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
    local import = LoadResourceFile('ox_core', file)
    local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
    chunk()

    -- RegisterNetEvent('ox:playerDeath', function(state)
    --     local player = Ox.GetPlayer(source)
    --     print("New state is ", state)
    --     local weaponData = exports.ox_inventory:GetCurrentWeapon(_source)
    --     print(json.encode(weaponData), {indent=true})
        
    --     if state == true then   
    --         dropCurrentWeapon(source, data)
    --     end
    -- end)
end

if isOXInventory then  
    ox_inventory = exports["ox_inventory"]
end

-- AddEventHandler("playerSpawned", function()
--     if firstSpawn then
--         print("FIREEEEEEEEEEEEEEEEED")
--         print("Ped ", cache.ped)
--         Init()
--         firstSpawn = false
--     end
-- end)

AddEventHandler('ox:playerLoaded', function() 
    Init()
end)


AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		if NetworkIsPlayerActive(PlayerId()) then
            Citizen.Wait(1000)
            Init()
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    deleteAllWeapons()
end)

AddEventHandler('mbt_malisling:handleWeaponProps', function(data)
    if data.Action == "Remove" then
        deleteAllWeapons(true)
        if data.Restore ~= nil and type(data.Restore) == "boolean" and data.Restore then 
            Wait(1000)
            TriggerServerEvent("mbt_malisling:checkInventory", true)
        end 
    elseif data.Action == "Restore" then
        Wait(1000)
        TriggerServerEvent("mbt_malisling:checkInventory", true)
    end

end)

function getPlayerData()
    local d

    if isOX then
        d  = Ox.GetPlayerData()
    elseif isESX then
        d = FrameworkObj.GetPlayerData()
    elseif isQB then

    end

    return d
end

function Init()
    playerPed = cache.ped
    local playerData = getPlayerData()
    -- print("------------")
    -- print(json.encode(playerData), {indent=true})
    -- print(json.encode(playerState), {indent=true})
    -- print("------------")
    TriggerServerEvent("mbt_malisling:getData")
    Wait(2000)
    TriggerEvent("ox_inv:sendAnim", {
        WeaponData = Config.Weapons,
        HolsterData = holsterData
    })
    Wait(500)
    TriggerServerEvent("mbt_malisling:checkInventory")
end

AddEventHandler('ox_inventory:currentWeapon', function(data)
    debugTrace("currentWeapon!")
    dumpTable(data)

    if data then
        --[[Equipping]]
        local weaponType = Config.Weapons[data.name]?.type
        local weaponProp = Config.Weapons[data.name]?.prop
        local weaponName = data.name
        
        print("weaponName ", weaponName)
        dumpTable(Config.Weapons[data.name])
        
        debugTrace("You have equipped a "..data.name)

        if attachedWeapons[weaponType] and type(attachedWeapons[weaponType]) == "number" then
            debugTrace("Equip check passed!")
            DeleteObject(attachedWeapons[weaponType] )
            attachedWeapons[weaponType] = false
            equippedWeapon = weaponName
            equippedWeaponSlot = data.slot
        end

        print("equippedWeaponSlot equip: ", equippedWeaponSlot)
        lastWeapon = data
        
    else   
        --[[Unequipping]]
        
        local weaponType = Config.Weapons[equippedWeapon]?.type
        local weaponProp = Config.Weapons[equippedWeapon]?.prop
        local weaponName = Config.Weapons[equippedWeapon]?.item
        
        debugTrace(equippedWeapon)
        dumpTable(Config.Weapons[equippedWeapon])
        print("equippedWeaponSlot unequip: ", equippedWeaponSlot)

        if IsPedDeadOrDying(cache.ped) then
            print("Unequipping after dead ", data)
            print(json.encode(lastWeapon), {indent=true})
            TriggerServerEvent("mbt_malisling:dropWeapon", equippedWeaponSlot)
        end


        debugTrace("You have unequipped a "..weaponName)
        local invWeap = ox_inventory:Search('slots', weaponName)
        for _, v in pairs(invWeap) do
            print("There is a "..weaponName.." in slot ", v.slot)
            if v.slot == equippedWeaponSlot then
                handleSling({
                    weaponName = equippedWeapon,
                    weaponProp = weaponProp,
                    weaponType = weaponType
                })
            end
        end

        
        --[[ 
            [ESX]            
            if ESX.PlayerData.inventory[equippedWeaponSlot] then -- Ox 
                handleSling({
                    weaponName = equippedWeapon,
                    weaponProp = weaponProp,
                    weaponType = weaponType
                })
            end
        ]]

        equippedWeapon = nil
        equippedWeaponSlot = nil
        lastWeapon = nil
    end
end)

AddEventHandler('ox_inventory:itemCount', function(itemName, left)
    debugTrace("Item "..itemName.." removed, remaining "..left)

    if isWeapon(itemName) then
        local weaponType = Config.Weapons[itemName]?.type

        if left < 1 and type(weaponType) == "string" then
            if type(attachedWeapons[weaponType]) == "number" then
                DeleteObject(attachedWeapons[weaponType])
            end
            attachedWeapons[weaponType] = false
            Wait(500)
            
            local playerWeapons = ox_inventory:Search('count', weaponNames) -- No check, fill table with weapon names to avoid cb!

            if playerWeapons then
                for name, count in pairs(playerWeapons) do

                    print('You have '..count..' '..name)
                    
                    if count > 0 then
                        
                        if Config.Weapons[name]?.type == weaponType then
                            local weaponProp = Config.Weapons[name]?.prop
                            handleSling({
                                weaponName = name,
                                weaponProp = weaponProp,
                                weaponType = weaponType
                            })
                        end
                    end
               
                end
            end
        end
    end    
end)


--[[
    [ESX]
    AddEventHandler("mal:removeInventoryItem", function (itemName, left)
    debugTrace("Item "..itemName.." removed, remaining "..left)
    if isWeapon(itemName) then
        local weaponType = Config.Weapons[itemName]?.type
        if left < 1 and type(weaponType) == "string" then
            if type(attachedWeapons[weaponType]) == "number" then
                DeleteObject(attachedWeapons[weaponType])
            end
            attachedWeapons[weaponType] = false
            Wait(500)
            ESX.PlayerData.inventory = ESX.GetPlayerData().inventory
            for k,v in pairs(ESX.PlayerData.inventory) do
                if isWeapon(v.name) then
                    if Config.Weapons[v.name]?.type == weaponType then
                        local weaponProp = Config.Weapons[v.name]?.prop
                        handleSling({
                            weaponName = v.name,
                            weaponProp = weaponProp,
                            weaponType = weaponType
                        })
                    end
                    
                end
            end
        end
    end
end)
]]

AddEventHandler("ox_inventory:updateInventory", function (data)
    dumpTable(data)
    local _, playerWeapon = GetCurrentPedWeapon(cache.ped, 1)
    -- debugTrace("data "..getTableLength(data))
    if getTableLength(data) == 1 then
        for k,v in pairs(data) do
            if type(v) == "table" then
                if isWeapon(v.name) and playerWeapon ~= joaat(v.name) then    
                    local weaponType = Config.Weapons[v.name]?.type
                    local weaponProp = Config.Weapons[v.name]?.prop
                    if not attachedWeapons[weaponType] then
                        debugTrace("Check weapon "..v.name)
                        handleSling({
                            weaponName = v.name,
                            weaponProp = weaponProp,
                            weaponType = weaponType
                        })
                    else
                        debugTrace("Slot "..weaponType.. " BUSY!")
                    end
                end
            end
        end
    end
end)

RegisterNetEvent("mbt_malisling:loadData")
AddEventHandler("mbt_malisling:loadData", function(t)
    loadData(t)
    for k in pairs(t) do weaponNames[#weaponNames+1] = tostring(k) end
end)

RegisterNetEvent("mbt_malisling:sendData")
AddEventHandler("mbt_malisling:sendData", function(v)
    TriggerEvent("ox_inventory:getWeaponsData", Config.Weapons)
end)

-- RegisterNetEvent("mbt_malisling:dropHandWeap")
-- AddEventHandler("mbt_malisling:dropHandWeap", function()
    
-- end)

RegisterNetEvent("mbt_malisling:checkWeaponProps")
AddEventHandler("mbt_malisling:checkWeaponProps", function(t, bool)
    local ignoreAttach = bool and bool or false
    debugTrace("Should ignore attach? "..tostring(ignoreAttach))

    for k, v in pairs(t) do
        if isWeapon(t[k]?.name) then
            debugTrace("Check weapon "..t[k].name)
            local weaponType = Config.Weapons[t[k]?.name]?.type
            local weaponProp = Config.Weapons[t[k]?.name]?.prop

            if ignoreAttach or not attachedWeapons[weaponType] then
                debugTrace("checkWeaponProps passed!")
                handleSling({
                    weaponName = t[k].name,
                    weaponProp = weaponProp,
                    weaponType = weaponType
                })
            else
                debugTrace("Slot "..weaponType.. " BUSY!")
            end
        end
    end
end)

--[[

    [5] = { -- slot
        [slot] = 5,
        [name] = "WEAPON_PISTOL",
        [label] = "Pistola Beretta M9",
        [count] = 1,
        [metadata] = {}
    }
]]

function handleSling(data)
    playerPed = cache.ped
    local hash = joaat(data.weaponProp)
    local playerCoords = GetEntityCoords(playerPed)
    if Config.PropInfo[data.weaponType] ~= nil then
        local attachInfo = Config.PropInfo[data.weaponType]
        local boneIndex = GetPedBoneIndex(playerPed, attachInfo["Bone"])
        requestModel(data.weaponProp)
        local weaponObj = CreateObject(hash, playerCoords.xyz, true, true, false)
        AttachEntityToEntity(weaponObj, playerPed, boneIndex, attachInfo["Pos"]["x"], attachInfo["Pos"]["y"], attachInfo["Pos"]["z"], attachInfo["Rot"]["x"], attachInfo["Rot"]["y"], attachInfo["Rot"]["z"], true, true, false, attachInfo["isPed"], attachInfo["RotOrder"], attachInfo["FixedRot"])
        attachedWeapons[data.weaponType] = weaponObj
    end
end

function deleteAllWeapons(freeTable)
    for k,v in pairs(attachedWeapons) do
        if DoesEntityExist(v) then DeleteObject(v) end
        if freeTable and type(freeTable) == "boolean" then 
            v = false
        end
    end
end

if Config.Debug then
    RegisterCommand("testwtable", function()
        dumpTable(attachedWeapons)
    end, false)

    RegisterCommand("testpped", function()
        print("PlayerPed ", cache.ped)
    end, false)

    RegisterCommand("removeWe", function()
        TriggerEvent("mbt_malisling:handleWeaponProps", {
            Action = "Remove",
            Restore = false
        }) 
    end, false)

    RegisterCommand("removeWe2", function()
        TriggerEvent("mbt_malisling:handleWeaponProps", {
            Action = "Remove",
            Restore = true
        }) 
    end, false)

    RegisterCommand("restoreWe", function()
        TriggerEvent("mbt_malisling:handleWeaponProps", {
            Action = "Restore"
        }) 
    end, false)
end

RegisterCommand("filestest", function()
	print("Akkkk")
	TriggerEvent("ox_inv:sendAnim", {
        WeaponData = Config.Weapons,
        HolsterData = holsterData
    })
end, false)