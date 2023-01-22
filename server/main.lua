local isESX = GetResourceState("es_extended") ~= "missing"
local isQB = GetResourceState("qb-core") ~= "missing"
local isOX = GetResourceState("ox_core") ~= "missing"
local isOXInventory = GetResourceState("ox_inventory") ~= "missing"
local isQBInventory = GetResourceState("ox_inventory") ~= "missing"
local isOXLib = GetResourceState("ox_lib") ~= "missing"
local weaponsData = json.decode(LoadResourceFile('mbt_malisling', 'weapons.json'))
local FrameworkObj = {}

if isESX and isQB then
	print("[ERROR] You are using both ESX and QB-Core, please remove one of them.")
elseif isESX then
	FrameworkObj = exports["es_extended"]:getSharedObject()
elseif isQB then
	FrameworkObj = exports["qb-core"]:GetCoreObject()
elseif isOX then
	local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
    local import = LoadResourceFile('ox_core', file)
    local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
    chunk()
end

if isOXInventory then  
    ox_inventory = exports["ox_inventory"]
end


RegisterServerEvent("mbt_malisling:dropWeapon")
AddEventHandler("mbt_malisling:dropWeapon", function(data)
    local _source = source
    dropCurrentWeapon(source, data)
end)

RegisterServerEvent("mbt_malisling:getData")
AddEventHandler("mbt_malisling:getData", function()
    local _source = source
    TriggerClientEvent("mbt_malisling:loadData", _source, weaponsData)
    loadData(weaponsData)
end)

RegisterServerEvent("mbt_malisling:checkInventory")
AddEventHandler("mbt_malisling:checkInventory", function(ignoreAttach)
    local _source = source
    TriggerClientEvent("mbt_malisling:checkWeaponProps", _source, ox_inventory:Inventory(_source).items, ignoreAttach)
end)


function dropWeaponHand(data)
    -- local r = math.random(1,10000)
    local r = ('DeadDrop %s000000000'):format(os.time(os.date('*t')))

    -- print("REMOVE! ", data.source, data.count, data.metadata.serial, data.slot)
    local slotItem = exports.ox_inventory:GetSlot(data.Source, data.Slot)

    if slotItem then
        exports.ox_inventory:RemoveItem(data.Source, slotItem.name, 1, nil, slotItem.slot)
    
        exports.ox_inventory:CustomDrop(r, {
            {slotItem.name, slotItem.count, slotItem.metadata}
        }, data.PlayerCoords, nil, nil, nil, Config.Weapons[slotItem.name].prop)
    end
    
end

function dropCurrentWeapon(source, slot)
    local _source = source

    -- local weaponData = exports.ox_inventory:GetCurrentWeapon(_source)
    -- print(json.encode(weaponData), {indent=true})

    if slot then
        local playerPed = GetPlayerPed(_source)
        local coords = GetEntityCoords(playerPed)

        local data = {
            Source = _source,
            PlayerCoords = coords,
            Slot = slot
        }

        dropWeaponHand(data)
    end
end

