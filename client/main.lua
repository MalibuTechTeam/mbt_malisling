local GetEntityCoords = GetEntityCoords
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
local GetPlayerFromServerId = GetPlayerFromServerId
local CreateWeaponObject = CreateWeaponObject
local SetEntityCompletelyDisableCollision = SetEntityCompletelyDisableCollision
local SetFlashLightKeepOnWhileMoving = SetFlashLightKeepOnWhileMoving

local utils = require 'utils'

local isESX = GetResourceState("es_extended") ~= "missing"
local isQB = GetResourceState("qb-core") ~= "missing"
local isOX = GetResourceState("ox_core") ~= "missing"
local isMultichar = GetResourceState("esx_multicharacter") ~= "missing"

local ox_inventory = exports["ox_inventory"]
local FrameworkObj, weaponNames, weaponObjectiveSpawned = {}, {}, {}
local isReady = false
local propInfoTable = utils.tableDeepCopy(MBT.PropInfo)
local playerSex
local flashlightState
local isfirstSpawn = true

equippedWeapon = {}
playersToTrack = {}

--- Delete all attached weapons and sync with server 
local function deleteAllWeapons()
    local playerToTrack = playersToTrack[cache.serverId]

    for k,v in pairs(playerToTrack) do
        if playerToTrack[k] and DoesEntityExist(v) then
            TriggerServerEvent("mbt_malisling:syncDeletion", k)
        end
    end
end

--- Check when player enter/exit a vehicle, remove weapon objects when enter to avoid weird behaviors caused by props interpenetration and attachments disappears
---@param value boolean
local function onVehicleCheck(value)
    if value then
        deleteAllWeapons()
        for k,v in pairs(playersToTrack[cache.serverId]) do
            SetEntityVisible(v, false, 0)
            SetEntityCollision(v, false, true)
        end
        deleteAllWeapons()   
    else
        TriggerServerEvent("mbt_malisling:checkInventory")
    end
end

--- Check when player change ped, remove weapon objects when enter to avoid weird behaviors caused by props interpenetration and attachments disappears
local function onPedChange()
    deleteAllWeapons()
    for k,v in pairs(playersToTrack[cache.serverId]) do
        SetEntityVisible(v, false, 0)
        SetEntityCollision(v, false, true)
    end
    deleteAllWeapons()
    Citizen.Wait(250)
    TriggerServerEvent("mbt_malisling:checkInventory")
end

--- Fire server event for sync
---@param data table
local function syncSling(data)
    TriggerServerEvent("mbt_malisling:syncSling", data)
end
---Apply attachments on weapon object
---@param data table
local function applyAttachments(data)
    if data and not utils.isTableEmpty(data) then
        utils.dumpTable(data.metadata)
        local components = data.metadata.components
        if components then
            for i = 1, #components do
                local componentName = components[i]

                if not MBT.EnableFlashlight and utils.isComponentAFlashlight(componentName) then goto continue; end

                utils.mbtDebugger("applyAttachments ~ Applying component: ", componentName)
                local compsTable = MBT.WeaponsInfo.Components[componentName]["client"]["component"]

                for v=1, #compsTable do
                    local component = compsTable[v]
                    if DoesWeaponTakeWeaponComponent(data.weaponHash, component) then
                        utils.mbtDebugger("applyAttachments ~ Component check passed!")
                        local compModel = GetWeaponComponentTypeModel(component)
                        utils.mbtDebugger("applyAttachments ~ Component model: ", compModel)
                        lib.requestModel(compModel)
                        GiveWeaponComponentToWeaponObject(data.weaponObj, component)
                    end
                end

                ::continue::

            end
        end
    end
end

---Afaik, seems that there is like a "shadow zone" where the player is detected as in scope by the server handler but on client its not truly existing yet, so, waiting if player enter or left our scope and return the outcome
---@param data table
---@return boolean
local function waitingForTargetPlayerPed(data)

    while true do
        utils.mbtDebugger("waitingForTargetPlayerPed ~ Waiting for player ", data.playerSource)
        if (GetPlayerFromServerId(data.playerSource) and GetPlayerFromServerId(data.playerSource) ~= -1) then
            utils.mbtDebugger("Player with id "..data.playerSource.." exist!")
            return true
        end

        if not playersToTrack[data.playerSource]["waiting"] then
            utils.mbtDebugger("waitingForTargetPlayerPed ~ Player with id "..data.playerSource.." doesn't exist!")
            return false
        end

        Wait(200)
    end
end

