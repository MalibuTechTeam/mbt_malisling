-- ─────────────────────────────────────────────────────────────────────────────
-- Concealed Carry — server
--
-- Authoritative concealment state. The client keybind only sends a REQUEST with
-- its clothing-quality evaluation (drawables are client-side data); the server
-- validates everything else: feature on, type concealable, the player actually
-- carries a weapon of that type, cooldown, alive. State is published as a
-- replicated player statebag (mbt_concealed = { [type] = 'good'|'poor' }) that
-- every client's prop-spawn guard reads. The prop teardown/respawn reuses the
-- existing core flows (syncDeletion / checkInventory) — no new sync paths.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ConcealedCarry then return end

local cfg        = MBT.ConcealedCarry
local lastToggle = {}   -- [src] = GetGameTimer()

local QUALITY = { good = true, poor = true }

--- Does the player actually carry a weapon of this concealable type?
local function hasTypeWeapon(src, wtype)
    local items = Inventory:GetInventoryItems(src)
    if type(items) ~= 'table' then return false end
    for _, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string'
            and item.name:sub(1, 7) == 'WEAPON_' then
            local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[item.name]
            if w and w.type == wtype then return true end
        end
    end
    return false
end

--- Toggle request from the client. data = { wtype, quality ('good'|'poor'|'none') }.
--- Returns the new state so the client can drive the prop teardown/respawn.
lib.callback.register('mbt_malisling:concealed:toggle', function(src, data)
    if not cfg.Enabled or type(data) ~= 'table' then return { ok = false } end

    local now = GetGameTimer()
    if lastToggle[src] and (now - lastToggle[src]) < (cfg.ToggleCooldownMs or 3000) then
        return { ok = false }
    end
    lastToggle[src] = now

    local wtype = data.wtype
    if type(wtype) ~= 'string' or not (cfg.ConcealableTypes and cfg.ConcealableTypes[wtype]) then
        return { ok = false }
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return { ok = false } end

    local state = Player(src).state.mbt_concealed
    state = type(state) == 'table' and state or {}

    if state[wtype] then
        -- Reveal.
        state[wtype] = nil
        Player(src).state:set('mbt_concealed', next(state) and state or false, true)
        return { ok = true, concealed = false }
    end

    -- Conceal: clothing must allow it (client-evaluated — drawables are client
    -- data; worst-case spoof is visual-only) and the weapon must exist server-side.
    local quality = data.quality
    if not QUALITY[quality] then return { ok = false, reason = 'concealed_bare' } end
    if not hasTypeWeapon(src, wtype) then return { ok = false, reason = 'concealed_no_weapon' } end

    state[wtype] = quality
    Player(src).state:set('mbt_concealed', state, true)
    return { ok = true, concealed = true, quality = quality }
end)

--- Force-reveal (clothing change made concealment invalid). Client-reported,
--- server-applied: it only ever REVEALS, so there's nothing to spoof-abuse.
RegisterNetEvent('mbt_malisling:concealed:forceReveal', function(wtype)
    local src = source
    if not cfg.Enabled or type(wtype) ~= 'string' then return end
    local state = Player(src).state.mbt_concealed
    if type(state) ~= 'table' or not state[wtype] then return end
    state[wtype] = nil
    Player(src).state:set('mbt_concealed', next(state) and state or false, true)
end)

AddEventHandler('playerDropped', function()
    if source then lastToggle[source] = nil end
end)
