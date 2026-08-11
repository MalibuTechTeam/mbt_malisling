-- ── Slung prop registry — client ─────────────────────────────────────────────────
--   playersToTrack[serverId][propType][serialKey] = SlungEntry
--
-- Replaces a map whose single cell held five different things — nil, false, a spawn-in-flight
-- reservation, an editor reservation, and a prop handle — with the two reservations sharing
-- the same `true`. The states below are those five values told apart.
--
-- Rules this file exists to enforce:
--   * a handle exists ONLY with state == 'live'
--   * every prop dies in ONE place, entity first and registry after (the old code did the
--     reverse in four places, and a handle missing from the spawn registry left the prop
--     hanging in the world)
--   * iteration is deterministic (lane, then serial) and safe to delete from
--   * no net events in here: callers decide what to synchronise, this file touches memory
--     and entities only

local DoesEntityExist = DoesEntityExist
local DeleteObject = DeleteObject
local DeleteEntity = DeleteEntity
local GetEntityType = GetEntityType
local type = type
local next = next

---@class SlungEntry
---@field serial string   registry key (serial, or '#slot' fallback)
---@field name   string?  weapon name
---@field state  'live'|'pending'|'reserved'|'shadow'
---@field handle number?  prop entity — only with state == 'live'
---@field lane   number?  visual slot, assigned by the SERVER (always 1 in phase 1)
---@field data   table?   the weaponData we were sent; what a retry would re-spawn from
---@field why    string?  free-text reason for a reservation, shown by /mbt_slingdebug

playersToTrack = {}

local waiting = {}   -- [serverId] = true while syncSling waits for that player's ped to stream in
local spawned = {}   -- [handle] = true — every prop WE created (was an array with a linear scan)

-- ── Internals ────────────────────────────────────────────────────────────────────

---@param create boolean?  create the nested tables instead of returning nil
---@return table<string, SlungEntry>?
local function bucket(serverId, propType, create)
    local p = playersToTrack[serverId]
    if not p then
        if not create then return nil end
        p = {}
        playersToTrack[serverId] = p
    end
    local t = p[propType]
    if not t then
        if not create then return nil end
        t = {}
        p[propType] = t
    end
    return t
end

--- Serial keys of one type, ordered by lane then serial, materialised up front: the order
--- must never depend on `pairs`, and a callback has to be able to delete while iterating.
---@return string[]
local function orderedSerials(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local la = t[a].lane or math.maxinteger
        local lb = t[b].lane or math.maxinteger
        if la ~= lb then return la < lb end
        return a < b
    end)
    return keys
end

local LIVE_ONLY = { live = true }

---@return table<string, boolean>?  nil means "every state"
local function statesOf(opts)
    local s = opts and opts.states
    if not s then return LIVE_ONLY end
    if s == 'all' then return nil end
    local set = {}
    for i = 1, #s do set[s[i]] = true end
    return set
end

--- The ONE place a slung prop dies. Entity first, registry after.
---@return boolean deleted  false when the entry held no prop
local function destroy(entry)
    local h = entry.handle
    entry.handle = nil
    if not h then return false end
    spawned[h] = nil
    if DoesEntityExist(h) then DeleteObject(h) end
    return true
end

-- ── Read ─────────────────────────────────────────────────────────────────────────

--- The entry for one serial, whatever its state (shadow and pending included).
---@return SlungEntry?
function Slung.entry(serverId, propType, serial)
    local t = bucket(serverId, propType)
    return t and t[serial] or nil
end

--- The prop entity for one serial, or nil. Only ever answers for a live, existing entity.
---@return number?
function Slung.get(serverId, propType, serial)
    local e = Slung.entry(serverId, propType, serial)
    if e and e.state == 'live' and e.handle and DoesEntityExist(e.handle) then return e.handle end
    return nil
end

--- Is this slot OCCUPIED — a prop, a spawn in flight, or a deliberate reservation.
--- Not "is there an entry": a shadow holds no prop and must not block a spawn, or a weapon
--- whose streaming failed once would never be retried by the ordinary sync path.
---@return boolean
function Slung.hasType(serverId, propType)
    local t = bucket(serverId, propType)
    if not t then return false end
    for _, e in pairs(t) do
        if e.state == 'live' or e.state == 'pending' or e.state == 'reserved' then return true end
    end
    return false
end

