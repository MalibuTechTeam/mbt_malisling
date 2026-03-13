lib.versionCheck('MalibuTechTeam/mbt_malisling')

local Utils = loadModule('modules.Utils.server')
local isReady = false
local ox_inventory = exports["ox_inventory"]
playersToTrack = {}

if not lib.checkDependency('ox_inventory', '2.30.0') then warn("The script has not been tested with this versions of ox_inventory!") end

AddStateBagChangeHandler('WeaponFlashlightState', nil, function(bagName, key, value)
    if not value then return end

    local netId = bagName:gsub('player:', '')
    local playerSource = tonumber(netId)

    for slot, payload in pairs(value) do
        local weaponData = ox_inventory:GetSlot(playerSource, slot)

        if not weaponData then return end
        Utils.mbtDebugger("Receiving WeaponFlashlightState ", payload.FlashlightState)
        Utils.dumpTable(weaponData)

        weaponData.metadata.flashlightState = payload.FlashlightState
        ox_inventory:SetMetadata(playerSource, weaponData.slot, weaponData.metadata)

        Utils.mbtDebugger("State of flashlight for weapon "..weaponData.label.." with serial "..weaponData.metadata.serial.." in slot "..weaponData.slot.." changed to "..tostring(weaponData.metadata.flashlightState))
        Utils.mbtDebugger("State of flashlight for weapon "..weaponData.label.." with serial "..weaponData.metadata.serial.." in slot "..weaponData.slot.." changed to "..tostring(weaponData.metadata.flashlightState))
    end
end)

lib.callback.register('mbt_malisling:getWeapoConf', function(source)
    Utils.mbtDebugger("getWeapoConf ~  Source ", source, " requested callback!")
    while not isReady do Wait(250) end
    return MBT.WeaponsInfo
end)

local function loadWeaponsInfo()
    Utils.mbtDebugger("Loading WeaponsInfo!")

    local weaponsFile = LoadResourceFile("ox_inventory", 'data/weapons.lua')
    local weaponsChunk = assert(load(weaponsFile, ('@@ox_inventory/data/weapons.lua')))
    local weaponsInfo = weaponsChunk()

    for k, v in pairs(Utils.data('weapons')) do
        if not weaponsInfo["Weapons"][k] then
            warn("Weapon not found in weapons data file: " .. k)
        else
            weaponsInfo["Weapons"][k]["type"] = v.type
        end
    end

    MBT.WeaponsInfo = weaponsInfo
    local b = MBT.EnableSling and true or false
    SetConvarReplicated("malisling:enable_sling", tostring(b))
    TriggerClientEvent("mbt_malisling:sendWeaponsData", -1, MBT.WeaponsInfo)
    isReady = true
end

---@param s number
local function dropPlayer(s)
    TriggerClientEvent("mbt_malisling:syncDeletion", -1,
        { playerSource = s, weaponType = "all", calledBy = "dropPlayer" })
    TriggerClientEvent("mbt_malisling:syncPlayerRemoval", -1, { playerSource = s })
    playersToTrack[s] = nil
    removePlayerFromScopes(s)
end

