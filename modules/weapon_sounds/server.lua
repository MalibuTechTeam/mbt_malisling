if not MBT.Sounds or not MBT.Sounds.Enabled then return end

local maxDist = (MBT.Sounds.MaxDistance or 8.0) + 5.0

RegisterNetEvent('mbt_malisling:syncHolsterSound')
AddEventHandler('mbt_malisling:syncHolsterSound', function(weaponType, action)
    local src    = source
    local srcPed = GetPlayerPed(src)
    if not srcPed or srcPed == 0 then return end

    local srcCoords = GetEntityCoords(srcPed)

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid and pid ~= src then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 then
                if #(srcCoords - GetEntityCoords(ped)) <= maxDist then
                    TriggerClientEvent('mbt_malisling:remoteHolsterSound', pid, src, weaponType, action)
                end
            end
        end
    end
end)