function appendMalisling()
    local st = LoadResourceFile('ox_inventory', "modules/weapon/client.lua")

    local i,e = string.find(st, "RegisterKeyMapping")

    print(i)

    if i then print("File already modified") return end

    local rs = [=[
        
Weapon.Equip = function(item, data)
    local playerPed, sleep = cache.ped, 200
    
    if client.weaponanims then
        if cache.vehicle and vehicleIsCycle(cache.vehicle) then
            goto skipAnim
        end

        local coords = GetEntityCoords(playerPed, true)
        local anim = data.anim or anims[GetWeapontypeGroup(data.hash)]
        local isPistolGroup = GetWeapontypeGroup(data.hash) == `GROUP_PISTOL`
        
        if anim == anims[`GROUP_PISTOL`] or data.type == "side" then
            
            local watingForHolster = nil
            local holsterConfirmed = false
            
            lib.showTextUI(']=]..Config.Labels["Holster_Help"]..[=[', {icon = 'hand'})

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

        sleep = anim and anim[3] or 1200
        
        coords = GetEntityCoords(playerPed, true)
        Utils.PlayAnimAdvanced(sleep*2, anim and anim[1] or 'reaction@intimidation@1h', anim and anim[2] or 'intro', coords.x, coords.y, coords.z, 0, 0, GetEntityHeading(playerPed), 8.0, 3.0, -1, 50, 0.1)
        Wait(sleep)
    end
    
    ::skipAnim::
    
    SetPedAmmo(playerPed, data.hash, 0)
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
    
    item.hash = data.hash
    item.ammo = data.ammoname
    item.melee = (not item.throwable and not data.ammoname) and 0
    item.timer = 0

    if data.throwable then item.throwable = true end

    SetCurrentPedWeapon(playerPed, data.hash, true)
    SetPedCurrentWeaponVisible(playerPed, true, false, false, false)
    AddAmmoToPed(playerPed, data.hash, item.metadata.ammo or 100)
    SetWeaponsNoAutoswap(true)

    if data.hash == `WEAPON_PETROLCAN` or data.hash == `WEAPON_HAZARDCAN` or data.hash == `WEAPON_FERTILIZERCAN` or data.hash == `WEAPON_FIREEXTINGUISHER` then
        item.metadata.ammo = item.metadata.durability
        SetPedInfiniteAmmo(playerPed, true, data.hash)
    end

    TriggerEvent('ox_inventory:currentWeapon', item)
    Utils.ItemNotify({item.metadata.label or item.label, item.metadata.image or item.name, 'ui_equipped'})
    Wait(sleep)
    RefillAmmoInstantly(playerPed)

    return item
end
    
Weapon.Disarm = function(currentWeapon, noAnim)
    if source == '' then
        TriggerServerEvent('ox_inventory:updateWeapon')
    end

    if currentWeapon then
        SetPedAmmo(cache.ped, currentWeapon.hash, 0)

        if client.weaponanims and not noAnim then
            if cache.vehicle and vehicleIsCycle(cache.vehicle) then
                goto skipAnim
            end

            ClearPedSecondaryTask(cache.ped)

            local item = Items[currentWeapon.name]
            local coords = GetEntityCoords(cache.ped, true)
            local anim = item.anim or anims[GetWeapontypeGroup(currentWeapon.hash)]
            local sleep = anim and anim[6] or 1400

            Utils.PlayAnimAdvanced(sleep*2, anim and anim[4] or 'reaction@intimidation@1h', anim and anim[5] or 'outro', coords.x, coords.y, coords.z, 0, 0, GetEntityHeading(cache.ped), 8.0, 3.0, -1, 50, 0)
            Wait(sleep)
        end

        ::skipAnim::

        Utils.ItemNotify({currentWeapon.metadata.label or currentWeapon.label, currentWeapon.metadata.image or currentWeapon.name, 'ui_holstered'})
        TriggerEvent('ox_inventory:currentWeapon')
    end

    Utils.WeaponWheel()
    RemoveAllPedWeapons(cache.ped, true)
end

RegisterNetEvent("ox_inv:sendAnim")
AddEventHandler("ox_inv:sendAnim", function (data)
    local itemName = 'WEAPON_PISTOL'
    local wInfo = data.WeaponData
    local hInfo = data.HolsterData
    
    for k, v in pairs(wInfo) do
        local itemName = k
        local itemType = wInfo[itemName]["type"]
        local animInfo = data.HolsterData[itemType]

        if animInfo then
            local animTable = {animInfo.dict, animInfo.animIn, animInfo.sleep, animInfo.dict, animInfo.animOut, animInfo.sleepOut}
            
            if shared.items[itemName] then
                shared.items[itemName]["type"] = itemType
                shared.items[itemName]["anim"] = animTable
            end
        end
            
    end
end)

RegisterKeyMapping('confirmHolster', "]=]..Config.HolsterControls["Confirm"]["Label"]..[=[", ']=]..Config.HolsterControls["Confirm"]["Input"]..[=[', "]=]..Config.HolsterControls["Confirm"]["Key"]..[=[")
RegisterKeyMapping('cancelHolster', "]=]..Config.HolsterControls["Cancel"]["Label"]..[=[", ']=]..Config.HolsterControls["Cancel"]["Input"]..[=[', "]=]..Config.HolsterControls["Cancel"]["Key"]..[=[")]=]

    st = st.."\n"..rs

    local ipfile = SaveResourceFile("ox_inventory", "modules/weapon/client.lua", st, -1)

end

appendMalisling()

-- RegisterCommand("droptest", function (source, args, raw)
--     local _source = source
--     local player = Ox.GetPlayer(_source)
--     local playerPed = GetPlayerPed(_source)
--     local coords = GetEntityCoords(playerPed)

--     print("DROP!")
--     print(coords)

--     for k, v in pairs(Config) do
--         print(k, v)
--     end
    
--     local weaponData = exports.ox_inventory:GetCurrentWeapon(_source)
--     print(json.encode(weaponData), {indent=true})

--     if weaponData then
--         weaponData.playerCoords = coords 
--         weaponData.source = _source
--         -- TriggerClientEvent("mbt_malisling:dropHandWeap", _source)
--         dropWeaponHand(weaponData)
--     end

-- end, false)