local function overwriteValues(newTable)

    for key, value in pairs(newTable) do
        if propInfoTable[key] ~= nil then
            propInfoTable[key]["Pos"] = utils.tableDeepCopy(value["Pos"])
            propInfoTable[key]["Rot"] = utils.tableDeepCopy(value["Rot"])
        end
    end
end

local function getAttachInfo(data)
    if MBT.CustomPropPosition[data.Job] and MBT.CustomPropPosition[data.Job][data.Type] then
        return MBT.CustomPropPosition[data.Job][data.Type]
    end
    return MBT.PropInfo[data.Type]
end

function sendAnimations(jobName)
    if MBT.CustomPropPosition[jobName] then
        utils.mbtDebugger("Custom prop position for job "..jobName.. " found!")
        overwriteValues(MBT.CustomPropPosition[jobName])
    else    
        propInfoTable = utils.tableDeepCopy(MBT.PropInfo)
    end

    TriggerEvent("mbt_malisling:sendAnim", {
        WeaponData = MBT.WeaponsInfo,
        HolsterData = propInfoTable
    })
end

local function Init()
    MBT.WeaponsInfo = lib.callback.await('mbt_malisling:getWeapoConf', false)
    utils.mbtDebugger("Init ~ has been fired!!!")

    local tempPlayers = GetActivePlayers()
    local activePlayers = {}

    for i=1, #tempPlayers do
        local activePlayerID = GetPlayerServerId(tempPlayers[i])
        if activePlayerID ~= cache.serverId then
            activePlayers[#activePlayers+1] =  activePlayerID
        end
    end

    TriggerServerEvent("mbt_malisling:getPlayersInPlayerScope", activePlayers)

    sendAnimations(PlayerData.job and PlayerData.job.name or {})
    
    Citizen.Wait(200)
    
    utils.mbtDebugger("Init ~  playersTrack clientside with my source that is "..cache.serverId)

    playersToTrack[cache.serverId] = {["side"] = false, ["back"] = false, ["back2"] = false, ["melee"] = false, ["melee2"] = false, ["melee3"] = false}


    utils.mbtDebugger("Init ~ playersToTrack filled with my id!!!")
    Wait(200)
    
    AddEventHandler('ox_inventory:currentWeapon', function(data)
        utils.mbtDebugger("ox_inventory:currentWeapon ~ Fired!")

        if data then

            local weaponType = MBT.WeaponsInfo["Weapons"][data.name]?.type

            local weaponName = data.name

            utils.dumpTable(data)

            utils.mbtDebugger("ox_inventory:currentWeapon ~ You have equipped a "..data.name)

            if playersToTrack[cache.serverId][weaponType] and type(playersToTrack[cache.serverId][weaponType]) == "number" then
                utils.mbtDebugger("ox_inventory:currentWeapon ~ Equip check passed!")
                TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
                equippedWeapon["name"] = weaponName; 
                equippedWeapon["slot"] = data.slot;
                equippedWeapon["components"] = data.metadata.components;
                equippedWeapon["serial"] = data.metadata.serial;
            end
            
            if data.metadata.flashlightState then SetFlashLightEnabled(cache.ped, true); end

            Citizen.CreateThread(function()
                while IsPedArmed(cache.ped, 7) do
                    flashlightState = IsFlashLightOn(cache.ped) == 1 and true or false
                    Wait(250) 
                end
            end)
        else
            if utils.isTableEmpty(equippedWeapon) then return end
            
            local weaponName = equippedWeapon["name"]
            if equippedWeapon["components"] and utils.containsValue(equippedWeapon["components"], "at_flashlight") or utils.weaponHasFlashlight(cache.ped, weaponName, MBT.WeaponsInfo.Components["at_flashlight"]["client"]["component"]) then
                LocalPlayer.state:set('WeaponFlashlightState', {
                    [equippedWeapon.slot] = {Serial = equippedWeapon.serial, FlashlightState = flashlightState}
                }, true)
            end

            utils.mbtDebugger("ox_inventory:currentWeapon ~ You have unequipped a "..weaponName)

            Wait(250)

            local invWeap = ox_inventory:Search('slots', weaponName)

            local playerWeapons = {}
            for _, v in pairs(invWeap) do
                if v.slot == equippedWeapon["slot"] and not equippedWeapon["dropped"] then
                    local weaponData = v
                    weaponData.type = MBT.WeaponsInfo["Weapons"][v.name]?.type
                    playerWeapons[weaponData.type] = weaponData
                end
            end
            if not utils.isTableEmpty(playerWeapons) then syncSling({playerWeapons = playerWeapons}) end

            equippedWeapon = {}
        end
    end)

    AddEventHandler('ox_inventory:itemCount', function(itemName, left)
        utils.mbtDebugger("ox_inventory:itemCount ~ Item "..itemName.." removed, remaining "..left)

        if utils.isWeapon(itemName) then
            local weaponType = MBT.WeaponsInfo["Weapons"][itemName]?.type

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
    
                                if MBT.WeaponsInfo["Weapons"][v.name]?.type == weaponType then
    
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

                    if not utils.isTableEmpty(pWeapons) then
                        syncSling({playerWeapons = pWeapons})
                    end
                end
            end
        end
    end)

    AddEventHandler("ox_inventory:updateInventory", function (data)
        utils.dumpTable(data)

        local _, playerWeapon = GetCurrentPedWeapon(cache.ped, 1)
        
        local playerWeapons = {}

        utils.mbtDebugger("ox_inventory:updateInventory ~ Launched updateInventory foe playerPed ", cache.ped)

        if utils.getTableLength(data) == 1 then
            for _,v in pairs(data) do
                if type(v) == "table" then
                    if utils.isWeapon(v.name) and playerWeapon ~= joaat(v.name) and MBT.WeaponsInfo["Weapons"][v.name]["type"] then
                        local weaponType = MBT.WeaponsInfo["Weapons"][v.name]?.type


                        if not playersToTrack[cache.serverId][weaponType] then
                            utils.mbtDebugger("ox_inventory:updateInventory ~ Check weapon "..v.name)

                            if not playerWeapons[weaponType] then
                                local weaponData = v
                                weaponData.type = weaponType
                                playerWeapons[weaponType] = weaponData
                            end
                        else
                            utils.mbtDebugger("ox_inventory:updateInventory ~ Slot "..weaponType.. " BUSY!")
                        end
                    end
                end
            end

            if not utils.isTableEmpty(playerWeapons) then
                syncSling({playerWeapons = playerWeapons})
            end
        end
    end)

    Wait(200)
    TriggerServerEvent("mbt_malisling:checkInventory")
    
    utils.mbtDebugger("ox_inventory:updateInventory ~ Init END!!!")

    lib.onCache('vehicle', function(value) onVehicleCheck(value); end)
    lib.onCache('ped', onPedChange)

    isReady = true
end

if isESX then 
	FrameworkObj = exports["es_extended"]:getSharedObject()

    AddEventHandler('esx:loadingScreenOff', function()
        utils.mbtDebugger("esx:loadingScreenOff ~ FIRED")
        while not FrameworkObj.IsPlayerLoaded() do Wait(100) end
        if isMultichar and MBT.Relog and not isfirstSpawn then return end
        isfirstSpawn = false
        Init()
    end)

    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer)
        FrameworkObj.PlayerLoaded = true
        PlayerData = xPlayer
    end)

    PlayerData = FrameworkObj.GetPlayerData()
    
    RegisterNetEvent('esx:setJob')
    AddEventHandler('esx:setJob', function(job)
        PlayerData.job = job
        utils.mbtDebugger("New job is "..PlayerData.job.name)
        sendAnimations(PlayerData.job.name)
    end) 

    RegisterNetEvent("esx:onPlayerLogout", function()
        deleteAllWeapons()
        FrameworkObj.PlayerLoaded = false
        PlayerData = {}
    end)

    AddEventHandler("esx:removeInventoryItem", function (itemName, left)
        utils.mbtDebugger("esx:removeInventoryItem ~ Item "..itemName.." removed, remaining "..left)
        
        if utils.isWeapon(itemName) then
            local weaponType = MBT.WeaponsInfo["Weapons"][itemName]?.type
            if left < 1 and type(weaponType) == "string" then
                if type(playersToTrack[cache.serverId][weaponType]) == "number" then
                    TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
                end
                Wait(500)
                FrameworkObj.PlayerData.inventory = FrameworkObj.GetPlayerData().inventory
                local pWeapons = {}

                for _, v in pairs(FrameworkObj.PlayerData.inventory) do
                    if utils.isWeapon(v.name) then
                        if MBT.WeaponsInfo["Weapons"][v.name]?.type == weaponType then
                            if not pWeapons[weaponType] then
                                local weaponData = v
                                weaponData.type = MBT.WeaponsInfo["Weapons"][v.name]?.type or "back"
                                pWeapons[weaponType] = weaponData
                                break
                            end
                        end
                    end
                end

                if not utils.isTableEmpty(pWeapons) then syncSling({playerWeapons = pWeapons}) end
            end
        end
    end)
 
