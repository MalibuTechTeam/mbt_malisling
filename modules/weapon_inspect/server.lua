-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Inspect — server
-- Broadcasts inspect start/stop to nearby players for the source-ped animation
-- (distance-based, mirrors weapon_sounds/server.lua). Overlay stays client-local.
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the block exists; Enabled + MaxDistance read fresh (live-apply via menu).
if not MBT.Inspect then return end

local lastSync = {}  -- [src] = last GetGameTimer(), basic rate limit

RegisterNetEvent('mbt_malisling:syncInspect', function(action)
    local src = source
    if not MBT.Inspect.Enabled then return end
    if action ~= 'start' and action ~= 'stop' then return end

    local maxDist = (MBT.Inspect.MaxDistance or 20.0) + 5.0

    -- Rate limit: the +/- key pair can be mashed; ignore bursts under 150ms.
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
                TriggerClientEvent('mbt_malisling:remoteInspect', pid, src, action)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    if source then lastSync[source] = nil end
end)
