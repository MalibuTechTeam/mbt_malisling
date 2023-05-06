local GetEntityCoords = GetEntityCoords
local RequestModel = RequestModel
local HasModelLoaded = HasModelLoaded
local Wait = Wait
local GetResourceState = GetResourceState
local GetCurrentResourceName = GetCurrentResourceName
local NetworkIsPlayerActive = NetworkIsPlayerActive
local DeleteObject = DeleteObject
local GetPedBoneIndex = GetPedBoneIndex
local AttachEntityToEntity = AttachEntityToEntity
local type = type
local next = next
local DoesEntityExist = DoesEntityExist
local DeleteEntity = DeleteEntity
local TriggerServerEvent = TriggerServerEvent
local joaat = joaat
local RequestWeaponHighDetailModel = RequestWeaponHighDetailModel
local TriggerEvent = TriggerEvent
local GiveWeaponComponentToWeaponObject = GiveWeaponComponentToWeaponObject
local GetWeaponComponentTypeModel = GetWeaponComponentTypeModel
local DoesWeaponTakeWeaponComponent = DoesWeaponTakeWeaponComponent


local isESX = GetResourceState("es_extended") ~= "missing"
local isQB = GetResourceState("qb-core") ~= "missing"
local isOX = GetResourceState("ox_core") ~= "missing"
if GetResourceState("ox_inventory") ~= "started" then warn("You are not running ox_inventory!"); return; end
local ox_inventory = exports["ox_inventory"]

local FrameworkObj, PlayerData, weaponNames, playersToTrack, lastWeapon, weaponObjectiveSpawned, equippedWeapon = {}, {}, {}, {}, {}, {}, {}
local noWeaponsDict = {["side"] = false, ["back"] = false, ["back2"] = false, ["melee"] = false, ["melee2"] = false, ["melee3"] = false}
local firstSpawn, isReady = true, false

if isESX then
	FrameworkObj = exports["es_extended"]:getSharedObject()

    AddEventHandler('esx:loadingScreenOff', function()
        print("esx:loadingScreenOff FIRED")
        while not FrameworkObj.IsPlayerLoaded() do Wait(200) end
        Init()
    end)

    AddEventHandler("esx:removeInventoryItem", function (itemName, left)
        debugTrace("Item "..itemName.." removed, remaining "..left)
        
        if isWeapon(itemName) then
            local weaponType = Config.WeaponsInfo["Weapons"][itemName]?.type
            if left < 1 and type(weaponType) == "string" then
                if type(playersToTrack[cache.serverId][weaponType]) == "number" then
                    TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
                end
                Wait(500)
                FrameworkObj.PlayerData.inventory = FrameworkObj.GetPlayerData().inventory
                local pWeapons = {}

                for k,v in pairs(FrameworkObj.PlayerData.inventory) do
                    if isWeapon(v.name) then
                        if Config.WeaponsInfo["Weapons"][v.name]?.type == weaponType then
                            if not pWeapons[weaponType] then
                                local weaponData = v
                                weaponData.type = Config.WeaponsInfo["Weapons"][v.name]?.type or "back"
                                pWeapons[weaponType] = weaponData
                                break
                            end
                        end
                    end
                end

                if not isTableEmpty(pWeapons) then handleSling({playerWeapons = pWeapons}) end
            end
        end
    end)
 
elseif isQB then
	FrameworkObj = exports["qb-core"]:GetCoreObject()
elseif isOX then
	local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
    local import = LoadResourceFile('ox_core', file)
    local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
    chunk()
 
    AddEventHandler('ox:playerLoaded', function()
        print("ox:playerLoaded FIRED")
        Init()
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		if NetworkIsPlayerActive(PlayerId()) then
            Init()
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for i=1, #weaponObjectiveSpawned do
        if DoesEntityExist(weaponObjectiveSpawned[i]) then
            DeleteEntity(weaponObjectiveSpawned[i])
        end
    end
end)

