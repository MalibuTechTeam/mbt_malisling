-- ── Slung prop registry — server ─────────────────────────────────────────────────
--   playersToTrack[serverId][propType][serialKey] = { data = weaponData, lane, vkey }
--
-- The server holds no entities: it holds what every observer has to be told. Both fan-outs
-- ship this table verbatim — the normal sync (core/server.lua) and the late-join scope
-- payload — which is exactly why the LANE lives in the entry. Anything kept beside it would
-- have to be threaded through two payloads by hand, and the day one of them forgot it, a
-- player entering scope would see the weapons in different places from everyone else.

playersToTrack = {}

---@return table?
local function bucket(src, propType, create)
    local p = playersToTrack[src]
    if not p then
        if not create then return nil end
        p = {}
        playersToTrack[src] = p
    end
    local t = p[propType]
    if not t then
        if not create then return nil end
        t = {}
        p[propType] = t
    end
    return t
end

--- Assign lanes across every serial of ONE type.
--- PHASE 2: cardinality is still one rendered prop per type, so exactly one entry gets
--- lane 1 and the rest are carried with no lane — tracked, not drawn. The pick is
--- deterministic (weapon name, then serial) so every observer, every late joiner and every
--- reconnect agree on which one it is; the old code let the order of `pairs` decide.
--- Phase 4 replaces THIS FUNCTION and nothing else: two-pass assignment (a lane per
--- distinct weapon name first, visual variants only with spare capacity), lease held while
--- the weapon is merely in hand, no compaction when one frees, inheritance when a component
--- changes the visual key. Kept as a single function so that stays true.
--- How many weapons this slot may DRAW. One unless the feature is on: the toggle has to be
--- semantically identical to the old behaviour, not merely similar.
local function laneCount()
    local cfg = MBT.MultiWeaponVisibility
    if not (cfg and cfg.Enabled) then return 1 end
    return math.max(1, math.floor(tonumber(cfg.MaxPerType) or 2))
end

