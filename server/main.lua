local isESX = GetResourceState("es_extended") ~= "missing"
local isQB = GetResourceState("qb-core") ~= "missing"
local isOX = GetResourceState("ox_core") ~= "missing"
local isOXInventory = GetResourceState("ox_inventory") ~= "missing"
local FrameworkObj = {}
local isReady = false
playersToTrack = {}

if GetResourceState("ox_inventory") ~= "started" then
    print(
    "You are not using ox_inventory, this resource will not work without it. Please install ox_inventory and restart the resource.")
    return
end

local ox_inventory = exports["ox_inventory"]

lib.callback.register('mbt_malisling:getWeapoConf', function(source)
    local _source = source
    print("Source ", _source, " requested callback!")
    print(json.encode(Config.WeaponsInfo), { indent = true })
    while not isReady do Wait(250) end
    return Config.WeaponsInfo
end)


AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print("RESTARTED ", resource)
    loadWeaponsInfo()
end)

if isESX then
    FrameworkObj = exports["es_extended"]:getSharedObject()

    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
        playersToTrack[playerId] = {}
        -- TriggerClientEvent("mbt_malisling:loadData", playerId, Config.WeaponsInfo)
    end)
elseif isQB then
    FrameworkObj = exports["qb-core"]:GetCoreObject()
    AddEventHandler('QBCore:Server:PlayerLoaded', function(qbPlayer)
        local source = qbPlayer.PlayerData.source
        -- TriggerClientEvent("mbt_malisling:loadData", source, Config.WeaponsInfo)
    end)
elseif isOX then
    local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
    local import = LoadResourceFile('ox_core', file)
    local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
    chunk()

    AddEventHandler('ox:playerLoaded', function(source, userid, charid)
        -- TriggerClientEvent("mbt_malisling:loadData", source, Config.WeaponsInfo)
    end)
end

if Config.EnableSling and GetConvarInt('inventory:weaponmismatch', 1) == 1 then
    warn(
    "You have enabled the sling feature, but you have not disabled the weapon mismatch check in ox_inventory. This will cause issues with the sling feature. Please set inventory:weaponmismatch to 0")
end

AddEventHandler("playerDropped", function() --TODO: Check if this works
    local _source = source
    if not _source then return end
    dropPlayer(_source)
end)

RegisterServerEvent("mbt_malisling:getPlayersInPlayerScope")
AddEventHandler("mbt_malisling:getPlayersInPlayerScope", function(data)
    local _source = source
    -- local players = getPlayersInPlayerScope(_source)

    if not players then scopes[tostring(_source)] = {}; end

    -- print("getPlayersInPlayerScope check")

    for i = 1, #data do
        addPlayerToPlayerScope(_source, data[i])
    end
end)

RegisterServerEvent("mbt_malisling:checkInventory")
AddEventHandler("mbt_malisling:checkInventory", function()
    local _source = source
    local inv = exports.ox_inventory:GetInventoryItems(_source)
    print("mbt_malisling:checkInventory ~  source ", _source)
    print(json.encode(inv), { indent = true })
    TriggerClientEvent("mbt_malisling:checkWeaponProps", _source, inv)
end)

RegisterServerEvent("mbt_malisling:syncSling")
AddEventHandler("mbt_malisling:syncSling", function(data)
    local _source = source

    data.tPed = _source
    -- print("Syncing sling for ", _source)

    -- dumpTable(data)

    if not playersToTrack[_source] then playersToTrack[_source] = {} end

    for k, v in pairs(data.playerWeapons) do playersToTrack[_source][k] = v end


    -- print("Sending weapon info about id ", _source)

    Wait(400)

    -- TriggerScopeEvent("mbt_malisling:syncSling", _source, true, nil, { playerSource = _source, playerWeapons = playersToTrack[_source] })

    TriggerScopeEvent({
        event = "mbt_malisling:syncSling",
        scopeOwner = _source,
        selfTrigger = true,
        payload = {
            type = "add",
            playerSource = _source,
            calledBy = "mbt_malisling:syncSling ~ 162",
            playerWeapons = playersToTrack[_source]
        }
    })

    -- functQueue[#functQueue+1] = {funct = TriggerScopeEvent, args = {
    --     event = "mbt_malisling:syncSling",
    --     scopeOwner = _source,
    --     selfTrigger = true,
    --     payload = {
    --         type = "add",
    --         playerSource = _source,
    --         playerWeapons = playersToTrack[_source]
    --     }
    -- }}
end)

RegisterServerEvent("mbt_malisling:syncDeletion")
AddEventHandler("mbt_malisling:syncDeletion", function(weaponType)
    local _source = source
    -- print("weaponType ", weaponType)
    -- print("playersToTrack[_source] ", playersToTrack[_source])
    if playersToTrack[_source] == nil then return end
    playersToTrack[_source][weaponType] = false
    -- TriggerScopeEvent("mbt_malisling:syncDeletion", _source, true, nil, { playerSource = _source, weaponType = weaponType })
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
    -- functQueue[#functQueue+1] = {funct = TriggerScopeEvent, args = {
    --     event = "mbt_malisling:syncDeletion",
    --     scopeOwner = _source,
    --     selfTrigger = true,
    --     payload = {
    --         playerSource = _source,
    --         weaponType = weaponType
    --     }
    -- }}
end)