elseif isQB then
	FrameworkObj = exports["qb-core"]:GetCoreObject()

    PlayerData = FrameworkObj.Functions.GetPlayerData()

    RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
        Init()
    end)

    RegisterNetEvent("QBCore:Client:OnJobUpdate", function(JobInfo)
        PlayerData.job = JobInfo
    end)

elseif isOX then
	local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
    local import = LoadResourceFile('ox_core', file)
    local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
    chunk()
 
    FrameworkObj = Ox

    AddEventHandler('ox:playerLoaded', function(data)
        utils.mbtDebugger("ox:playerLoaded ~ FIRED")
        PlayerData = data
        
        Init()
    end)
    PlayerData = FrameworkObj.GetPlayerData()

 
    sendAnimations = function ()
        local playerGroups = {}
        
        for k in pairs(PlayerData.groups) do
            playerGroups[#playerGroups+1] = k
        end

        if next(playerGroups) == nil then
            utils.mbtDebugger("No groups found, setting default!")
            propInfoTable = utils.tableDeepCopy(MBT.PropInfo)
            return 
        end

        for i=1, #playerGroups do
            local jobName = playerGroups[i]
            if MBT.CustomPropPosition[jobName] then
                utils.mbtDebugger("Custom prop position for job "..jobName.. " found!")
                overwriteValues(MBT.CustomPropPosition[jobName])
            else    
                utils.mbtDebugger("No job position customization found, setting default!")
                propInfoTable = utils.tableDeepCopy(MBT.PropInfo)
            end
        end

        TriggerEvent("mbt_malisling:sendAnim", {
            WeaponData = MBT.WeaponsInfo,
            HolsterData = propInfoTable
        })

       
    end

    
    RegisterNetEvent('ox:setGroup', function(group, grade) 
        PlayerData.groups[group] = grade
        sendAnimations()
    end)
end


AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		if NetworkIsPlayerActive(PlayerId()) then
            while not FrameworkObj do Wait(100) end
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

    utils.mbtDebugger("syncDeletion ~ Checking deletion client for id ", targetPlayerServerId)

    local playerToTrack = playersToTrack[targetPlayerServerId]
    if not playerToTrack then return end
    
    if weaponType == "all" then
        
        for wType in pairs(playerToTrack) do
            
            if type(playerToTrack[wType]) == "number" then
                DeleteObject(playerToTrack[wType])
                local containsObj, index = utils.containsValue(playersToTrack, playerToTrack[wType])

                if containsObj then table.remove(playersToTrack, index) end
            end
            playerToTrack[wType] = false
        end
    else 
        if type(playerToTrack[weaponType]) == "number" then
            DeleteObject(playerToTrack[weaponType])
            local containsObj, index = utils.containsValue(playersToTrack, playerToTrack[weaponType])
            if containsObj then
                table.remove(playersToTrack, index)
            end
        end
        playerToTrack[weaponType] = false
    end
    
    
end)