RegisterNetEvent("mbt_malisling:loadData")
AddEventHandler("mbt_malisling:loadData", function(t)
    print("mbt_malisling:loadData FIRED")
    Config.WeaponsInfo = t
    print("mbt_malisling:loadData ASSIGNED")
    for k in pairs(Config.WeaponsInfo["Weapons"]) do 
        weaponNames[#weaponNames+1] = tostring(k) 
    end
    print("mbt_malisling:END ITERATION")
    isReady = true
    print("mbt_malisling:isReady")
end)


-- AddEventHandler('mbt_malisling:handleWeaponProps', function(data)
    
--     if data.Action == "Remove" then
--         deleteAllWeapons(true)
--         if data.Restore ~= nil and type(data.Restore) == "boolean" and data.Restore then
--             Wait(1000)
--             TriggerServerEvent("mbt_malisling:checkInventory", true)
--         end
--     elseif data.Action == "Restore" then
--         Wait(1000)
--         TriggerServerEvent("mbt_malisling:checkInventory", true)
--     end

-- end)

RegisterNetEvent("mbt_malisling:syncPlayerRemoval")
AddEventHandler("mbt_malisling:syncPlayerRemoval", function(data)
    if not data then return end
    if not data.playerSource then return end
    if not playersToTrack[data.playerSource] then return end
    playersToTrack[data.playerSource] = nil
end)    

RegisterNetEvent("mbt_malisling:syncDeletion")
AddEventHandler("mbt_malisling:syncDeletion", function(data)
    if not data or not data.weaponType then return end
    if not type(data.weaponType) == "string" then return end

    local weaponType = data.weaponType
    local targetPlayerServerId = data.playerSource
  
    print("Checking deletion client for id ", targetPlayerServerId)
    print("Check DoesEntityExist ~ mbt_malisling:syncDeletion")
  
    local playerToTrack = playersToTrack[targetPlayerServerId]
    if not playerToTrack then return end

    print("Check PRE ~ mbt_malisling:syncDeletion")
    dumpTable(playersToTrack)
    
    if weaponType == "all" then
        
        for wType,v in pairs(playerToTrack) do
            
            if type(playerToTrack[wType]) == "number" then
                DeleteObject(playerToTrack[wType])
                local containsObj, index = containsValue(playersToTrack, playerToTrack[wType])

                if containsObj then table.remove(playersToTrack, index) end
            end
            playerToTrack[wType] = false
        end
    else
        if type(playerToTrack[weaponType]) == "number" then
            DeleteObject(playerToTrack[weaponType])
            local containsObj, index = containsValue(playersToTrack, playerToTrack[weaponType])
            if containsObj then
                table.remove(playersToTrack, index)
            end
        end
        playerToTrack[weaponType] = false
    end
    
    print("Check POST ~ mbt_malisling:syncDeletion")
    dumpTable(playersToTrack)
    
    
end)

RegisterNetEvent("mbt_malisling:checkWeaponProps")
AddEventHandler("mbt_malisling:checkWeaponProps", function(t, bool)
    local ignoreAttach = bool or false
    print("Should ignore attach? "..tostring(ignoreAttach))
    if ignoreAttach then return end

    print("mbt_malisling:checkWeaponProps ~ ", t)
    print("mbt_malisling:checkWeaponProps ~ ", bool)
    if isTableEmpty(t) then debugTrace("Table is empty!") return end
    local playerWeapons = {}

    print("Starting iterating inventory weapons!")
    
    for _, weaponData in pairs(t) do
        if isWeapon(weaponData.name) then
            local weaponType = Config.WeaponsInfo["Weapons"][weaponData.name]?.type
            print("weaponType ", weaponData.name, weaponType	)

            if not playerWeapons[weaponType] then
                weaponData.type = weaponType
                playerWeapons[weaponType] = weaponData
            end

        end
    end
    if not isTableEmpty(playerWeapons) then handleSling({playerWeapons = playerWeapons}) end
end)

RegisterNetEvent('mbt_malisling:syncScope')
AddEventHandler('mbt_malisling:syncScope', function (data)
    local tType = data.tType and data.tType or "add"
    
    print("^4syncScope ~ Scope synced for source "..data.playerSource.." Type "..tType)

    dumpTable(playersToTrack)

    if tType == "del" then
        for k,v in pairs(playersToTrack[data.playerSource]) do
        
            local containsObj, index = containsValue(weaponObjectiveSpawned, v)
            if containsObj then
                if DoesEntityExist(v) then 
                    DeleteEntity(v) 
                end
                table.remove(weaponObjectiveSpawned, index)
            end
        end

        playersToTrack[data.playerSource] = {["side"] = false, ["back"] = false, ["back2"] = false, ["melee"] = false, ["melee2"] = false, ["melee3"] = false}

        return
    end

    TriggerEvent('mbt_malisling:syncSling', data)
end)

RegisterNetEvent('mbt_malisling:syncSling')
AddEventHandler('mbt_malisling:syncSling', function (data)
    print("^2syncSling - Receiving data from server")
    print("data.playerSource  ", data.playerSource)
    if not data then return end
    if not data.playerSource then return end
    print("^2syncSling - Receiving and filling table for source ", data.playerSource)
    local targetPlayerId = GetPlayerFromServerId(data.playerSource)
    print("data.playerSource ", data.playerSource)
    if not targetPlayerId or targetPlayerId == -1 then return end
    print("syncSling - PlayerID is valid ", targetPlayerId)
    local playerPed =  GetPlayerPed(targetPlayerId)
    if not playerPed then return end
    if not data.playerWeapons then return end
    local playerCoords = GetEntityCoords(playerPed)

    if not playersToTrack[data.playerSource] then playersToTrack[data.playerSource] = {} end

    for weaponType, weaponData in pairs(data.playerWeapons) do

        if weaponData ~= false and Config.PropInfo[weaponType] ~= nil and (playersToTrack[data.playerSource][weaponType] == false or playersToTrack[data.playerSource][weaponType] == nil) then
            print("Check PASSED for syncSling!")
            local attachInfo = Config.PropInfo[weaponType]
            local boneIndex = GetPedBoneIndex(playerPed, attachInfo["Bone"])
            weaponData.weaponHash = joaat(weaponData.name)
            requestWeaponAsset(weaponData.weaponHash)
            weaponData.weaponObj = CreateWeaponObject(weaponData.weaponHash , 50, playerCoords.x, playerCoords.y, playerCoords.z, true, 1.0, 0)
            RequestWeaponHighDetailModel(weaponData.weaponObj)
            print("WEAPON OBJ ", weaponData.name, playerPed, boneIndex, attachInfo["Pos"]["x"], attachInfo["Pos"]["y"], attachInfo["Pos"]["z"])
            AttachEntityToEntity(weaponData.weaponObj, playerPed, boneIndex, attachInfo["Pos"]["x"], attachInfo["Pos"]["y"], attachInfo["Pos"]["z"], attachInfo["Rot"]["x"], attachInfo["Rot"]["y"], attachInfo["Rot"]["z"], true, true, false, attachInfo["isPed"], attachInfo["RotOrder"], attachInfo["FixedRot"])
            applyAttachments(weaponData)
            playersToTrack[data.playerSource][weaponType] = weaponData.weaponObj            
            weaponObjectiveSpawned[#weaponObjectiveSpawned+1] = weaponData.weaponObj
        end
    end
end)

function Init()
    -- while isReady == false do print("Waiting"); Wait(100) end
    Config.WeaponsInfo = lib.callback.await('mbt_malisling:getWeapoConf', false)


    print("CB RESOLVED")
    print("wConf ", json.encode(wConf)) 

    print("^4Init has been fired!!!")

    local tempPlayers = GetActivePlayers()
    local activePlayers = {}

    for i=1, #tempPlayers do
        local activePlayerID = GetPlayerServerId(tempPlayers[i])
        if activePlayerID ~= cache.serverId then
            activePlayers[#activePlayers+1] = activePlayerID
        end
    end

    TriggerServerEvent("mbt_malisling:getPlayersInPlayerScope", activePlayers)
    -- Citizen.Wait(2000)    
    print(json.encode(Config.WeaponsInfo))

    TriggerEvent("ox_inv:sendAnim", {
        WeaponData = Config.WeaponsInfo,
        HolsterData = Config.PropInfo
    })
    
    Citizen.Wait(200)
    
    print("Init playersTrack clientside with my source that is "..cache.serverId)

    playersToTrack[cache.serverId] = {["side"] = false, ["back"] = false, ["back2"] = false, ["melee"] = false, ["melee2"] = false, ["melee3"] = false}

    print("playersToTrack filled with my id!!!")
    Wait(200)
    
    AddEventHandler('ox_inventory:currentWeapon', function(data)
        debugTrace("currentWeapon!")

        if data then
            
            local weaponType = Config.WeaponsInfo["Weapons"][data.name]?.type
            -- local weaponProp = Config.WeaponsInfo["Weapons"][data.name]?.prop
            local weaponName = data.name

            debugTrace("You have equipped a "..data.name)

            if playersToTrack[cache.serverId][weaponType] and type(playersToTrack[cache.serverId][weaponType]) == "number" then
                debugTrace("Equip check passed!")
                TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
                equippedWeapon["name"] = weaponName; 
                equippedWeapon["slot"] = data.slot
            end

            lastWeapon = data

        else
            if next(equippedWeapon) == nil then return end
            local weaponType = Config.WeaponsInfo["Weapons"][equippedWeapon["name"]]?.type
            -- local weaponProp = Config.WeaponsInfo["Weapons"][equippedWeapon["name"]]?.prop
            local weaponName = equippedWeapon["name"]

            debugTrace("You have unequipped a "..weaponName)

            local invWeap = ox_inventory:Search('slots', weaponName)

            local playerWeapons = {}

            for _, v in pairs(invWeap) do
                
                if v.slot == equippedWeapon["slot"] then
                    local weaponData = v
                    weaponData.type = Config.WeaponsInfo["Weapons"][v.name]?.type
                    playerWeapons[weaponData.type] = weaponData
                end
            end

            if not isTableEmpty(playerWeapons) then handleSling({playerWeapons = playerWeapons}) end

            equippedWeapon = {}
            lastWeapon = nil
        end
    end)

    AddEventHandler('ox_inventory:itemCount', function(itemName, left)
        debugTrace("Item "..itemName.." removed, remaining "..left)

        if isWeapon(itemName) then
            local weaponType = Config.WeaponsInfo["Weapons"][itemName]?.type

            if left < 1 and type(weaponType) == "string" then
                if type(playersToTrack[cache.serverId][weaponType]) == "number" then
                    TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
                end

                Wait(500)

                local playerWeapons = ox_inventory:Search('slots', weaponNames)
                
                if playerWeapons then
                    local pWeapons = {}

                    for name, data in pairs(playerWeapons) do

                        for _, v in pairs(data) do 

                            if v.count and v.count > 0 then
    
                                if Config.WeaponsInfo["Weapons"][v.name]?.type == weaponType then
    
                                    if not pWeapons[weaponType] then
                                        local weaponData = v
                                        weaponData.type = weaponType
                                        pWeapons[weaponType] = weaponData
                                        break
                                    end
    
                                end
    
                            end
                        end
                        
                    end                    

                    if not isTableEmpty(pWeapons) then
                        handleSling({playerWeapons = pWeapons})
                    end
                end
            end
        end
    end)

    AddEventHandler("ox_inventory:updateInventory", function (data)
        dumpTable(data)

        local _, playerWeapon = GetCurrentPedWeapon(cache.ped, 1)
        
        local playerWeapons = {}

        print("Launched updateInventory ")

        print("Passed updateInventory with playerPed ", cache.ped)
        -- dumpTable(Config.WeaponsInfo)    

        if getTableLength(data) == 1 then
            for k,v in pairs(data) do
                if type(v) == "table" then
                    if isWeapon(v.name) and playerWeapon ~= joaat(v.name) then
                        local weaponType = Config.WeaponsInfo["Weapons"][v.name]?.type
                        -- local weaponProp = Config.WeaponsInfo["Weapons"][v.name]?.prop

                        if not playersToTrack[cache.serverId][weaponType] then
                            debugTrace("Check weapon "..v.name)

                            if not playerWeapons[weaponType] then
                                local weaponData = v
                                weaponData.type = weaponType
                                playerWeapons[weaponType] = weaponData
                            end
                        else
                            debugTrace("Slot "..weaponType.. " BUSY!")
                        end
                    end
                end
            end

            if not isTableEmpty(playerWeapons) then
                handleSling({playerWeapons = playerWeapons})
            end
        end
    end)

    Wait(200)
    TriggerServerEvent("mbt_malisling:checkInventory")
    print("^4Init has been fired ~ END!!!")
end



function applyAttachments(data)
    if data and next(data) ~= nil then
        local components, skin = data.metadata.components

        if components then
            for i = 1, #components do
                local componentName = components[i]
                local isSkin = isComponentASkin(componentName)

                local compsTable = Config.WeaponsInfo.Components[componentName]["client"]["component"]

                for v=1, #compsTable do
                    local component = compsTable[v]

                    if DoesWeaponTakeWeaponComponent(data.weaponHash, component) then
                        local compModel = GetWeaponComponentTypeModel(component)
                        lib.requestModel(compModel)
                        GiveWeaponComponentToWeaponObject(data.weaponObj, component)
                    end
                end
            end
        end
    end
end

function deleteAllWeapons(freeTable)
    local playerToTrack = playersToTrack[cache.serverId]

    for k,v in pairs(playerToTrack) do
        if playerToTrack[k] and DoesEntityExist(v) then
            TriggerServerEvent("mbt_malisling:syncDeletion", k)
        end
        if freeTable and type(freeTable) == "boolean" then
            playerToTrack[k] = false
        end
    end
end

if Config.Debug then
    RegisterCommand("testwtable", function()
        dumpTable(playersToTrack[cache.serverId])
    end, false)

    RegisterCommand("testpped", function()
        print("PlayerPed ", cache.ped)
        print("PlayerPedId ", PlayerPedId())
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

    RegisterCommand("filestest", function()
        -- print("Akkkk")
        TriggerEvent("ox_inv:sendAnim", {
            WeaponData = Config.WeaponsInfo,
            HolsterData = holsterData
        })
    end, false)

    RegisterCommand("dlop", function()
        -- print(GetPedWeaponTintIndex(PlayerPedId(), `WEAPON_PISTOL`))
    end, false)

    RegisterCommand("testatt", function()
        local playerPed = cache.ped
        local x = GetEntityAttachedTo(playerPed)
        -- print(json.encode(x), {indent=true})
    end, false)

    RegisterCommand("spweap", function()
        TriggerServerEvent("mbt_malisling:syncWeaponObj", {})
    end, false)

    RegisterCommand("jiji", function (source, args, raw)
        while not isTableEmpty(weaponObjectiveSpawned) do
            for i=1, #weaponObjectiveSpawned, 1 do
                if DoesEntityExist(weaponObjectiveSpawned[i]) then
                    DeleteObject(weaponObjectiveSpawned[i])
                    table.remove(weaponObjectiveSpawned, i)
                end
            end
    
            Wait(2000)
        end
    end)
    
    RegisterCommand("ptt", function (source, args, raw)
        dumpTable(playersToTrack)
    end)
    
    RegisterCommand("weaponObjectiveSpawned", function (source, args, raw)
        dumpTable(weaponObjectiveSpawned)
    end)
    
    RegisterCommand("jpr", function (source, args, raw)
        while true do
            if IsDisabledControlJustPressed(0, 162) then
                -- print("DISABLE PRESSED 162")
            end
            if IsControlJustPressed(0, 162) then
                -- print("PRESSED 162")
            end
            if IsDisabledControlJustPressed(0, 165) then
                -- print("DISABLE PRESSED 165")
            end
            if IsControlJustPressed(0, 165) then
                -- print("PRESSED 165")
            end
            Wait(1)
        end
    
    end)
    
end



RegisterCommand('hastest', function(source, args)
    -- local hash = args[1]
    
    print(GetWeapontypeModel(`WEAPON_SPECIALCARBINE`))
    print(`w_ar_specialcarbine`)
    print(joaat("w_ar_specialcarbine"))
    print(GetWeapontypeGroup(`WEAPON_SPECIALCARBINE`))
    print(GetWeapontypeGroup(`WEAPON_PISTOL`))
    print(GetWeapontypeGroup(`WEAPON_PISTOL_MK2`))
    print(GetWeapontypeGroup(`WEAPON_MACHETE`))
    print(GetWeapontypeGroup(`WEAPON_BAT`))
    print(GetWeapontypeGroup(`WEAPON_RPG`))
    print(GetWeapontypeGroup(`WEAPON_HOMINGLAUNCHER`))
    

    -- print(GetPickupHashFromWeapon(hash))
end, false)

RegisterCommand('diosda', function(source, args)
    local xx = {
        ["sex"] = "male",
        ["description"] = "Piece of clothing belonging to Moldrok Developer",
        ["Tshirt"] = { ["texture"] = 0, ["index"] = 8, ["drawable"] = 15, ["palette"] = 0 },
        ["Jacket"] = { ["texture"] = 0, ["index"] = 11, ["drawable"] = 16, ["palette"] = 0 },
        ["Arms"] = { ["texture"] = 0, ["index"] = 3, ["drawable"] = 15, ["palette"] = 0 },
    }
    
    print("PIO")
    print(#xx)
    print(table.getn(xx))
end, false)



local cc = true

RegisterCommand('diopooo', function(source, args)
    -- print("Dio ", playersToTrack[8]["back"])
    -- SetCreateWeaponObjectLightSource(playersToTrack[8]["back"], true)

    cc = not cc
    for k,v in pairs(playersToTrack[cache.serverId]) do
        print(GetEntityType(v))
        -- SetEntityVisible(v, cc, 0)
        SetEntityCollision(v, cc, cc)
    end

end, false)

-- lib.onCache('vehicle', function(value)
--     if value then
--         -- TriggerEvent("mbt_malisling:syncDeletion", { playerSource = cache.serverId, weaponType = "all" })
--         -- for k,v in pairs(playersToTrack[cache.serverId]) do
--         --     print(GetEntityType(v))
--         --     SetEntityVisible(v, false, 0)
--         --     SetEntityCollision(v, false, true)
--         -- end
--         deleteAllWeapons(true)       
--     else
--         TriggerServerEvent("mbt_malisling:checkInventory")
--     end
-- end)