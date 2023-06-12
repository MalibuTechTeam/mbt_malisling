if not MBT.Jamming["Enabled"] then return end

local utils = require 'utils'
local jammed = GetGameTimer()
local currentWeapon

local jamAnim = MBT.Jamming["Animation"]
local isJammed = false
LocalPlayer.state:set('JammedState', false, false)

AddEventHandler('ox_inventory:currentWeapon', function(data)
    currentWeapon = data
end)

local function skillCheck()
    Wait(1000)
    local success

    repeat
        success = lib.skillCheck({ 'easy', 'easy', { areaSize = 50, speedMultiplier = 1 }, 'easy' }, { 'w', 'a', 'd' })
        Wait(success and 100 or 800)
    until success

    LocalPlayer.state:set('JammedState', false, false)
    MBT.Notification(MBT.Labels["has_unjammed"])
end

local function disableFiring()
    while isJammed do
        DisablePlayerFiring(cache.playerId, true)
        DisableControlAction(0, 25, true)
        Wait(5)
    end
end

local function jammedAnim()
    lib.requestAnimDict(jamAnim["Dict"])
    while isJammed do
        TaskPlayAnim(cache.ped, jamAnim["Dict"], jamAnim["Anim"], 2.0, 2.0, 750, 48, 0.0, false, false, false)
        DisablePlayerFiring(cache.playerId, true)
        DisableControlAction(0, 25, true)
        Wait(800)
    end
    ClearPedTasks(cache.ped)
    RemoveAnimDict(jamAnim["Dict"])
end

AddStateBagChangeHandler('JammedState', nil, function(bagName, key, value)
    if value == nil or not type(value) == "boolean" then return end
    isJammed = value
    utils.mbtDebugger("isJammed has been set to ", isJammed)
    MBT.Notification(MBT.Labels["has_jammed"])

    if isJammed then
        Citizen.CreateThread(function()
            disableFiring()
        end)
        Citizen.CreateThread(function()
            jammedAnim()
        end)
        Citizen.CreateThread(function()
            skillCheck()
        end)
    end
end)

AddEventHandler("CEventGunShotWhizzedBy", function(entities, eventEntity, args)
    if currentWeapon and not isJammed then
        utils.mbtDebugger("currentWeapon.metadata.durability ", currentWeapon.metadata.durability)
        if utils.getJammingChance(currentWeapon.metadata.durability) and (GetGameTimer() - jammed) > (MBT.Jamming["Cooldown"] * 1000) then
                jammed = GetGameTimer()
                LocalPlayer.state:set('JammedState', true, false)
        end
    end
end)