RegisterNetEvent("mbt_malisling:checkWeaponProps")
AddEventHandler("mbt_malisling:checkWeaponProps", function(t)
    if utils.isTableEmpty(t) then utils.mbtDebugger("checkWeaponProps ~ Table is empty!") return end
    local playerWeapons = {}

    utils.mbtDebugger("checkWeaponProps ~ Starting iterating inventory weapons!")
    
    for _, weaponData in pairs(t) do
        if utils.isWeapon(weaponData.name) and MBT.WeaponsInfo["Weapons"][weaponData.name]["type"] then
            local weaponType = MBT.WeaponsInfo["Weapons"][weaponData.name]?.type
            utils.mbtDebugger("checkWeaponProps ~ weaponType ", weaponData.name, weaponType	)

            if not playerWeapons[weaponType] then
                weaponData.type = weaponType
                playerWeapons[weaponType] = weaponData
            end

        end
    end
    if not utils.isTableEmpty(playerWeapons) then syncSling({playerWeapons = playerWeapons}) end
end)

RegisterNetEvent('mbt_malisling:syncScope')
AddEventHandler('mbt_malisling:syncScope', function (data)
    local tType = data.tType and data.tType or "add"
    
    utils.mbtDebugger("syncScope ~ Scope synced for source "..data.playerSource.." Type "..tType)


    if not playersToTrack[data.playerSource] then  playersToTrack[data.playerSource] = {} end
    if tType == "del" then
        
        utils.mbtDebugger("syncScope ~ ", data.playerSource, " has exited from your scope!")

        playersToTrack[data.playerSource]["waiting"] = false

        for _,v in pairs(playersToTrack[data.playerSource]) do
        
            local containsObj, index = utils.containsValue(weaponObjectiveSpawned, v)
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

    playersToTrack[data.playerSource]["waiting"] = true
    TriggerEvent('mbt_malisling:syncSling', data)
end)

