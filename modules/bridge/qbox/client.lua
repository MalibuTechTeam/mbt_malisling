if GetResourceState('qbx_core') ~= 'started' then return end

QBCore = exports['qbx_core']:GetCoreObject()
PlayerData = QBCore.Functions.GetPlayerData()

AddEventHandler('qbx_core:client:playerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    Init()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    sendAnimations(JobInfo.name)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload')
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    deleteAllWeapons()
end)
