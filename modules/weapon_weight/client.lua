-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Weight / Carry Penalty — client
--
-- Carrying many counted-group weapons slightly slows the player. The server hands
-- back the carried WEAPON_* items; we resolve each group with GetWeapontypeGroup
-- (client native) and, if the counted total exceeds the threshold, apply a
-- move-rate override scaling with the surplus, capped at MaxPenalty. Purely RP.
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the feature block exists; Enabled + Mode are read at use time so the
-- admin menu can toggle/retune live (cfg is the live MBT.WeaponWeight table).
if not MBT.WeaponWeight then return end

local cfg = MBT.WeaponWeight

local moveRate = 1.0   -- 1.0 = normal speed; <1 = slowed

--- Resolve the active tuning from Mode each call (preset / custom / off).
--- Returns nil when the feature is off or the Mode is unknown.
local function activeTuning()
    if not cfg.Enabled then return nil end
    local mode = cfg.Mode or 'custom'
    if mode == 'off' then return nil end
    local t = (mode == 'custom') and cfg or (cfg.Presets and cfg.Presets[mode])
    if not t then return nil end
    return { THRESHOLD = t.Threshold or 2, PER_WEAPON = t.PerWeapon or 0.03, MAX_PENALTY = t.MaxPenalty or 0.18 }
end

--- Ask the server for carried weapons and compute the counted total.
local function countCarried()
    local weapons = lib.callback.await('mbt_malisling:getCarriedWeapons', false)
    if type(weapons) ~= 'table' then return 0 end
    local total = 0
    for i = 1, #weapons do
        local w = weapons[i]
        if w and w.name and cfg.CountGroups[GetWeapontypeGroup(joaat(w.name))] then
            total = total + (tonumber(w.count) or 1)
        end
    end
    return total
end

--- Recompute the target move rate from the current weapon count + active tuning.
local function refresh()
    local t = activeTuning()
    if not t then moveRate = 1.0; return end
    local surplus = countCarried() - t.THRESHOLD
    moveRate = surplus <= 0 and 1.0 or (1.0 - math.min(t.MAX_PENALTY, surplus * t.PER_WEAPON))
end

-- Apply loop: SetPedMoveRateOverride must be re-applied every frame while a
-- penalty is active (it resets). Sleeps fully when there's no penalty.
CreateThread(function()
    while true do
        if moveRate < 1.0 then
            SetPedMoveRateOverride(cache.ped, moveRate)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Refresh the count periodically and whenever the inventory changes.
CreateThread(function()
    Wait(2000)  -- let inventory/data finish loading
    while true do
        refresh()
        Wait(cfg.RefreshMs or 5000)
    end
end)

local refreshQueued = false
AddEventHandler('ox_inventory:updateInventory', function()
    -- Coalesce a burst of inventory mutations into ONE refresh — each refresh is a server
    -- round-trip, so looting/sorting otherwise fires one callback per mutated slot.
    if refreshQueued then return end
    refreshQueued = true
    SetTimeout(300, function() refreshQueued = false; refresh() end)
end)