RegisterNetEvent('mbt_malisling:stopWaitingForPlayer')
AddEventHandler('mbt_malisling:stopWaitingForPlayer', function (p)
    playersToTrack[p]["waiting"] = nil
    utils.mbtDebugger("stopWaitingForPlayer ~ Stopped waiting for player ", p)
end)

RegisterNetEvent('mbt_malisling:syncSling')
AddEventHandler('mbt_malisling:syncSling', function (data)
    while not isReady do Wait(100) end
    utils.mbtDebugger("syncSling ~ Receiving data from server")
    if not data then return end
    if not data.playerSource then return end

    utils.mbtDebugger("syncSling ~ Receiving and filling table for source ", data.playerSource)

    local condSatisfied = waitingForTargetPlayerPed(data)
    if not condSatisfied then return end
    
    local targetPlayerId = GetPlayerFromServerId(data.playerSource)

    if not targetPlayerId or targetPlayerId == -1 then return end
    utils.mbtDebugger("syncSling ~ PlayerID is valid ", targetPlayerId)
    while not DoesEntityExist(GetPlayerPed(targetPlayerId)) do
        utils.mbtDebugger("syncSling ~ Player ped is not valid yet")
        Wait(100)
    end

    local playerPed =  GetPlayerPed(targetPlayerId)
    if not playerPed then return end
    if not data.playerWeapons then return end
    local playerCoords = GetEntityCoords(playerPed)
    local playerJob = data.playerJob
    local pedSex = data.pedSex

    utils.dumpTable(data)
    
    utils.mbtDebugger("Ped is ", pedSex, " with job ", playerJob)

    for weaponType, weaponData in pairs(data.playerWeapons) do
        if weaponData ~= false and propInfoTable[weaponType] ~= nil and (playersToTrack[data.playerSource][weaponType] == false or playersToTrack[data.playerSource][weaponType] == nil) then
            utils.mbtDebugger("syncSling ~ Check passed, creating weapon object!")
            local attachInfo = getAttachInfo({
                Job = playerJob,
                Type = weaponType
            })
            local boneIndex = GetPedBoneIndex(playerPed, attachInfo["Bone"])
            weaponData.weaponHash = joaat(weaponData.name)
            lib.requestWeaponAsset(weaponData.weaponHash, 500, 31, 1)
            weaponData.weaponObj = CreateWeaponObject(weaponData.weaponHash , 50, playerCoords.x, playerCoords.y, playerCoords.z, true, 1.0, 0)
            RequestWeaponHighDetailModel(weaponData.weaponObj)
            utils.mbtDebugger("syncSling ~ Weapon object created! ", weaponData.name, playerPed, boneIndex, attachInfo["Pos"][pedSex]["x"], attachInfo["Pos"][pedSex]["y"], attachInfo["Pos"][pedSex]["z"])
            applyAttachments(weaponData)
            SetCreateWeaponObjectLightSource(weaponData.weaponObj, weaponData.metadata.flashlightState)
            Wait(50)
            AttachEntityToEntity(weaponData.weaponObj, playerPed, boneIndex, attachInfo["Pos"][pedSex]["x"], attachInfo["Pos"][pedSex]["y"], attachInfo["Pos"][pedSex]["z"], attachInfo["Rot"][pedSex]["x"], attachInfo["Rot"][pedSex]["y"], attachInfo["Rot"][pedSex]["z"], true, true, false, attachInfo["isPed"], attachInfo["RotOrder"], attachInfo["FixedRot"])
            SetEntityCompletelyDisableCollision(weaponData.weaponObj, false, true)
            SetFlashLightKeepOnWhileMoving(true)
            utils.mbtDebugger("syncSling ~ Apply attachments to weapon obj!")
            playersToTrack[data.playerSource][weaponType] = weaponData.weaponObj            
            weaponObjectiveSpawned[#weaponObjectiveSpawned+1] = weaponData.weaponObj
        end
    end

    playersToTrack[data.playerSource]["waiting"] = nil    
end)

