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

--- Lane for a serial in its type.
--- PHASE 1: cardinality is still one weapon per type, so the answer is always lane 1.
--- Phase 4 replaces THIS FUNCTION and nothing else: two-pass assignment (a lane per distinct
--- weapon name first, visual variants only with spare capacity), lease held while the weapon
--- is merely in hand, no compaction when one frees, inheritance when a component changes the
--- visual key. Kept as a single function so that stays true.
---@return number
local function allocateLane(t, serial)
    local e = t[serial]
    if e and e.lane then return e.lane end
    return 1
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

--- PHASE 1 ONLY — keeps today's cardinality while the shape changes underneath.
--- The client still reports one weapon per type, and the old registry overwrote
--- playersToTrack[src][type] on every report. Clearing before the put reproduces that
--- exactly. Phase 2 (desired-set reconciliation) deletes this function and puts each serial
--- independently; nothing else has to change for that.
---@return number lane
function Slung.replaceType(src, propType, weaponData)
    Slung.clearType(src, propType)
    return Slung.put(src, propType, Slung.serialKey(weaponData), weaponData)
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
