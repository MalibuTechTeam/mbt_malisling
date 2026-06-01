-- ─────────────────────────────────────────────────────────────────────────────
-- Showcase Poses — server
--
-- Holds the player's active pose in a replicated Player statebag. Unlike the
-- one-shot broadcast used by inspect/charge, a pose is persistent, so a statebag
-- is the right tool: when a new player streams in, their client's
-- StateBagChangeHandler fires and replays the pose on the already-posing ped —
-- which makes the group-photo / late-join case work automatically.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ShowcasePoses or not MBT.ShowcasePoses.Enabled then return end
if not MBT.ShowcasePoses.Sync then return end

local cfg     = MBT.ShowcasePoses
local lastUse = {}

RegisterNetEvent('mbt_malisling:setShowcasePose', function(idx)
    local src = source

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