--- Assign lanes across every serial of ONE type.
---
--- Groups by VISUAL SIGNATURE, so copies of a weapon that look identical on the body share
--- one prop, then hands out lanes in two passes:
---   1. one lane per distinct weapon NAME
---   2. leftover lanes to the other visual variants of names already shown
--- Without the second pass being second, two variants of one rifle would take both lanes
--- and the shotgun would vanish — the exact opposite of what this feature is for.
---
--- Whoever holds a lane keeps it while still carried, so picking up a weapon that sorts
--- earlier cannot silently swap what is on your back in front of everyone.
---@param prev table?  the same type's map from before this snapshot, for lane stability
local function assignLanes(t, prev)
    for _, e in pairs(t) do e.lane = nil end
    local maxLanes = laneCount()

    -- Serials sorted once: every derived order below inherits it, so two observers and two
    -- reconnects agree on the answer.
    local serials = {}
    for serial in pairs(t) do serials[#serials + 1] = serial end
    table.sort(serials)

    local groups, order = {}, {}
    for i = 1, #serials do
        local serial = serials[i]
        local e = t[serial]
        local vkey = e.vkey or (e.data and e.data.name) or '?'
        local g = groups[vkey]
        if not g then
            g = { vkey = vkey, name = (e.data and e.data.name) or '?', serials = {} }
            groups[vkey] = g
            order[#order + 1] = g
        end
        g.serials[#g.serials + 1] = serial
    end

    local taken = {}
    local function claim(g, lane)
        if not lane or lane > maxLanes or taken[lane] or g.lane then return false end
        taken[lane], g.lane = true, lane
        return true
    end
    local function lowestFree()
        for l = 1, maxLanes do if not taken[l] then return l end end
    end

    -- Leases first.
    if prev then
        for _, e in pairs(prev) do
            if e.lane and e.vkey and groups[e.vkey] then claim(groups[e.vkey], e.lane) end
        end
    end

    local byName, nameOrder = {}, {}
    for i = 1, #order do
        local g = order[i]
        if not byName[g.name] then
            byName[g.name] = {}
            nameOrder[#nameOrder + 1] = g.name
        end
        local list = byName[g.name]
        list[#list + 1] = g
    end
    table.sort(nameOrder)

    -- Pass 1 — a lane for every distinct name.
    for i = 1, #nameOrder do
        local list = byName[nameOrder[i]]
        table.sort(list, function(a, b) return a.vkey < b.vkey end)
        local placed = false
        for j = 1, #list do
            if list[j].lane then placed = true break end
        end
        if not placed then claim(list[1], lowestFree()) end
    end

    -- Pass 2 — what is left over goes to the other variants.
    for i = 1, #nameOrder do
        local list = byName[nameOrder[i]]
        for j = 1, #list do
            if not list[j].lane then claim(list[j], lowestFree()) end
        end
    end

    -- Stamp the group's representative. Whoever represented it before keeps the job, so a
    -- new copy arriving doesn't swap the prop for an identical one.
    for i = 1, #order do
        local g = order[i]
        if g.lane then
            local rep
            if prev then
                for j = 1, #g.serials do
                    local p = prev[g.serials[j]]
                    if p and p.lane then rep = g.serials[j] break end
                end
            end
            t[rep or g.serials[1]].lane = g.lane
        end
    end
end

---@return number?
local function allocateLane(t, serial)
    local e = t[serial]
    return e and e.lane or nil
end

--- Record one weapon as slung.
---@param weaponData table
---@return number lane
function Slung.put(src, propType, serial, weaponData)
    local t = bucket(src, propType, true)
    local lane = allocateLane(t, serial)
    t[serial] = {
        data = weaponData,
        lane = lane,
        vkey = Slung.visualKey(weaponData),
    }
    return lane
end

--- The owner's FULL desired set: every weapon that should be hanging on it right now,
--- keyed by type and serial. Replaces wholesale rather than merging, and that is the whole
--- point — a merge keeps entries for weapons that are gone, and nothing would ever tell us
--- they went. With a snapshot, a dropped event costs one stale frame instead of a prop that
--- hangs around until something unrelated happens to clear it.
---@param byType table<string, table<string, table>>
function Slung.replaceAll(src, byType)
    local prev = playersToTrack[src] or {}
    local p = {}
    playersToTrack[src] = p

    for propType, bySerial in pairs(byType) do
        if MBT.PropInfo[propType] and type(bySerial) == 'table' then
            local t = {}
            for serial, weaponData in pairs(bySerial) do
                -- A client can put anything on the wire: only tables that look like a
                -- weapon item get in, and the key is re-derived rather than trusted.
                if type(weaponData) == 'table' and type(weaponData.name) == 'string' then
                    t[tostring(serial)] = {
                        data = weaponData,
                        vkey = Slung.visualKey(weaponData),
                    }
                end
            end
            if next(t) then
                assignLanes(t, prev[propType])
                p[propType] = t
            end
        end
    end
end

--- Make sure this player HAS a registry entry, even an empty one.
--- Not cosmetic: playerEnteredScope refuses to wire a player who has no entry
--- (core/server.lua), and the bridges only create one on playerLoaded — which does NOT
--- fire again when the resource restarts under players who are already connected. Without
--- this, whoever reports a weapon first gets wired and the other one silently does not:
--- "I see him, he doesn't see me".
function Slung.ensurePlayer(src)
    if not playersToTrack[src] then playersToTrack[src] = {} end
end

function Slung.clearSerial(src, propType, serial)
    local t = bucket(src, propType)
    if t then t[serial] = nil end
end

function Slung.clearType(src, propType)
    local t = bucket(src, propType)
    if not t then return end
    for k in pairs(t) do t[k] = nil end
end

function Slung.clearAll(src)
    local p = playersToTrack[src]
    if not p then return end
    for propType in pairs(p) do Slung.clearType(src, propType) end
end

function Slung.clearPlayer(src)
    playersToTrack[src] = nil
end

--- What every observer of this player must render. The single point that decides the shape
--- on the wire: both the live sync and the scope/late-join payload go through here, so they
--- can never drift apart.
---@return table?
function Slung.snapshot(src)
    return playersToTrack[src]
end
