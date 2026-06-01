-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Weight / Carry Penalty — client
--
-- Carrying many counted-group weapons slightly slows the player. The server hands
-- back the carried WEAPON_* items; we resolve each group with GetWeapontypeGroup
-- (client native) and, if the counted total exceeds the threshold, apply a
-- move-rate override scaling with the surplus, capped at MaxPenalty. Purely RP.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.WeaponWeight or not MBT.WeaponWeight.Enabled then return end

local cfg = MBT.WeaponWeight

-- Resolve the active tuning from Mode: a named preset, raw fields ('custom'), or
-- bail out entirely ('off').
local mode = cfg.Mode or 'custom'
if mode == 'off' then return end
local tuning = (mode == 'custom') and cfg or (cfg.Presets and cfg.Presets[mode])
if not tuning then
    Utils.mbtWarn('weapon_weight ~ unknown Mode "' .. tostring(mode) .. '"; feature inert')
    return
end
local THRESHOLD   = tuning.Threshold or 2
local PER_WEAPON  = tuning.PerWeapon or 0.03
local MAX_PENALTY = tuning.MaxPenalty or 0.18

local moveRate = 1.0   -- 1.0 = normal speed; <1 = slowed

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

--- Recompute the target move rate from the current weapon count.
local function refresh()
    local n = countCarried()
    local surplus = n - THRESHOLD
    if surplus <= 0 then
        moveRate = 1.0
    else
        local penalty = math.min(MAX_PENALTY, surplus * PER_WEAPON)
        moveRate = 1.0 - penalty
    end
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

AddEventHandler('ox_inventory:updateInventory', function()
    -- A weapon may have been added/removed — recheck soon (debounced by the loop).
    CreateThread(refresh)
end)
