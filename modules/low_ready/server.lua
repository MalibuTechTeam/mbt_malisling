-- ─────────────────────────────────────────────────────────────────────────────
-- Low Ready — server
-- Broadcasts a player's low-ready toggle to nearby players so they re-place the
-- slung prop. Distance-based, rate-limited. Mirrors weapon_inspect/server.lua.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.LowReady then return end   -- always register; Enabled is live-checked in the handler

local maxDist  = 60.0  -- slung props are visible far; keep generous
local lastSync = {}

RegisterNetEvent('mbt_malisling:syncLowReady', function(propType, chest)
    local src = source
    if not MBT.LowReady.Enabled then return end   -- live on/off from the dashboard
    if type(propType) ~= 'string' then return end

    -- Rate limit the toggle key.
    local now = GetGameTimer()
    if lastSync[src] and (now - lastSync[src]) < 150 then return end
    lastSync[src] = now

    local srcPed = GetPlayerPed(src)
    if not srcPed or srcPed == 0 then return end
    local srcCoords = GetEntityCoords(srcPed)

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid and pid ~= src then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 and #(srcCoords - GetEntityCoords(ped)) <= maxDist then
                TriggerClientEvent('mbt_malisling:remoteLowReady', pid, src, propType, chest and true or false)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    if source then lastSync[source] = nil end
end)
