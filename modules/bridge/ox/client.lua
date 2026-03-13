if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

PlayerData = Ox.GetPlayerData() or {}

AddEventHandler('ox:playerLoaded', function(data)
    PlayerData = data
    Init()
end)

RegisterNetEvent('ox:setGroup')
AddEventHandler('ox:setGroup', function(group, grade)
    PlayerData.groups = PlayerData.groups or {}
    PlayerData.groups[group] = grade
    sendAnimations(nil)
end)