--- Iterate one type. `fn(handle, propType, serial, entry)`; a non-nil return STOPS the walk
--- and becomes the return value — find, any and first are all this one primitive.
---@param opts table?  { states = {'live'} | 'all', stale = boolean }
function Slung.forEachType(serverId, propType, fn, opts)
    local t = bucket(serverId, propType)
    if not t then return nil end

    local states = statesOf(opts)
    local keys = orderedSerials(t)
    local stale = opts and opts.stale

    for i = 1, #keys do
        local e = t[keys[i]]
        if e and (not states or states[e.state]) then
            -- A live handle whose entity is gone (entity migration, engine recycle) is not
            -- something a caller should act on unless it explicitly asked for it.
            if e.state ~= 'live' or stale or (e.handle and DoesEntityExist(e.handle)) then
                local r = fn(e.handle, propType, keys[i], e)
                if r ~= nil then return r end
            end
        end
    end
end

--- Iterate every type of one player, types in a stable order. Same callback contract.
function Slung.forEach(serverId, fn, opts)
    local p = playersToTrack[serverId]
    if not p then return nil end

    local types = {}
    for k in pairs(p) do types[#types + 1] = k end
    table.sort(types)

    for i = 1, #types do
        local r = Slung.forEachType(serverId, types[i], fn, opts)
        if r ~= nil then return r end
    end
end

--- The prop in the lowest lane of this type. COMPAT ONLY: a caller holding a serial must
--- use Slung.get or Slung.resolve — the serial is the identity, "the first one" is not.
---@return number? handle, string? serial
function Slung.first(propType, serverId)
    serverId = serverId or cache.serverId
    local t = bucket(serverId, propType)
    if not t then return nil end

    local keys = orderedSerials(t)
    for i = 1, #keys do
        local e = t[keys[i]]
        if e.state == 'live' and e.handle and DoesEntityExist(e.handle) then
            return e.handle, keys[i]
        end
    end
    return nil
end

-- ── Write ────────────────────────────────────────────────────────────────────────

--- Claim a slot before the async spawn. The ONLY door to a reservation, and the guard that
--- stops two near-simultaneous syncSling from both passing the "is it free" test during the
--- ~500ms create window and orphaning one of the two props.
---@param why string?  shown by /mbt_slingdebug — this is what told the two old `true`s apart
---@return boolean claimed
function Slung.reserve(serverId, propType, serial, why)
    if not Slung.isType(propType) then return false end

    local t = bucket(serverId, propType, true)
    local e = t[serial]
    if e and (e.state == 'live' or e.state == 'pending' or e.state == 'reserved') then
        return false
    end

    t[serial] = e or { serial = serial }
    t[serial].state = 'pending'
    t[serial].why = why
    return true
end

--- Reservation → live prop.
---@param data table?  weaponData, kept so a later retry has something to re-spawn from
---@param lane number?  the lane the SERVER assigned; the client applies it, never invents it
function Slung.commit(serverId, propType, serial, handle, data, lane)
    local t = bucket(serverId, propType, true)
    local e = t[serial] or { serial = serial }

    e.state, e.handle = 'live', handle
    e.why = nil              -- the reservation is over; keeping it only muddies /mbt_slingdebug
    if lane then e.lane = lane end
    if data then
        e.data = data
        e.name = data.name
    end
    t[serial] = e
    spawned[handle] = true
    return e
end

--- Spawn failed (asset streaming, create timeout): drop to shadow rather than deleting the
--- entry, and keep the weaponData so a retry has something to build from. The slot is free
--- again — a shadow does not occupy it — so the ordinary sync path retries on its own, and
--- phase 2's reconciliation tick can retry without waiting for one.
---@param data table?  the weaponData the failed spawn was built from
function Slung.release(serverId, propType, serial, data)
    local e = Slung.entry(serverId, propType, serial)
    if not e then return end
    destroy(e)
    e.state = 'shadow'
    if data then
        e.data = data
        e.name = data.name
    end
end

--- Track a serial with no prop: a visual duplicate, an overflow past MaxPerType, or a
--- failed spawn. Shadows are what make "delete them all" and promotion possible.
function Slung.shadow(serverId, propType, serial, data, lane)
    local t = bucket(serverId, propType, true)
    local e = t[serial] or { serial = serial }

    destroy(e)
    e.state = 'shadow'
    e.lane = lane
    if data then
        e.data = data
        e.name = data.name
    end
    t[serial] = e
    return e
end

-- ── Delete ───────────────────────────────────────────────────────────────────────

--- @param opts table?  { reserve = true } deletes the prop but KEEPS the slot claimed, so
---                     nothing re-spawns it (what the position editor needs while editing)
---@return boolean deleted
function Slung.deleteSerial(serverId, propType, serial, opts)
    local t = bucket(serverId, propType)
    if not t then return false end
    local e = t[serial]
    if not e then return false end

    local had = destroy(e)
    if opts and opts.reserve then
        e.state = 'reserved'
        e.why = 'editor'
    else
        t[serial] = nil
    end
    return had
end

---@return number deleted
function Slung.deleteType(serverId, propType, opts)
    local t = bucket(serverId, propType)
    if not t then return 0 end

    local n = 0
    local keys = orderedSerials(t)
    for i = 1, #keys do
        if Slung.deleteSerial(serverId, propType, keys[i], opts) then n = n + 1 end
    end
    return n
end

--- Every prop of one player, or of EVERY tracked player when serverId is nil.
---@return number deleted
function Slung.deleteAll(serverId, opts)
    local n = 0
    if serverId then
        local p = playersToTrack[serverId]
        if not p then return 0 end
        for propType in pairs(p) do
            n = n + Slung.deleteType(serverId, propType, opts)
        end
        return n
    end
    for id in pairs(playersToTrack) do
        n = n + Slung.deleteAll(id, opts)
    end
    return n
end

--- Scope exit: props gone, the player stays tracked. Replaces the three hardcoded six-type
--- resets (PropInfo has seven — 'extinguisher' was missing from all of them). No type keys
--- are pre-created: buckets appear on first use, so the reset can't go stale against config.
function Slung.resetPlayer(serverId)
    Slung.deleteAll(serverId)
    playersToTrack[serverId] = {}
    waiting[serverId] = nil
end

--- Disconnect / removal: props gone and the player forgotten entirely.
function Slung.clearPlayer(serverId)
    Slung.deleteAll(serverId)
    playersToTrack[serverId] = nil
    waiting[serverId] = nil
end

--- Drop live entries whose entity no longer exists (network ownership migration, engine
--- handle recycling) so they stop being reported as props that are there.
---@return number pruned
function Slung.prune(serverId)
    local p = playersToTrack[serverId]
    if not p then return 0 end

    local n = 0
    for propType, t in pairs(p) do
        for _, serial in ipairs(orderedSerials(t)) do
            local e = t[serial]
            if e.state == 'live' and (not e.handle or not DoesEntityExist(e.handle)) then
                if e.handle then spawned[e.handle] = nil end
                e.handle = nil
                e.state = 'shadow'
                n = n + 1
            end
        end
    end
    return n
end

-- ── Waiting (out of the type map on purpose) ─────────────────────────────────────
-- It used to live at playersToTrack[serverId]['waiting'], next to the type keys: with
-- table values every pairs() over the registry would now hit a boolean where it expects a
-- dictionary of serials. Keeping it here also makes it nil-safe for a player who was
-- removed mid-wait — core/client.lua wrote to that table after syncPlayerRemoval nilled it.

---@return boolean
function Slung.isWaiting(serverId)
    return waiting[serverId] == true
end

function Slung.setWaiting(serverId, value)
    waiting[serverId] = value or nil
end

-- ── Promotion (injection point — phase 4 fills it) ───────────────────────────────

--- Installed by the core in phase 4: builds the prop for one entry in a given lane.
--- Signature: fun(serverId, propType, entry, lane): number|nil
Slung.spawner = nil

--- The handle this action may act on FOR THIS SERIAL. When the serial has no prop because
--- another copy of the same model represents it, phase 4 promotes it into the same lane —
--- new prop built hidden, attached, revealed, and only then the old one deleted. Never the
--- other way round: the create-to-attach window reaches ~550ms, and a weapon that vanishes
--- from a back and returns reads as a bug.
--- Phase 1 has no spawner, so this degrades to a plain lookup: exactly today's behaviour.
---@return number? handle, boolean promoted
function Slung.resolve(propType, serial, serverId)
    serverId = serverId or cache.serverId

    local h = Slung.get(serverId, propType, serial)
    if h then return h, false end

    local e = Slung.entry(serverId, propType, serial)
    if not e or not Slung.spawner then return nil, false end

    local lane = e.lane
    local promoted = Slung.spawner(serverId, propType, e, lane)
    if not promoted then return nil, false end

    -- Same lane, one representative: whoever held it steps down only now that the
    -- replacement is on the ped and visible.
    Slung.forEachType(serverId, propType, function(_, _, otherSerial, other)
        if otherSerial ~= serial and other.lane == lane then
            Slung.deleteSerial(serverId, propType, otherSerial)
        end
    end)
    Slung.commit(serverId, propType, serial, promoted, e.data)
    return promoted, true
end

-- ── Teardown ─────────────────────────────────────────────────────────────────────

--- Resource stop: delete every prop we created. Only weapon OBJECTS (type 3) — entity
--- handles get recycled by the engine, so a stale handle can point at a ped (an MLO one,
--- say) by now, and deleting that is what made interior peds drop on restart.
function Slung.teardown()
    for h in pairs(spawned) do
        if DoesEntityExist(h) and GetEntityType(h) == 3 then DeleteEntity(h) end
    end
    spawned = {}
end
