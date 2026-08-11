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
---@param prev table?  the same type's map from before this snapshot, for lane stability
local function assignLanes(t, prev)
    -- Whoever held the lane keeps it, as long as they are still carried. Without this the
    -- sort decides afresh every snapshot, so picking up a rifle whose name sorts earlier
    -- silently swaps the weapon on your back in front of everyone — the lane belongs to
    -- what is already being worn, not to the alphabet.
    if prev then
        for serial, e in pairs(prev) do
            if e.lane == 1 and t[serial] then
                t[serial].lane = 1
                for other in pairs(t) do
                    if other ~= serial then t[other].lane = nil end
                end
                return
            end
        end
    end

    local keys = {}
    for serial in pairs(t) do keys[#keys + 1] = serial end
    table.sort(keys, function(a, b)
        local na = t[a].data and t[a].data.name or ''
        local nb = t[b].data and t[b].data.name or ''
        if na ~= nb then return na < nb end
        return a < b
    end)
    for i = 1, #keys do
        t[keys[i]].lane = (i == 1) and 1 or nil
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
