if not MBT.Sounds then return end   -- always register; Enabled is live-checked in the handler

local maxDist = (MBT.Sounds.MaxDistance or 8.0) + 5.0

RegisterNetEvent('mbt_malisling:syncHolsterSound')
AddEventHandler('mbt_malisling:syncHolsterSound', function(weaponType, action)
    if not MBT.Sounds.Enabled then return end   -- live on/off from the dashboard
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
