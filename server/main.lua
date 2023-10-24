local utils = require 'utils'
local isESX = GetResourceState("es_extended") ~= "missing"
local isQB = GetResourceState("qb-core") ~= "missing"
local isOX = GetResourceState("ox_core") ~= "missing"
local FrameworkObj = {}
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
        utils.mbtDebugger("Receiving WeaponFlashlightState ", payload.FlashlightState)
        utils.dumpTable(weaponData)
        
        weaponData.metadata.flashlightState = payload.FlashlightState
        ox_inventory:SetMetadata(playerSource, weaponData.slot, weaponData.metadata)
        
        utils.mbtDebugger("State of flashlight for weapon "..weaponData.label.." with serial "..weaponData.metadata.serial.." in slot "..weaponData.slot.." changed to "..tostring(weaponData.metadata.flashlightState))
        utils.mbtDebugger("State of flashlight for weapon "..weaponData.label.." with serial "..weaponData.metadata.serial.." in slot "..weaponData.slot.." changed to "..tostring(weaponData.metadata.flashlightState))
    end
end)

lib.callback.register('mbt_malisling:getWeapoConf', function(source)
    utils.mbtDebugger("getWeapoConf ~  Source ", source, " requested callback!")
    -- utils.mbtDebugger(MBT.WeaponsInfo)
    while not isReady do Wait(250) end
    return MBT.WeaponsInfo
end)

local function loadWeaponsInfo()
    utils.mbtDebugger("Loading WeaponsInfo!")

    local weaponsFile = LoadResourceFile("ox_inventory", 'data/weapons.lua')
    local weaponsChunk = assert(load(weaponsFile, ('@@ox_inventory/data/weapons.lua')))
    local weaponsInfo = weaponsChunk()

    for k, v in pairs(utils.data('weapons')) do
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
        utils.mbtDebugger("appendMalisling ~ File has already modification")
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

                lib.showTextUI(']=] .. MBT.Labels["Holster_Help"] .. [=[', {icon = 'hand'})

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

                lib.hideTextUI()

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

if isESX then
    FrameworkObj = exports["es_extended"]:getSharedObject()

    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(playerId)
        playersToTrack[playerId] = {}
    end)

    getPlayerJob = function (s)
        s = tonumber(s)
        local xPlayer = FrameworkObj.GetPlayerFromId(s)
        if not xPlayer then return "" end
        return xPlayer.job.name
    end
    
    getPlayerSex = function (s)
        s = tonumber(s)
        local xPlayer = FrameworkObj.GetPlayerFromId(s)
        if not xPlayer then return "male" end
        return xPlayer.get("sex") == "m" and "male" or "female"
    end

elseif isQB then
    FrameworkObj = exports["qb-core"]:GetCoreObject()
    AddEventHandler('QBCore:Server:PlayerLoaded', function(qbPlayer)
        local source = qbPlayer.PlayerData.source
        playersToTrack[source] = {}
    end)

    getPlayerJob = function (s)
        s = tonumber(s)
        local xPlayer  = FrameworkObj.Functions.GetPlayer(s)
        if not xPlayer then return "male" end
        return xPlayer.PlayerData.job.name
    end
    
    getPlayerSex = function (s)
        s = tonumber(s)
        local xPlayer  = FrameworkObj.Functions.GetPlayer(s)
        if not xPlayer then return "male" end
        return xPlayer.PlayerData.charinfo.gender == 0 and "male" or "female"
    end
elseif isOX then
    local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
    local import = LoadResourceFile('ox_core', file)
    local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
    chunk()

    AddEventHandler('ox:playerLoaded', function(source, userid, charid)
        playersToTrack[source] = {}
    end)

    getPlayerJob = function (s)
        s = tonumber(s)
        local player = Ox.GetPlayer(s)  
        if not player then return "" end
        return player.getGroups() and player.getGroups()[1] or "unemployed"
    end

    getPlayerSex = function (s)
        s = tonumber(s)
        local player  = Ox.GetPlayer(s)
        if not player then return "male" end
        return player.get("gender")
    end
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
    utils.mbtDebugger("checkInventory ~ Checking inventory for source ", source)
    local inv = exports.ox_inventory:GetInventoryItems(source)
    -- utils.mbtDebugger(inv)
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
