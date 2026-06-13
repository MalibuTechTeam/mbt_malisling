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

-- Inventory is provided by modules/inventory/*/client.lua (ox or qb bridge)
local weaponObjectiveSpawned = {}
local isReady = false
local hasRegistered = false
local propInfoTable = Utils.tableDeepCopy(MBT.PropInfo)
local playerSex

-- Last polled value of IsFlashLightOn(ped). We can't trust a synchronous read in the
-- ox_inventory:currentWeapon(nil) unequip handler because GTA's holster transition clears
-- the held-weapon flashlight before the event fires — the sync read returns 0 even when
-- the player visibly had it on. A 150ms-cadence tracker captures the state shortly before
-- the transition begins, which is what we want to persist to the slung prop's metadata.
local lastFlashlightState = false

equippedWeapon = {}
playersToTrack = {}

--- Reset client state on character logout (multicharacter support)
function ResetForMultichar()
    isReady = false
    equippedWeapon = {}
    if playersToTrack[cache.serverId] then
        playersToTrack[cache.serverId] = {["side"] = false, ["back"] = false, ["back2"] = false, ["melee"] = false, ["melee2"] = false, ["melee3"] = false}
    end
end

--- Delete all attached weapons and sync with server
function deleteAllWeapons()
    local playerToTrack = playersToTrack[cache.serverId]
    if not playerToTrack then return end

    for k, v in pairs(playerToTrack) do
        if type(v) == "number" and DoesEntityExist(v) then
            DeleteObject(v)
            local containsObj, index = Utils.containsValue(weaponObjectiveSpawned, v)
            if containsObj then table.remove(weaponObjectiveSpawned, index) end
            playerToTrack[k] = false
            TriggerServerEvent("mbt_malisling:syncDeletion", k)
        end
    end
end

--- True when the weapon should STAY visible inside this vehicle (roofless: bikes,
--- quads, buggies, convertibles with the top down). Enclosed vehicles return false
--- so the prop is hidden to avoid the barrel clipping through the roof.
---@param veh number
---@return boolean
local function isOpenVehicle(veh)
    local cfg = MBT.VehicleHiding
    if not cfg or not cfg.Enabled then return false end  -- legacy: hide everywhere
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    if cfg.KeepVisibleClasses and cfg.KeepVisibleClasses[GetVehicleClass(veh)] then
        return true
    end
    if cfg.UseRoofCheck and not DoesVehicleHaveRoof(veh) then
        return true
    end
    return false
end

-- Tracks whether we hid/deleted the props for the current vehicle, so we only
-- re-sync on exit when we actually hid something (no redundant re-spawn — and no
-- duplicate props — after riding an open vehicle where we left them visible).
local hiddenForVehicle = false

--- Check when player enter/exit a vehicle, remove weapon objects when enter to avoid weird behaviors caused by props interpenetration and attachments disappears
---@param value number|boolean  vehicle entity when entering, false when exiting
local function onVehicleCheck(value)
    if value then
        -- Open (roofless) vehicle: leave the slung weapon visible, do nothing.
        if isOpenVehicle(value) then
            hiddenForVehicle = false
            return
        end
        deleteAllWeapons()
        local playerToTrack = playersToTrack[cache.serverId]
        if playerToTrack then
            for k,v in pairs(playerToTrack) do
                SetEntityVisible(v, false, 0)
                SetEntityCollision(v, false, true)
            end
        end
        deleteAllWeapons()
        hiddenForVehicle = true
    else
        if hiddenForVehicle then
            hiddenForVehicle = false
            TriggerServerEvent("mbt_malisling:checkInventory")
        end
    end
end

--- Check when player change ped, remove weapon objects when enter to avoid weird behaviors caused by props interpenetration and attachments disappears
local function onPedChange()
    deleteAllWeapons()
    local playerToTrack = playersToTrack[cache.serverId]
    if playerToTrack then
        for k,v in pairs(playerToTrack) do
            SetEntityVisible(v, false, 0)
            SetEntityCollision(v, false, true)
        end
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
    if data and not Utils.isTableEmpty(data) then
        Utils.mbtDebugger(data.metadata)
        local components = data.metadata.components
        if components then
            for i = 1, #components do
                local componentName = components[i]

                if not MBT.EnableFlashlight and Utils.isComponentAFlashlight(componentName) then goto continue; end

                Utils.mbtDebugger("applyAttachments ~ Applying component: ", componentName)
                local compsTable = MBT.WeaponsInfo.Components[componentName]["client"]["component"]

                for v=1, #compsTable do
                    local component = compsTable[v]
                    if DoesWeaponTakeWeaponComponent(data.weaponHash, component) then
                        Utils.mbtDebugger("applyAttachments ~ Component check passed!")
                        local compModel = GetWeaponComponentTypeModel(component)
                        Utils.mbtDebugger("applyAttachments ~ Component model: ", compModel)
                        lib.requestModel(compModel)
                        GiveWeaponComponentToWeaponObject(data.weaponObj, component)
                        SetModelAsNoLongerNeeded(compModel)
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
        Utils.mbtDebugger("waitingForTargetPlayerPed ~ Waiting for player ", data.playerSource)
        if (GetPlayerFromServerId(data.playerSource) and GetPlayerFromServerId(data.playerSource) ~= -1) then
            Utils.mbtDebugger("Player with id "..data.playerSource.." exist!")
            return true
        end

        if not playersToTrack[data.playerSource] or not playersToTrack[data.playerSource]["waiting"] then
            Utils.mbtDebugger("waitingForTargetPlayerPed ~ Player with id "..data.playerSource.." doesn't exist!")
            return false
        end

        Wait(200)
    end
end

local function overwriteValues(newTable)

    for key, value in pairs(newTable) do
        if propInfoTable[key] ~= nil then
            propInfoTable[key]["Pos"] = Utils.tableDeepCopy(value["Pos"])
            propInfoTable[key]["Rot"] = Utils.tableDeepCopy(value["Rot"])
        end
    end
end

local function getAttachInfo(data)
    if MBT.CustomPropPosition[data.Job] and MBT.CustomPropPosition[data.Job][data.Type] then
        return MBT.CustomPropPosition[data.Job][data.Type]
    end
    return MBT.PropInfo[data.Type]
end

--- Resolved back/sling attach info for a prop type, with job overrides applied
--- (propInfoTable is rebuilt by sendAnimations per the local player's job/group).
--- Exposed as a global so sibling client modules (e.g. low_ready) can re-attach a
--- slung prop to its canonical back position without duplicating the job lookup.
---@param propType string
---@return table?
function GetResolvedPropInfo(propType)
    return propInfoTable[propType]
end

--- The slung-prop entity currently tracked for the local player at this type, or
--- nil. (playersToTrack[serverId][type] is the weapon object handle when slung.)
---@param propType string
---@return number?
function GetLocalSlungProp(propType)
    local mine = playersToTrack[cache.serverId]
    local ent = mine and mine[propType]
    if type(ent) == 'number' and DoesEntityExist(ent) then return ent end
    return nil
end

function sendAnimations(jobName)
    -- ox_core uses PlayerData.groups instead of a single job name
    if PlayerData and PlayerData.groups then
        local playerGroups = {}
        for k in pairs(PlayerData.groups) do
            playerGroups[#playerGroups+1] = k
        end
        if #playerGroups == 0 then
            Utils.mbtDebugger("No groups found, setting default!")
            propInfoTable = Utils.tableDeepCopy(MBT.PropInfo)
        else
            for i = 1, #playerGroups do
                local gName = playerGroups[i]
                if MBT.CustomPropPosition[gName] then
                    Utils.mbtDebugger("Custom prop position for group "..gName.." found!")
                    overwriteValues(MBT.CustomPropPosition[gName])
                else
                    Utils.mbtDebugger("No group position customization found, setting default!")
                    propInfoTable = Utils.tableDeepCopy(MBT.PropInfo)
                end
            end
        end
    elseif jobName and MBT.CustomPropPosition[jobName] then
        Utils.mbtDebugger("Custom prop position for job "..jobName.." found!")
        overwriteValues(MBT.CustomPropPosition[jobName])
    else
        propInfoTable = Utils.tableDeepCopy(MBT.PropInfo)
    end

    TriggerEvent("mbt_malisling:sendAnim", {
        WeaponData = MBT.WeaponsInfo,
        HolsterData = propInfoTable
    })
end

function Init()
    isReady = false
    equippedWeapon = {}

    MBT.WeaponsInfo = lib.callback.await('mbt_malisling:getWeapoConf', false)
    Utils.mbtDebugger("Init ~ has been fired!!!")

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

    Utils.mbtDebugger("Init ~  playersTrack clientside with my source that is "..cache.serverId)

    playersToTrack[cache.serverId] = {["side"] = false, ["back"] = false, ["back2"] = false, ["melee"] = false, ["melee2"] = false, ["melee3"] = false}


    Utils.mbtDebugger("Init ~ playersToTrack filled with my id!!!")
    Wait(200)

    if hasRegistered then
        Wait(200)
        TriggerServerEvent("mbt_malisling:checkInventory")
        Utils.mbtDebugger("Init ~ Skipping handler registration (already registered)")
        isReady = true
        return
    end
    hasRegistered = true

    AddEventHandler('ox_inventory:currentWeapon', function(data)
        Utils.mbtDebugger("ox_inventory:currentWeapon ~ Fired!")

        if data then

            local weaponType = MBT.WeaponsInfo["Weapons"][data.name]?.type

            local weaponName = data.name

            Utils.mbtDebugger(data)

            Utils.mbtDebugger("ox_inventory:currentWeapon ~ You have equipped a "..data.name)

            if not playersToTrack[cache.serverId] then return end

            if playersToTrack[cache.serverId][weaponType] and type(playersToTrack[cache.serverId][weaponType]) == "number" then
                Utils.mbtDebugger("ox_inventory:currentWeapon ~ Equip check passed!")
                TriggerEvent('mbt_malisling:onUnholster', weaponType)
                TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
                equippedWeapon["name"] = weaponName;
                equippedWeapon["slot"] = data.slot;
                equippedWeapon["components"] = data.metadata.components;
                equippedWeapon["serial"] = data.metadata.serial;
            end

            if data.metadata.flashlightState then SetFlashLightEnabled(cache.ped, true); end
            -- NOTE: previously here lived a polling thread that ran `while IsPedArmed(ped, 7) do`,
            -- but `IsPedArmed` returns 0/1 (integer) and in Lua 0 is truthy, so the loop never
            -- exited — every equip leaked another thread, and the 250ms polling lag caused stale
            -- `true` values to be written into the saved metadata. We now read IsFlashLightOn
            -- synchronously inside the unequip branch instead.
        else
            if Utils.isTableEmpty(equippedWeapon) then return end

            local weaponName = equippedWeapon["name"]
            if not weaponName then return end
            local hasFlashlight = (equippedWeapon["components"] and Utils.containsValue(equippedWeapon["components"], "at_flashlight"))
                or Utils.weaponHasFlashlight(cache.ped, weaponName, MBT.WeaponsInfo.Components["at_flashlight"]["client"]["component"])
            local currentFlashlightState
            if hasFlashlight then
                -- Use the polled value, not a sync IsFlashLightOn read: by this point GTA
                -- has already cleared the held-weapon flashlight as part of the holster
                -- transition, so a sync read returns 0 even when the player had it on.
                currentFlashlightState = lastFlashlightState
                LocalPlayer.state:set('WeaponFlashlightState', {
                    [equippedWeapon.slot] = {Serial = equippedWeapon.serial, FlashlightState = currentFlashlightState}
                }, true)
            end

            Utils.mbtDebugger("ox_inventory:currentWeapon ~ You have unequipped a "..weaponName)

            local immediateType = MBT.WeaponsInfo["Weapons"][weaponName]?.type
            if immediateType then TriggerEvent('mbt_malisling:onHolster', immediateType) end

            Wait(250)

            local invWeap = Inventory:Search('slots', weaponName)

            local playerWeapons = {}
            for _, v in pairs(invWeap) do
                if v.slot == equippedWeapon["slot"] and not equippedWeapon["dropped"] then
                    local weaponData = v
                    weaponData.type = MBT.WeaponsInfo["Weapons"][v.name]?.type
                    -- ox_inventory's client-side metadata cache may not have received the
                    -- server's state-bag-driven metadata.flashlightState update by the time
                    -- we read it here. Authoritatively override with the value we captured
                    -- synchronously at unequip time so the slung prop spawns with the
                    -- correct light source.
                    if currentFlashlightState ~= nil then
                        weaponData.metadata = weaponData.metadata or {}
                        weaponData.metadata.flashlightState = currentFlashlightState
                    end
                    playerWeapons[weaponData.type] = weaponData
                end
            end
            if not Utils.isTableEmpty(playerWeapons) then
                syncSling({playerWeapons = playerWeapons})
            end

            equippedWeapon = {}
        end
    end)

    AddEventHandler('ox_inventory:itemCount', function(itemName, left)
        Utils.mbtDebugger("ox_inventory:itemCount ~ Item "..itemName.." removed, remaining "..left)

        if Utils.isWeapon(itemName) then
            local weaponType = MBT.WeaponsInfo["Weapons"][itemName]?.type

            if left < 1 and type(weaponType) == "string" then
                if playersToTrack[cache.serverId] and type(playersToTrack[cache.serverId][weaponType]) == "number" then
                    TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
                end

                Wait(500)

                local knownWeaponNames = {}
                for name in pairs(MBT.WeaponsInfo["Weapons"]) do
                    knownWeaponNames[#knownWeaponNames + 1] = name
                end

                local playerWeapons = Inventory:Search('slots', knownWeaponNames)

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

                    if not Utils.isTableEmpty(pWeapons) then
                        syncSling({playerWeapons = pWeapons})
                    end
                end
            end
        end
    end)

    AddEventHandler("ox_inventory:updateInventory", function (data)
        Utils.mbtDebugger(data)

        local _, playerWeapon = GetCurrentPedWeapon(cache.ped, 1)

        local playerWeapons = {}

        Utils.mbtDebugger("ox_inventory:updateInventory ~ Launched updateInventory foe playerPed ", cache.ped)

        for _, v in pairs(data) do
            if type(v) == "table" and Utils.isWeapon(v.name) and playerWeapon ~= joaat(v.name) then
                local weaponType = MBT.WeaponsInfo["Weapons"][v.name] and MBT.WeaponsInfo["Weapons"][v.name]["type"]
                if weaponType then
                    if not playersToTrack[cache.serverId] then return end
                    if not playersToTrack[cache.serverId][weaponType] then
                        Utils.mbtDebugger("ox_inventory:updateInventory ~ Check weapon "..v.name)
                        if not playerWeapons[weaponType] then
                            local weaponData = v
                            weaponData.type = weaponType
                            playerWeapons[weaponType] = weaponData
                        end
                    else
                        Utils.mbtDebugger("ox_inventory:updateInventory ~ Slot "..weaponType.." BUSY!")
                    end
                end
            end
        end

        if not Utils.isTableEmpty(playerWeapons) then
            syncSling({playerWeapons = playerWeapons})
        end
    end)

    Wait(200)
    TriggerServerEvent("mbt_malisling:checkInventory")

    Utils.mbtDebugger("ox_inventory:updateInventory ~ Init END!!!")

    lib.onCache('vehicle', function(value) onVehicleCheck(value); end)
    lib.onCache('ped', onPedChange)

    isReady = true
end

--- Called by ESX bridge when esx:removeInventoryItem fires
function onEsxWeaponRemoved(itemName, left)
    Utils.mbtDebugger("esx:removeInventoryItem ~ Item "..itemName.." removed, remaining "..left)

    if Utils.isWeapon(itemName) then
        local weaponType = MBT.WeaponsInfo["Weapons"][itemName]?.type
        if left < 1 and type(weaponType) == "string" then
            if playersToTrack[cache.serverId] and type(playersToTrack[cache.serverId][weaponType]) == "number" then
                TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
            end
            Wait(500)
            local inventory = ESX.GetPlayerData().inventory
            local pWeapons = {}

            for _, v in pairs(inventory) do
                if Utils.isWeapon(v.name) then
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

            if not Utils.isTableEmpty(pWeapons) then syncSling({playerWeapons = pWeapons}) end
        end
    end
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
    if type(data.weaponType) ~= "string" then return end

    local weaponType = data.weaponType
    local targetPlayerServerId = data.playerSource

    Utils.mbtDebugger("syncDeletion ~ Checking deletion client for id ", targetPlayerServerId)

    local playerToTrack = playersToTrack[targetPlayerServerId]
    if not playerToTrack then return end

    if weaponType == "all" then

        for wType in pairs(playerToTrack) do

            if type(playerToTrack[wType]) == "number" then
                DeleteObject(playerToTrack[wType])
                local containsObj, index = Utils.containsValue(playersToTrack, playerToTrack[wType])

                if containsObj then table.remove(playersToTrack, index) end
            end
            playerToTrack[wType] = false
        end
    else
        if type(playerToTrack[weaponType]) == "number" then
            DeleteObject(playerToTrack[weaponType])
            local containsObj, index = Utils.containsValue(playersToTrack, playerToTrack[weaponType])
            if containsObj then
                table.remove(playersToTrack, index)
            end
        end
        playerToTrack[weaponType] = false
    end


end)

RegisterNetEvent("mbt_malisling:checkWeaponProps")
AddEventHandler("mbt_malisling:checkWeaponProps", function(t)
    if type(t) ~= "table" then return end
    if Utils.isTableEmpty(t) then Utils.mbtDebugger("checkWeaponProps ~ Table is empty!") return end
    local playerWeapons = {}

    Utils.mbtDebugger("checkWeaponProps ~ Starting iterating inventory weapons!")

    for _, weaponData in pairs(t) do
        if Utils.isWeapon(weaponData.name) and MBT.WeaponsInfo["Weapons"][weaponData.name]["type"] then
            local weaponType = MBT.WeaponsInfo["Weapons"][weaponData.name]?.type
            Utils.mbtDebugger("checkWeaponProps ~ weaponType ", weaponData.name, weaponType	)

            if not playerWeapons[weaponType] then
                weaponData.type = weaponType
                playerWeapons[weaponType] = weaponData
            end

        end
    end
    if not Utils.isTableEmpty(playerWeapons) then syncSling({playerWeapons = playerWeapons}) end
end)

RegisterNetEvent('mbt_malisling:syncScope')
AddEventHandler('mbt_malisling:syncScope', function (data)
    local tType = data.tType and data.tType or "add"

    Utils.mbtDebugger("syncScope ~ Scope synced for source "..data.playerSource.." Type "..tType)


    if not playersToTrack[data.playerSource] then  playersToTrack[data.playerSource] = {} end
    if tType == "del" then

        Utils.mbtDebugger("syncScope ~ ", data.playerSource, " has exited from your scope!")

        playersToTrack[data.playerSource]["waiting"] = false

        for _,v in pairs(playersToTrack[data.playerSource]) do

            local containsObj, index = Utils.containsValue(weaponObjectiveSpawned, v)
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
    if not playersToTrack[p] then return end
    playersToTrack[p]["waiting"] = nil
    Utils.mbtDebugger("stopWaitingForPlayer ~ Stopped waiting for player ", p)
end)

RegisterNetEvent('mbt_malisling:syncSling')
AddEventHandler('mbt_malisling:syncSling', function (data)
    while not isReady do Wait(100) end
    Utils.mbtDebugger("syncSling ~ Receiving data from server")
    if not data then return end
    if not data.playerSource then return end

    Utils.mbtDebugger("syncSling ~ Receiving and filling table for source ", data.playerSource)

    local condSatisfied = waitingForTargetPlayerPed(data)
    if not condSatisfied then return end

    local targetPlayerId = GetPlayerFromServerId(data.playerSource)

    if not targetPlayerId or targetPlayerId == -1 then return end
    Utils.mbtDebugger("syncSling ~ PlayerID is valid ", targetPlayerId)
    local _deadline = GetGameTimer() + 10000
    while not DoesEntityExist(GetPlayerPed(targetPlayerId)) do
        if GetGameTimer() > _deadline or GetPlayerFromServerId(data.playerSource) == -1 then
            Utils.mbtDebugger("syncSling ~ Player ped timed out or disconnected, aborting")
            return
        end
        Utils.mbtDebugger("syncSling ~ Player ped is not valid yet")
        Wait(100)
    end

    local playerPed =  GetPlayerPed(targetPlayerId)
    if not playerPed then return end
    if not data.playerWeapons then return end
    local playerCoords = GetEntityCoords(playerPed)
    local playerJob = data.playerJob
    local pedSex = data.pedSex

    Utils.mbtDebugger(data)

    Utils.mbtDebugger("Ped is ", pedSex, " with job ", playerJob)

    for weaponType, weaponData in pairs(data.playerWeapons) do
        if not playersToTrack[data.playerSource] then return end
        -- Concealed Carry guard (opaque hook, no-op without the module): skip
        -- spawning types the player's replicated statebag marks as concealed.
        if weaponData ~= false and propInfoTable[weaponType] ~= nil
            and not (MBT.IsTypeConcealed and MBT.IsTypeConcealed(data.playerSource, weaponType))
            and (playersToTrack[data.playerSource][weaponType] == false or playersToTrack[data.playerSource][weaponType] == nil) then
            Utils.mbtDebugger("syncSling ~ Check passed, creating weapon object!")
            local attachInfo = getAttachInfo({
                Job = playerJob,
                Type = weaponType
            })
            local boneIndex = GetPedBoneIndex(playerPed, attachInfo["Bone"])
            weaponData.weaponHash = joaat(weaponData.name)
            lib.requestWeaponAsset(weaponData.weaponHash, 1000, 31, 1)
            weaponData.weaponObj = CreateWeaponObject(weaponData.weaponHash, 50, playerCoords.x, playerCoords.y, playerCoords.z, true, 1.0, 0)
            RequestWeaponHighDetailModel(weaponData.weaponObj)

            local deadline = GetGameTimer() + 500
            while not DoesEntityExist(weaponData.weaponObj) and GetGameTimer() < deadline do
                Wait(10)
            end

            if not DoesEntityExist(weaponData.weaponObj) then
                Utils.mbtDebugger("syncSling ~ Weapon object failed to create for ", weaponData.name)
            else
                Utils.mbtDebugger("syncSling ~ Weapon object created! ", weaponData.name, playerPed, boneIndex, attachInfo["Pos"][pedSex]["x"], attachInfo["Pos"][pedSex]["y"], attachInfo["Pos"][pedSex]["z"])
                applyAttachments(weaponData)
                local desiredFlashlight = weaponData.metadata and weaponData.metadata.flashlightState and true or false
                SetCreateWeaponObjectLightSource(weaponData.weaponObj, desiredFlashlight)
                -- CRITICAL: do not remove this Wait. The engine needs one tick to commit the
                -- light-source flag onto the weapon object before AttachEntityToEntity is
                -- called, otherwise the attachment pass resets the flag and the slung prop
                -- never renders its flashlight. Regression of fa34b9a (the polling loop that
                -- replaced the original Wait(50) didn't preserve this side-effect).
                Wait(50)
                AttachEntityToEntity(weaponData.weaponObj, playerPed, boneIndex, attachInfo["Pos"][pedSex]["x"], attachInfo["Pos"][pedSex]["y"], attachInfo["Pos"][pedSex]["z"], attachInfo["Rot"][pedSex]["x"], attachInfo["Rot"][pedSex]["y"], attachInfo["Rot"][pedSex]["z"], true, true, false, attachInfo["isPed"], attachInfo["RotOrder"], attachInfo["FixedRot"])
                SetEntityCompletelyDisableCollision(weaponData.weaponObj, false, true)
                SetFlashLightKeepOnWhileMoving(true)
                Utils.mbtDebugger("syncSling ~ Apply attachments to weapon obj!")
                playersToTrack[data.playerSource][weaponType] = weaponData.weaponObj
                weaponObjectiveSpawned[#weaponObjectiveSpawned+1] = weaponData.weaponObj
            end
        end
    end

    playersToTrack[data.playerSource]["waiting"] = nil
end)

exports('ResetWeaponsOnBack', function()
    deleteAllWeapons()
    TriggerServerEvent("mbt_malisling:checkInventory")
end)

-- ── Flashlight state tracker ──────────────────────────────────────────────────
-- Polls IsFlashLightOn at 150ms cadence. Used by the unequip handler to recover
-- the state from the moment BEFORE GTA's holster transition cleared it. Single
-- thread, one native call per tick — negligible cost. Always-on, no gating.
CreateThread(function()
    while true do
        lastFlashlightState = IsFlashLightOn(cache.ped) == 1
        Wait(150)
    end
end)

-- ── Slung prop visibility sync ────────────────────────────────────────────────
-- Keeps each tracked weapon prop's visibility in sync with its owner ped. When a
-- ped is made invisible by a third-party script (admin noclip being the common
-- case), the weapon props attached to it would otherwise stay visible and appear
-- to float in mid-air. Covers the local player and every tracked remote player
-- (handles networked noclip). The vehicle path deletes props rather than hiding
-- them, so the `type(v) == "number"` check naturally skips those entries.
CreateThread(function()
    while true do
        Wait(500)
        for serverId, props in pairs(playersToTrack) do
            local ped
            if serverId == cache.serverId then
                ped = cache.ped
            else
                local plyr = GetPlayerFromServerId(serverId)
                ped = (plyr and plyr ~= -1) and GetPlayerPed(plyr) or nil
            end
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local pedVisible = IsEntityVisible(ped)
                for _, v in pairs(props) do
                    if type(v) == "number" and DoesEntityExist(v)
                       and IsEntityVisible(v) ~= pedVisible then
                        SetEntityVisible(v, pedVisible, 0)
                    end
                end
            end
        end
    end
end)

