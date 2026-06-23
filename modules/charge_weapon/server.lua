-- ─────────────────────────────────────────────────────────────────────────────
-- Charge Weapon — server
--
-- Broadcasts a charge to nearby players so they see the anim + hear the sound on
-- the source ped. Distance-based, rate-limited. Mirrors weapon_inspect/server.lua.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ChargeWeapon then return end   -- always register; Enabled is live-checked in the handler

local maxDist  = (MBT.ChargeWeapon.MaxDistance or 20.0) + 5.0
local lastSync = {}

RegisterNetEvent('mbt_malisling:syncCharge', function()
    if not MBT.ChargeWeapon.Enabled then return end   -- live on/off from the dashboard
    local src = source

    local now = GetGameTimer()
    if lastSync[src] and (now - lastSync[src]) < 1000 then return end
    lastSync[src] = now

    local srcPed = GetPlayerPed(src)
    if not srcPed or srcPed == 0 then return end
    local srcCoords = GetEntityCoords(srcPed)

    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid and pid ~= src then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 and #(srcCoords - GetEntityCoords(ped)) <= maxDist then
                TriggerClientEvent('mbt_malisling:remoteCharge', pid, src)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    if source then lastSync[source] = nil end
end)
