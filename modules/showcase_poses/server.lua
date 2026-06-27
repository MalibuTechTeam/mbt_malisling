-- ─────────────────────────────────────────────────────────────────────────────
-- Showcase Poses — server
-- Holds the active pose in a replicated Player statebag (vs a one-shot broadcast):
-- a pose is persistent, so a late-streaming client's StateBagChangeHandler replays
-- it on the already-posing ped — group-photo / late-join works automatically.
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the block exists; Enabled + Sync checked at use time (live-apply via menu).
if not MBT.ShowcasePoses then return end

local cfg     = MBT.ShowcasePoses
local lastUse = {}

RegisterNetEvent('mbt_malisling:setShowcasePose', function(idx)
    local src = source
    if not cfg.Enabled or not cfg.Sync then return end

    local now = GetGameTimer()
    if lastUse[src] and (now - lastUse[src]) < 300 then return end
    lastUse[src] = now

    if idx ~= false then
        idx = tonumber(idx)
        if not idx or not cfg.Poses[idx] then return end
    end

    Player(src).state:set('mbt_showcasePose', idx or false, true)
end)

AddEventHandler('playerDropped', function()
    if source then lastUse[source] = nil end
end)
