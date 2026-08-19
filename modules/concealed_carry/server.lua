-- ─────────────────────────────────────────────────────────────────────────────
-- Concealed Carry — server
-- Authoritative concealment state. Client sends a REQUEST with its clothing-quality
-- eval (drawables are client data); server validates the rest (feature on, type
-- concealable, carries that weapon, cooldown, alive). Published as a replicated
-- statebag (mbt_concealed = { [type] = 'good'|'poor' }) read by every client's
-- prop-spawn guard. Teardown/respawn reuses core flows (syncDeletion/checkInventory).
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ConcealedCarry then return end

local cfg        = MBT.ConcealedCarry
local lastToggle = {}   -- [src] = GetGameTimer()

local QUALITY = { good = true, poor = true }

--- Does the player actually carry THIS weapon, and is it concealable?
--- By serial, not by type: "he owns some pistol" is not authority to hide a specific one,
--- and the serial is what the statebag will be keyed by.
---@return boolean ok, string? wtype
local function ownsConcealable(src, serial)
    local items = Inventory:GetInventoryItems(src)
    if type(items) ~= 'table' then return false end

    for _, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string'
            and item.name:sub(1, 7) == 'WEAPON_' then
            local key = Slung.serialKey(item)
            if key == serial then
                local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[item.name]
                local wtype = w and w.type
                if wtype and cfg.ConcealableTypes and cfg.ConcealableTypes[wtype] then
                    return true, wtype
                end
                return false
            end
        end
    end
    return false
end

--- Toggle request. data = { wtype, quality }; returns new state for client prop sync.
lib.callback.register('mbt_malisling:concealed:toggle', function(src, data)
    if not cfg.Enabled or type(data) ~= 'table' then return { ok = false } end

    local now = GetGameTimer()
    if lastToggle[src] and (now - lastToggle[src]) < (cfg.ToggleCooldownMs or 3000) then
        return { ok = false }
    end
    lastToggle[src] = now

    local serial = data.serial
    if type(serial) ~= 'string' or #serial > 64 then return { ok = false } end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return { ok = false } end

    local state = Player(src).state.mbt_concealed
    state = type(state) == 'table' and state or {}

    if state[serial] then
        -- Reveal. No ownership check: revealing is never something to protect against, and
        -- refusing it would strand a player whose weapon left their hands while hidden.
        state[serial] = nil
        Player(src).state:set('mbt_concealed', next(state) and state or false, true)
        return { ok = true, concealed = false }
    end

    -- Conceal: clothing must allow it (client-evaluated — drawables are client data;
    -- worst-case spoof is visual-only) and this exact weapon must be his and concealable.
    local quality = data.quality
    if not QUALITY[quality] then return { ok = false, reason = 'concealed_bare' } end

    local ok, wtype = ownsConcealable(src, serial)
    if not ok then return { ok = false, reason = 'concealed_no_weapon' } end

    -- Refuse concealing what the player's job already hides. Without this, the toggle
    -- reports success — tuck gesture, tell timer, pat-down deception, all of it — for a
    -- weapon that was already invisible for an unrelated reason and gains nothing from it.
    -- Reveal is never refused this way (see the branch above): there is nothing to protect
    -- by blocking it, and a job-hidden weapon revealing is meaningless in the same direction.
    if Slung.isHiddenByJob(src, wtype) then
        return { ok = false, reason = 'concealed_already_hidden' }
    end

    state[serial] = { t = wtype, q = quality }
    Player(src).state:set('mbt_concealed', state, true)
    return { ok = true, concealed = true, quality = quality }
end)

--- Force-reveal (clothing change invalidated concealment); client-reported but only ever REVEALS, so there's nothing to spoof-abuse.
RegisterNetEvent('mbt_malisling:concealed:forceReveal', function(serial)
    local src = source
    if not cfg.Enabled or type(serial) ~= 'string' then return end
    -- Each accepted call writes a replicated statebag, so an unthrottled one is a free
    -- way to make the server broadcast to every client.
    if not (MBT.NetThrottle and MBT.NetThrottle(src, 'forceReveal', 250)) then return end
    local state = Player(src).state.mbt_concealed
    if type(state) ~= 'table' or not state[serial] then return end
    state[serial] = nil
    Player(src).state:set('mbt_concealed', next(state) and state or false, true)
end)

AddEventHandler('playerDropped', function()
    if source then lastToggle[source] = nil end
end)

-- Resource restart wipes the module's client state but the replicated statebag
-- would survive → players stuck concealed with no way to toggle back. Clear all
-- concealment on start; props re-sync through the normal init checkInventory.
AddEventHandler('onServerResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, src in ipairs(GetPlayers()) do
        local s = tonumber(src)
        if s and Player(s).state.mbt_concealed then
            Player(s).state:set('mbt_concealed', false, true)
        end
    end
end)
