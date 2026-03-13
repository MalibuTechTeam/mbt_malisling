if GetResourceState('es_extended') ~= 'started' then return end

local isMultichar = GetResourceState('esx_multicharacter') ~= 'missing'
local isfirstSpawn = true

ESX = exports.es_extended:getSharedObject()
PlayerData = ESX.GetPlayerData()

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerLoaded = true
    PlayerData = xPlayer
end)

AddEventHandler('esx:loadingScreenOff', function()
    while not ESX.IsPlayerLoaded() do Wait(100) end
    if isMultichar and MBT.Relog and not isfirstSpawn then return end
    isfirstSpawn = false
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
    deleteAllWeapons()
end)

AddEventHandler('esx:removeInventoryItem', function(itemName, left)
    onEsxWeaponRemoved(itemName, left)
end)
