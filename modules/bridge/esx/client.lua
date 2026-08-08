if GetResourceState('es_extended') ~= 'started' then return end

local isInitialized = false

ESX = exports.es_extended:getSharedObject()
PlayerData = ESX.GetPlayerData()

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerLoaded = true
    PlayerData = xPlayer
    -- Fast multichar: esx:loadingScreenOff doesn't re-fire, so Init() runs here for
    -- the 2nd character. isInitialized was reset by esx:onPlayerLogout, so this is safe.
    if not isInitialized then
        isInitialized = true
        Init()
    end
end)

AddEventHandler('esx:loadingScreenOff', function()
    while not ESX.IsPlayerLoaded() do Wait(100) end
    if isInitialized then return end
    isInitialized = true
    Init()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
    sendAnimations(job.name)
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
    ESX.PlayerLoaded = false
    PlayerData = {}
    isInitialized = false
    deleteAllWeapons()
    ResetForMultichar()
end)

AddEventHandler('esx:removeInventoryItem', function(itemName, left)
    onEsxWeaponRemoved(itemName, left)
end)
