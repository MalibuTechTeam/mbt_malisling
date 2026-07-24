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

--- True when the weapon stays visible inside this vehicle (roofless: bikes, quads, buggies, convertibles); enclosed vehicles return false so the prop can't clip through the roof.
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

--- On vehicle enter, remove weapon objects (props clip/break otherwise); on exit, re-sync if we hid anything.
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

--- On ped change, remove weapon objects then re-check inventory: stale attachments on the old ped clip/break otherwise.
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

---@param data table
local function syncSling(data)
    TriggerServerEvent("mbt_malisling:syncSling", data)
end

---Apply attachments on weapon object.
---@param data table
---@return boolean appliedFlashlight  true only if a flashlight component was actually given to the object
local function applyAttachments(data)
    local appliedFlashlight = false
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
                        -- Track whether this object really accepted a flashlight: the slung
                        -- prop's light source must only be enabled for weapons that actually
                        -- have one, otherwise stale flashlightState glows the wrong prop.
                        if Utils.isComponentAFlashlight(componentName) then appliedFlashlight = true end
                    end
                end

                ::continue::

            end
        end
    end
    return appliedFlashlight
end

---Scope "shadow zone": server marks the player in-scope before the client ped truly exists.
---Wait until the player resolves (return true) or leaves our scope (return false).
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

--- Resolved back/sling attach info for a prop type, job overrides applied; global so sibling modules (e.g. low_ready) can re-attach a slung prop without duplicating the job lookup.
---@param propType string
---@return table?
function GetResolvedPropInfo(propType)
    return propInfoTable[propType]
end