function dropPlayer(s)
    --TriggerScopeEvent("mbt_malisling:syncDeletion", s, false, nil, { playerSource = s, weaponType = "all" })
    TriggerClientEvent("mbt_malisling:syncDeletion", -1,
        { playerSource = s, weaponType = "all", calledBy = "dropPlayer" })
    TriggerClientEvent("mbt_malisling:syncPlayerRemoval", -1, { playerSource = s })
    playersToTrack[s] = nil
end

function loadWeaponsInfo()
    print("loading WeaponsInfo!")

    local weaponsFile = LoadResourceFile("ox_inventory", 'data/weapons.lua')
    local weaponsChunk = assert(load(weaponsFile, ('@@ox_inventory/data/weapons.lua')))
    local weaponsInfo = weaponsChunk()

    for k, v in pairs(data('weapons')) do
        if not weaponsInfo["Weapons"][k] then
            warn("Weapon not found in weapons data file: " .. k)
        else
            weaponsInfo["Weapons"][k]["type"] = v.type
        end
    end

    Config.WeaponsInfo = weaponsInfo
    local b = Config.EnableSling and true or false

    -- print("Config.EnableSling: ", b, type(b))

    SetConvarReplicated("malisling:enable_sling", tostring(b))
    isReady = true
end

function appendMalisling()
    local st = LoadResourceFile('ox_inventory', "modules/weapon/client.lua")

    local substring = "return Weapon"
    local pattern = "%a*"..substring.."%a*"
    local st1 = st:gsub(pattern, "")

    -- print("type of st ", type(st))
    -- print(st)
    -- print("-------------------------------------")
    -- print(st1)

    local i, e = string.find(st1, "RegisterKeyMapping")

    if i then
        print("File already modified")
        return
    end

    local rs = [=[

Weapon.Equip = function(item, data)
    local playerPed = cache.ped

	if client.weaponanims then
		if cache.vehicle and vehicleIsCycle(cache.vehicle) then
			goto skipAnim
		end

		local coords = GetEntityCoords(playerPed, true)
		local anim = data.anim or anims[GetWeapontypeGroup(data.hash)]


		-- if anim == anims[`GROUP_PISTOL`] and not client.hasGroup(shared.police) then
        --     print("Pistol group AND not police")
		-- 	anim = nil
		-- end

        if anim == anims[`GROUP_PISTOL`] or data.type == "side" then


            if GetConvar('malisling:enable_sling', 'false') == 'true' then

                local watingForHolster = nil
                local holsterConfirmed = false

                lib.showTextUI(']=] .. Config.Labels["Holster_Help"] .. [=[', {icon = 'hand'})

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

		local sleep = anim and anim[3] or 1200

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

	SetPedAmmo(playerPed, data.hash, ammo)
	SetCurrentPedWeapon(playerPed, data.hash, true)
	SetPedCurrentWeaponVisible(playerPed, true, false, false, false)
	SetWeaponsNoAutoswap(true)
	SetTimeout(0, function() RefillAmmoInstantly(playerPed) end)

	if item.group == `GROUP_PETROLCAN` or item.group == `GROUP_FIREEXTINGUISHER` then
		item.metadata.ammo = item.metadata.durability
		SetPedInfiniteAmmo(playerPed, true, data.hash)
	end

	TriggerEvent('ox_inventory:currentWeapon', item)
	Utils.ItemNotify({ item, 'ui_equipped' })

	return item
end

function Weapon.Disarm(currentWeapon, noAnim)
	if not currentWeapon?.timer then return end

	if source == '' then
		TriggerServerEvent('ox_inventory:updateWeapon')
	end

	if currentWeapon then
		currentWeapon.timer = nil
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
				-- anim = nil
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

RegisterNetEvent("ox_inv:sendAnim")
AddEventHandler("ox_inv:sendAnim", function (data)
    local wInfo = data.WeaponData["Weapons"]
	local Items = require 'modules.items.shared' --[[@as { [string]: OxClientItem }]]
	
    for k, v in pairs(wInfo) do
        local itemName = k
        local itemType = wInfo[itemName]["type"]
		
		if itemType == nil then
			print(itemName, " type is nil, no animation for it")
		end

		if itemType then
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
    Config.HolsterControls["Confirm"]["Label"] ..
    [=[", ']=] .. Config.HolsterControls["Confirm"]["Input"] ..
    [=[', "]=] .. Config.HolsterControls["Confirm"]["Key"] .. [=[")
RegisterKeyMapping('cancelHolster', "]=] ..
    Config.HolsterControls["Cancel"]["Label"] ..
    [=[", ']=] .. Config.HolsterControls["Cancel"]["Input"] .. [=[', "]=] ..
    Config.HolsterControls["Cancel"]["Key"] .. [=[")

return Weapon
]=]


    st1 = st1 .. "\n" .. rs

    local ipfile = SaveResourceFile("ox_inventory", "modules/weapon/client.lua", st1, -1)
end

appendMalisling()



RegisterCommand("setC", function(source, args, raw)
    SetConvarReplicated("malisling:enable_sling", true)
end)

RegisterCommand("getC", function(source, args, raw)
    print(GetConvar('malisling:enable_sling', 'false'))
    if GetConvar('malisling:enable_sling', 'false') == 'true' then

    end
end)

RegisterCommand("ptts", function(source, args, raw)
    dumpTable(playersToTrack)
end)

RegisterCommand("consv", function(source, args, raw)
    dumpTable(Config.WeaponsInfo["Weapons"])
end)