---Coarse way to manipulate the equip/disarm of ox_inventory, not optimal, ugly as hell but it works
local function appendMalisling()
    local st = LoadResourceFile('ox_inventory', "modules/weapon/client.lua")

    local substring = "\nreturn Weapon"
    local pattern = "[^\n]*" .. substring .. "[^\n]*\n"
    local st1 = st:gsub(pattern, "")

    local i, e = string.find(st1, "RegisterKeyMapping")

    if i then
        Utils.mbtDebugger("appendMalisling ~ File has already modification")
        return
    end

    local rs = [=[
function Weapon.Equip(item, data)
    local playerPed = cache.ped
    local coords = GetEntityCoords(playerPed, true)
    local sleep

	if client.weaponanims then
		if cache.vehicle and vehicleIsCycle(cache.vehicle) then
			goto skipAnim
		end

		local anim = data.anim or anims[GetWeapontypeGroup(data.hash)]

		-- if anim == anims[`GROUP_PISTOL`] and not client.hasGroup(shared.police) then
		-- 	anim = nil
		-- end

        if anim == anims[`GROUP_PISTOL`] or data.type == "side" then
            if GetConvar('malisling:enable_sling', 'false') == 'true' then

                local watingForHolster = nil

                SendNUIMessage({action = "showHolster", data = {
                    weaponLabel = data.model or "WEAPON",
                    position    = "]=] .. (MBT.UI and MBT.UI.Position or "bottom-center") .. [=[",
                    confirm     = {label = "]=] .. MBT.HolsterControls["Confirm"]["Label"] .. [=[", display = "RMB"},
                    cancel      = {label = "]=] .. MBT.HolsterControls["Cancel"]["Label"]  .. [=[", display = "BACKSPACE"}
                }})

                lib.requestAnimDict("reaction@intimidation@cop@unarmed")

                while not IsEntityPlayingAnim(playerPed, "reaction@intimidation@cop@unarmed", "intro", 3) do
                    TaskPlayAnim(playerPed, "reaction@intimidation@cop@unarmed", "intro", 8.0, 2.0, -1, 50, 2.0, 0, 0, 0 )
                    Citizen.Wait(10)
                end

                RegisterCommand("confirmHolster", function()
                    watingForHolster = true
                end, false)

                RegisterCommand("cancelHolster", function()
                    watingForHolster = false
                end, false)

                while watingForHolster == nil do
                    Citizen.Wait(100)
                end

                SendNUIMessage({action = "hideHolster"})

                ClearPedTasks(playerPed)

                RegisterCommand("confirmHolster", function() end, false)

                RegisterCommand("cancelHolster", function() end, false)

                if not watingForHolster then return end
            end
        end

		sleep = anim and anim[3] or 1200
        coords = GetEntityCoords(playerPed, true)

		Utils.PlayAnimAdvanced(sleep, anim and anim[1] or 'reaction@intimidation@1h', anim and anim[2] or 'intro', coords.x, coords.y, coords.z, 0, 0, GetEntityHeading(playerPed), 8.0, 3.0, sleep*2, 50, 0.1)
	end

	::skipAnim::

    item.hash = data.hash
	item.ammo = data.ammoname
	item.melee = GetWeaponDamageType(data.hash) == 2 and 0
	item.timer = 0
	item.throwable = data.throwable
	item.group = GetWeapontypeGroup(item.hash)

	GiveWeaponToPed(playerPed, data.hash, 0, false, true)

	if item.metadata.tint then SetPedWeaponTintIndex(playerPed, data.hash, item.metadata.tint) end

	if item.metadata.components then
		for i = 1, #item.metadata.components do
			local components = Items[item.metadata.components[i]].client.component
			for v=1, #components do
				local component = components[v]
				if DoesWeaponTakeWeaponComponent(data.hash, component) then
					if not HasPedGotWeaponComponent(playerPed, data.hash, component) then
						GiveWeaponComponentToPed(playerPed, data.hash, component)
					end
				end
			end
		end
	end

	if item.metadata.specialAmmo then
		local clipComponentKey = ('%s_CLIP'):format(data.model:gsub('WEAPON_', 'COMPONENT_'))
		local specialClip = ('%s_%s'):format(clipComponentKey, item.metadata.specialAmmo:upper())

		if DoesWeaponTakeWeaponComponent(data.hash, specialClip) then
			GiveWeaponComponentToPed(playerPed, data.hash, specialClip)
		end
	end

	local ammo = item.metadata.ammo or item.throwable and 1 or 0

    SetCurrentPedWeapon(playerPed, data.hash, true)
	SetPedCurrentWeaponVisible(playerPed, true, false, false, false)
	SetWeaponsNoAutoswap(true)
	SetPedAmmo(playerPed, data.hash, ammo)
	SetTimeout(0, function() RefillAmmoInstantly(playerPed) end)

	if item.group == `GROUP_PETROLCAN` or item.group == `GROUP_FIREEXTINGUISHER` then
		item.metadata.ammo = item.metadata.durability
		SetPedInfiniteAmmo(playerPed, true, data.hash)
	end

	TriggerEvent('ox_inventory:currentWeapon', item)
	Utils.ItemNotify({ item, 'ui_equipped' })

	return item, sleep
end

function Weapon.Disarm(currentWeapon, noAnim)
    if currentWeapon?.timer then
		currentWeapon.timer = nil

		if source == '' then
			TriggerServerEvent('ox_inventory:updateWeapon')
		end

		SetPedAmmo(cache.ped, currentWeapon.hash, 0)

		if client.weaponanims and not noAnim then
			if cache.vehicle and vehicleIsCycle(cache.vehicle) then
				goto skipAnim
			end

			ClearPedSecondaryTask(cache.ped)

			local item = Items[currentWeapon.name]
			local coords = GetEntityCoords(cache.ped, true)
			local anim = item.anim or anims[GetWeapontypeGroup(currentWeapon.hash)]

			-- if anim == anims[`GROUP_PISTOL`] and not client.hasGroup(shared.police) then
			--	anim = nil
			-- end

			local sleep = anim and anim[6] or 1400

			Utils.PlayAnimAdvanced(sleep, anim and anim[4] or 'reaction@intimidation@1h', anim and anim[5] or 'outro', coords.x, coords.y, coords.z, 0, 0, GetEntityHeading(cache.ped), 8.0, 3.0, sleep, 50, 0)
		end

		::skipAnim::

		Utils.ItemNotify({ currentWeapon, 'ui_holstered' })
		TriggerEvent('ox_inventory:currentWeapon')
	end

	Utils.WeaponWheel()
	RemoveAllPedWeapons(cache.ped, true)
end

RegisterNetEvent("mbt_malisling:sendAnim")
AddEventHandler("mbt_malisling:sendAnim", function (data)
    local wInfo = data.WeaponData["Weapons"]
	local Items = require 'modules.items.shared'

    for k, v in pairs(wInfo) do
        local itemName = k
        local itemType = wInfo[itemName]["type"]

		if not itemType then
			local s = "The weapon "..itemName.." has not been configured in data/weapons.lua of mbt_malisling, therefore it will not be attached to player!"
			warn(s)
		else
			if data.HolsterData[itemType]["HolsterAnim"] then
				local animInfo = data.HolsterData[itemType]["HolsterAnim"]
				local animTable = {animInfo.dict, animInfo.animIn, animInfo.sleep, animInfo.dict, animInfo.animOut, animInfo.sleepOut}

				if Items[itemName] then
					Items[itemName]["type"] = itemType
					Items[itemName]["anim"] = animTable
				end
			end
		end
    end
end)

RegisterKeyMapping('confirmHolster', "]=] ..
    MBT.HolsterControls["Confirm"]["Label"] ..
    [=[", ']=] .. MBT.HolsterControls["Confirm"]["Input"] ..
    [=[', "]=] .. MBT.HolsterControls["Confirm"]["Key"] .. [=[")
RegisterKeyMapping('cancelHolster', "]=] ..
    MBT.HolsterControls["Cancel"]["Label"] ..
    [=[", ']=] .. MBT.HolsterControls["Cancel"]["Input"] .. [=[', "]=] ..
    MBT.HolsterControls["Cancel"]["Key"] .. [=[")

return Weapon
]=]

    st1 = st1 .. "\n" .. rs

    local ipfile = SaveResourceFile("ox_inventory", "modules/weapon/client.lua", st1, -1)
    warn("Restart your server to allow the Sling feature to work properly!")
end

-- Check if the weaponanims convar is disabled
if GetConvarInt('inventory:weaponanims', 1) == 0 then
    warn(
    "You have enabled the sling feature, but you have disabled the weapons animation convar in ox_inventory. This will cause issues with animations and the sling feature. Please set inventory:weaponanims to 1")
end

appendMalisling()

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadWeaponsInfo()
end)

AddEventHandler("playerDropped", function()
    if not source then return end
    dropPlayer(source)
end)

RegisterNetEvent("mbt_malisling:getPlayersInPlayerScope")
AddEventHandler("mbt_malisling:getPlayersInPlayerScope", function(data)
    if not players then scopes[tostring(source)] = {} end
    for i = 1, #data do
        addPlayerToPlayerScope(source, data[i])
    end
end)

RegisterNetEvent("mbt_malisling:checkInventory")
AddEventHandler("mbt_malisling:checkInventory", function()
    Utils.mbtDebugger("checkInventory ~ Checking inventory for source ", source)
    local inv = exports.ox_inventory:GetInventoryItems(source)
    TriggerClientEvent("mbt_malisling:checkWeaponProps", source, inv)
end)

RegisterNetEvent("mbt_malisling:syncSling")
AddEventHandler("mbt_malisling:syncSling", function(data)
    local _source = source
    if not playersToTrack[_source] then playersToTrack[_source] = {} end
    for k, v in pairs(data.playerWeapons) do playersToTrack[_source][k] = v end

    Wait(100)

    TriggerScopeEvent({
        event = "mbt_malisling:syncSling",
        scopeOwner = _source,
        selfTrigger = true,
        payload = {
            type = "add",
            playerSource = _source,
            playerJob = getPlayerJob(_source),
            pedSex = getPlayerSex(_source),
            calledBy = "mbt_malisling:syncSling ~ 162",
            playerWeapons = playersToTrack[_source]
        }
    })
end)

RegisterNetEvent("mbt_malisling:syncDeletion")
AddEventHandler("mbt_malisling:syncDeletion", function(weaponType)
    local _source = source
    if playersToTrack[_source] == nil then return end
    playersToTrack[_source][weaponType] = false

    TriggerScopeEvent({
        event = "mbt_malisling:syncDeletion",
        scopeOwner = _source,
        selfTrigger = true,
        payload = {
            playerSource = _source,
            calledBy = "mbt_malisling:syncDeletion",
            weaponType = weaponType
        }
    })
end)

-- Scopes --

local functQueue, oldScop = {}, {}
scopes = {}

---@param player number | string
---@param playerToAdd number | string
function addPlayerToPlayerScope(player, playerToAdd)
    local player = tostring(player)
    local playerSource = tonumber(player)
    local playerToAdd = tonumber(playerToAdd)
    local playerToAddSource = tostring(playerToAdd)

    local playerScope = scopes[player]
    if Utils.containsValue(playerScope, playerToAdd) then return end
    playerScope[#playerScope+1] = playerToAdd

    if scopes[playerToAddSource] then
        local isIn = Utils.containsValue(scopes[playerToAddSource], playerSource)
        if not isIn then
            scopes[playerToAddSource][#scopes[playerToAddSource]+1] = playerSource
        end
    end

    Utils.mbtDebugger("addPlayerToPlayerScope ~ Added players!")
end

---@param player string
---@param playerToRemove string
local function removePlayerFromPlayerScope(player, playerToRemove)
    local playerSource = tonumber(player)
    local playerToRemoveSource = tonumber(playerToRemove)

    if scopes[player] then
        TriggerClientEvent("mbt_malisling:stopWaitingForPlayer", playerSource, playerToRemoveSource)
    end

    if scopes[player] then
        local isContaining, index = Utils.containsValue(scopes[player], playerToRemoveSource)
        if isContaining then
            table.remove(scopes[player], index)
        end
    end

    if scopes[playerToRemove] then
        local isContaining, index = Utils.containsValue(scopes[playerToRemove], playerSource)
        if isContaining then
            table.remove(scopes[playerToRemove], index)
        end
    end
end

function removePlayerFromScopes(s)
    for k,v in pairs(scopes) do
        for i=1, #v do
            if v[i] == s then
                table.remove(v, i)
            end
        end
        if k == tostring(s) then scopes[k] = nil end
    end
end

---@param data table
---@return promise
local function triggerCl(data)
    local event = data.event
    if not data.event then warn("No event has passed in triggerCl function") return end
    local target = data.target
    if not data.target then warn("No target has passed in triggerCl function") return end
    local payload = data.payload
    if not data.payload then warn("No payload has passed in triggerCl function") return end

    local p = promise.new()

    TriggerClientEvent(data.event, data.target, data.payload)

    p:resolve("Done")
    return p
end

---Trigger event to all players inside scope
---@param data table
---@return promise
function TriggerScopeEvent(data)
    local event = data.event
    local scopeOwner = tostring(data.scopeOwner)
    if not scopeOwner then return end
    local selfTrigger = data.selfTrigger
    local payload = data.payload
    local cb = data.cb
    local targets = scopes[scopeOwner]

    if not targets then return end

    local p = promise.new()

    Utils.mbtDebugger("^2TriggerScopeEvent ~ targets of ", scopeOwner)
    for i=1, #targets do
        local target = tonumber(targets[i])
        TriggerClientEvent(event, target, payload)
    end

    if selfTrigger then
        scopeOwner = tonumber(scopeOwner)
        TriggerClientEvent(event, scopeOwner, payload)
    end

    if cb then cb() end

    p:resolve("Done")
    Utils.mbtDebugger("TriggerScopeEvent ~ Finished!, state of promise ", p.state, p.value)

    return p
end

AddEventHandler("playerEnteredScope", function(data)
    local playerEntering, player = data["player"], data["for"]
    local playerEnteringSource, playerSource = tonumber(playerEntering), tonumber(player)
    local playerEnteringCoords = GetEntityCoords(GetPlayerPed(playerEnteringSource))
    local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
    if not playerEnteringCoords.x == 0.0 and playerEnteringCoords.y == 0.0 then return end
    if not playerCoords.x == 0.0 and playerCoords.y == 0.0 then return end

    Utils.mbtDebugger(("^2%s is entering %s's scope"):format(playerEntering, player))
    if not playerEntering then return end
    Utils.mbtDebugger("playerEnteredScope check 2")
    if not player then return end
    Utils.mbtDebugger("playerEnteredScope check 3")

    if not playersToTrack[playerSource] then return end

    Utils.mbtDebugger("playerEnteredScope ~ Check passed!")

    if not scopes[player] then
        Utils.mbtDebugger("playerEnteredScope ~ Initialized scope for player ", player)
        scopes[player] = {}
    end

    addPlayerToPlayerScope(player, playerEntering)
end)

AddEventHandler("playerLeftScope", function(data)
    local playerLeaving, player = data["player"], data["for"]
    Utils.mbtDebugger(("^2%s is leaving %s's scope"):format(playerLeaving, player))
    removePlayerFromPlayerScope(playerLeaving, player);
end)

Citizen.CreateThread(function()
    Utils.mbtDebugger("Queuing Thread ~ Started!")
    while true do

        local diffs = Utils.getDifferences(oldScop, scopes)

        for source, values in pairs(diffs) do
            for i=1, #values do
                Utils.mbtDebugger("Queuing Thread ~ Key: ", source, "Type: ", values[i].type, "Value: ", values[i].value)

                functQueue[#functQueue+1] = {
                    funct = triggerCl,
                    args = {
                        event = "mbt_malisling:syncScope",
                        target = tonumber(values[i].value),
                        payload = {
                            tType = values[i].type == "Removed" and "del" or "add",
                            playerSource = tonumber(source),
                            playerJob = getPlayerJob(source),
                            pedSex = getPlayerSex(source),
                            playerWeapons = values[i].type == "Added" and playersToTrack[tonumber(source)] or nil
                        }
                    }
                }
            end
        end

        oldScop = Utils.tableDeepCopy(scopes)
        Citizen.Wait(100)
    end
end)

Citizen.CreateThread(function()
    local isBusy = false

    while true do
        Wait(200)
        if #functQueue > 0 then
            if isBusy then Utils.mbtDebugger("Execute queue thread ~ Busy!!!") end
            if not isBusy and functQueue[1] then
                isBusy = true
                local qElement = functQueue[1]

                Utils.mbtDebugger("Execute queue thread ~ Executing function ", qElement.args.event, " with target ", qElement.args.target, " and payload ", json.encode(qElement.args.payload))
                local ps = Citizen.Await(qElement.funct(qElement.args))
                table.remove(functQueue, 1)
                Utils.mbtDebugger("Execute queue thread ~ Resolved process event ", qElement.args.event, " Promise: ", ps)
                isBusy = false
            end
        end
    end
end)