--- The slung-prop entity tracked for the local player at this type, or nil (playersToTrack[serverId][type] is the weapon object handle when slung).
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

    -- Load DB-persisted prop-position overrides into MBT.PropInfo/CustomPropPosition BEFORE
    -- the first sendAnimations rebuild, so saved editor positions survive a resource restart.
    if MBT.SyncSavedPropPositions then MBT.SyncSavedPropPositions() end

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

            -- Scope the ped-global flashlight to the weapon now in hand: enable it only
            -- when THIS weapon actually has a flashlight component AND its saved state was
            -- on; otherwise explicitly clear it. SetFlashLightEnabled is ped-global, so
            -- without the else the previous weapon's torch carries over to the next weapon
            -- (and leaks into the saved state at unequip → wrong prop glows).
            local eqComponents = data.metadata and data.metadata.components
            local eqHasFlashlight = (eqComponents and Utils.containsValue(eqComponents, "at_flashlight")) and true or false
            if MBT.EnableFlashlight and eqHasFlashlight and data.metadata and data.metadata.flashlightState == true then
                SetFlashLightEnabled(cache.ped, true)
            else
                SetFlashLightEnabled(cache.ped, false)
            end
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

                -- Never re-sling the weapon currently in hand. On qb the equip
                -- transition can fire itemCount (item leaves the grid) while the
                -- ped is now armed; without this guard the re-search would spawn a
                -- slung prop for the held weapon (regression: it stays on the back).
                local _, heldHash = GetCurrentPedWeapon(cache.ped, 1)

                if playerWeapons then
                    local pWeapons = {}

                    for name, data in pairs(playerWeapons) do

                        for _, v in pairs(data) do

                            if v.count and v.count > 0 and joaat(v.name) ~= heldHash then

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
        local e = weaponObjectiveSpawned[i]
        -- Only delete OUR weapon OBJECTS (type 3). Entity handles get recycled by the engine,
        -- so a stale handle left in this registry can point at a ped/vehicle (e.g. an MLO ped)
        -- by now — deleting that is what made interior peds drop on restart.
        if e and DoesEntityExist(e) and GetEntityType(e) == 3 then
            DeleteEntity(e)
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
                -- Remove the handle from the SPAWN registry (not playersToTrack — that map isn't an
                -- array, so containsValue's #-scan never found it and the registry leaked). Matches
                -- the correct paths in deleteAllWeapons and syncScope.
                local containsObj, index = Utils.containsValue(weaponObjectiveSpawned, playerToTrack[wType])
                if containsObj then table.remove(weaponObjectiveSpawned, index) end
            end
            playerToTrack[wType] = false
        end
    else
        if type(playerToTrack[weaponType]) == "number" then
            DeleteObject(playerToTrack[weaponType])
            -- Same fix as the "all" path: clean the spawn registry, not playersToTrack.
            local containsObj, index = Utils.containsValue(weaponObjectiveSpawned, playerToTrack[weaponType])
            if containsObj then
                table.remove(weaponObjectiveSpawned, index)
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
    local _, heldHash = GetCurrentPedWeapon(cache.ped, 1)  -- weapon in hand → not slung

    Utils.mbtDebugger("checkWeaponProps ~ Starting iterating inventory weapons!")

    for _, weaponData in pairs(t) do
        if Utils.isWeapon(weaponData.name) and MBT.WeaponsInfo["Weapons"][weaponData.name]["type"] then
            local weaponType = MBT.WeaponsInfo["Weapons"][weaponData.name]?.type
            Utils.mbtDebugger("checkWeaponProps ~ weaponType ", weaponData.name, weaponType	)

            -- Skip the drawn weapon: it's in hand, not on the back. A full re-sync
            -- (e.g. a conceal reveal fires checkInventory) would otherwise spawn a
            -- back prop while the player is holding it.
            local drawn = heldHash and heldHash ~= `WEAPON_UNARMED` and joaat(weaponData.name) == heldHash
            if not drawn and not playerWeapons[weaponType] then
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
            -- Reserve the slot SYNCHRONOUSLY before the async CreateWeaponObject below.
            -- Two near-simultaneous syncSling for the same type (e.g. at restart the
            -- snapshot-poll updateInventory AND the server checkInventory both fire)
            -- would otherwise both pass the false/nil guard during the ~500ms create
            -- window, spawn two props, and orphan the first (it stays on the back
            -- after equip deletes the tracked one). The sentinel makes the loser skip.
            playersToTrack[data.playerSource][weaponType] = true
            local attachInfo = getAttachInfo({
                Job = playerJob,
                Type = weaponType
            })
            -- Low Ready guard (opaque hook, no-op without the module): if the LOCAL player has
            -- this type in chest carry, spawn it on the chest directly so a re-sling after a
            -- draw doesn't snap back→chest. Gated to the local player (the stance is local state).
            if targetPlayerId == PlayerId() and MBT.GetLowReadyOverride then
                attachInfo = MBT.GetLowReadyOverride(weaponType) or attachInfo
            end
            local boneIndex = GetPedBoneIndex(playerPed, attachInfo["Bone"])
            weaponData.weaponHash = joaat(weaponData.name)
            -- Streaming can exceed 1s under load (restart/asset spikes). pcall so a slow
            -- stream doesn't throw a red error and wedge the reserved slot — release it
            -- and skip this type; a later sync retries once streaming frees up.
            if not pcall(lib.requestWeaponAsset, weaponData.weaponHash, 5000, 31, 1) then
                Utils.mbtDebugger("syncSling ~ weapon asset failed to stream for ", weaponData.name)
                playersToTrack[data.playerSource][weaponType] = false
                goto continue
            end
            weaponData.weaponObj = CreateWeaponObject(weaponData.weaponHash, 50, playerCoords.x, playerCoords.y, playerCoords.z, true, 1.0, 0)
            RequestWeaponHighDetailModel(weaponData.weaponObj)
            RemoveWeaponAsset(weaponData.weaponHash)   -- object keeps its model; the asset was never freed (streaming-memory leak)

            local deadline = GetGameTimer() + 500
            while not DoesEntityExist(weaponData.weaponObj) and GetGameTimer() < deadline do
                Wait(10)
            end

            if not DoesEntityExist(weaponData.weaponObj) then
                Utils.mbtDebugger("syncSling ~ Weapon object failed to create for ", weaponData.name)
                playersToTrack[data.playerSource][weaponType] = false   -- release reservation
            else
                Utils.mbtDebugger("syncSling ~ Weapon object created! ", weaponData.name, playerPed, boneIndex, attachInfo["Pos"][pedSex]["x"], attachInfo["Pos"][pedSex]["y"], attachInfo["Pos"][pedSex]["z"])
                -- Hide it for the whole spawn window. CreateWeaponObject drops a physics-enabled
                -- weapon at the player's feet, and it stays loose there — falling, tumbling —
                -- through the component pass and the flashlight Wait below (up to ~550ms) until
                -- the attach snaps it to the bone. That tumble is what you see on a restart.
                -- The visibility tick can't reveal it early: the slot still holds the boolean
                -- sentinel, and that loop only touches number handles.
                SetEntityVisible(weaponData.weaponObj, false, 0)
                local hasObjFlashlight = applyAttachments(weaponData)
                -- Light the slung prop only when it ACTUALLY received a flashlight component
                -- AND the saved state says it was on. The component check prevents a weapon
                -- with stale/leaked flashlightState (but no torch) from glowing. NOTE: once a
                -- flashlight-component prop is lit, GTA couples it to the ped's global
                -- flashlight emitter, so it also lights when the player toggles the HELD
                -- weapon's torch — that is an engine limitation we accept (documented).
                local desiredFlashlight = MBT.EnableFlashlight and hasObjFlashlight
                    and weaponData.metadata and weaponData.metadata.flashlightState == true or false
                SetCreateWeaponObjectLightSource(weaponData.weaponObj, desiredFlashlight)
                -- CRITICAL: keep this Wait. The engine needs a tick to commit the light-source
                -- flag before AttachEntityToEntity, or the attach pass resets it and the slung
                -- prop never renders its flashlight.
                Wait(50)
                -- Force Pos/Rot to FLOATS: an integer rotation argument makes AttachEntityToEntity
                -- IGNORE the rotation (the NUI's React sliders send integers that reach here as
                -- Lua ints, leaving the prop stuck at its default pose). +0.0 guarantees a float.
                local P, R = attachInfo["Pos"][pedSex], attachInfo["Rot"][pedSex]
                AttachEntityToEntity(weaponData.weaponObj, playerPed, boneIndex,
                    P.x + 0.0, P.y + 0.0, P.z + 0.0, R.x + 0.0, R.y + 0.0, R.z + 0.0,
                    true, true, false, attachInfo["isPed"], attachInfo["RotOrder"], attachInfo["FixedRot"])
                SetEntityCompletelyDisableCollision(weaponData.weaponObj, false, true)
                -- In place at last — reveal it, matching whatever the owner is doing on both
                -- channels: hidden (noclip) and faded out (relog/multichar fade the ped to 0
                -- while we re-spawn its weapons, and the sync tick would flash them meanwhile).
                SetEntityVisible(weaponData.weaponObj, IsEntityVisible(playerPed), 0)
                Utils.syncPropAlpha(weaponData.weaponObj, GetEntityAlpha(playerPed))
                SetFlashLightKeepOnWhileMoving(true)
                Utils.mbtDebugger("syncSling ~ Apply attachments to weapon obj!")
                playersToTrack[data.playerSource][weaponType] = weaponData.weaponObj
                weaponObjectiveSpawned[#weaponObjectiveSpawned+1] = weaponData.weaponObj
            end
        end
        ::continue::
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

-- ── Slung prop visibility + alpha sync ────────────────────────────────────────
-- Keeps each tracked weapon prop in sync with its owner ped on BOTH channels a
-- third-party script can use to hide someone:
--   * visibility flag — admin noclip is the common case (SetEntityVisible)
--   * alpha           — multichar switch / relog fade the ped to 0 for ~2s while
--                       the right outfit is applied (SetEntityAlpha)
-- They're independent: a ped at alpha 0 still reports IsEntityVisible() == true,
-- so syncing visibility alone left the props hanging in mid-air during a relog.
-- Covers the local player and every tracked remote player. The vehicle path
-- deletes props rather than hiding them, so `type(v) == "number"` skips those.
CreateThread(function()
    while true do
        Wait(500)
        local mc = GetEntityCoords(cache.ped)
        for serverId, props in pairs(playersToTrack) do
            local ped
            if serverId == cache.serverId then
                ped = cache.ped
            else
                local plyr = GetPlayerFromServerId(serverId)
                ped = (plyr and plyr ~= -1) and GetPlayerPed(plyr) or nil
            end
            -- Distance-cull: a far ped's slung props aren't visible to us anyway, so skip the
            -- visibility sync (work scales with NEARBY peds, not every tracked one). Local always runs.
            if ped and ped ~= 0 and DoesEntityExist(ped)
               and (serverId == cache.serverId or #(mc - GetEntityCoords(ped)) < 80.0) then
                local pedVisible = IsEntityVisible(ped)
                local pedAlpha   = GetEntityAlpha(ped)
                for _, v in pairs(props) do
                    if type(v) == "number" and DoesEntityExist(v) then
                        if IsEntityVisible(v) ~= pedVisible then
                            SetEntityVisible(v, pedVisible, 0)
                        end
                        Utils.syncPropAlpha(v, pedAlpha)
                    end
                end
            end
        end
    end
end)

