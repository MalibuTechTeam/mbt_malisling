-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Rack / Gun Locker — server
--
-- Place a weapon onto a fixed WORLD rack (defined in MBT.WeaponRack.Locations) and
-- retrieve it later. Same model as the Trunk Rack but anchored to a static config
-- location instead of a vehicle, so the rack itself needs no DB. The weapon never
-- lives in a stash: its {name,count,metadata} is held here and re-minted into the
-- player's inventory on retrieve via the framework-agnostic Inventory bridge (ox+qb).
--
-- Persistence is a single self-managed oxmysql table (mbt_malisling_racks), keyed by the
-- location id, so racked weapons survive restarts. oxmysql is SOFT/feature-gated:
-- without it the racks still work but their contents are in-memory only (reset on
-- restart) — the rest of the script stays DB-free.
--
-- Sync: the rack PROP is spawned locally and identically on every client (it's
-- config-defined), so only the CONTENTS are replicated — via GlobalState
-- (mbt_weaponRacks = { [id] = { {weapon,wtype}, ... } }). No networked weapon objects,
-- hence none of the weapon-object sync jitter that plagues other rack scripts.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.WeaponRack then return end

local cfg     = MBT.WeaponRack
local racks   = {}    -- [rackId] = { { name, count, metadata, wtype }, ... }
local lastUse = {}    -- [src]    = GetGameTimer()  (rate limit)

local function hasDb() return GetResourceState('oxmysql') == 'started' end

-- Server is the source of truth for a rack's coords + job; the client only ever
-- sends an id. Anything not in this table is refused.
local locById = {}
for _, loc in ipairs(cfg.Locations or {}) do
    if type(loc) == 'table' and type(loc.id) == 'string' and loc.coords then
        locById[loc.id] = loc
    end
end

-- Runtime-placed racks — admin (/mbt_placerack) and player (inventory item). Merged
-- into locById so stow/retrieve accept them, and persisted in mbt_malisling_rack_placements
-- (oxmysql; without it runtime racks reset on restart).
local adminCommand = (MBT.Admin and MBT.Admin.Command) or 'mbtconfig'
local adminPerm    = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)
local dynamicLocs  = {}   -- [id] = loc
local dynSeq       = 0

--- Stable player identifier (char identifier/citizenid from the framework bridge).
local function identifierOf(src)
    local _, id = getPlayerName(src)
    return id
end

-- ── Sync (GlobalState; render-only, no metadata leaves the server) ───────────────
local function publishAll()
    local render = {}
    for id, list in pairs(racks) do
        local r = {}
        for i = 1, #list do
            local md = list[i].metadata or {}
            -- Display-only fields for the rack picker UI (custom name, serial,
            -- durability for the condition tier) — never the full metadata.
            r[i] = {
                weapon = list[i].name, wtype = list[i].wtype,
                label = md.label, serial = md.serial, dur = md.durability,
            }
        end
        if #r > 0 then render[id] = r end
    end
    GlobalState.mbt_weaponRacks = render
end

-- ── Persistence (oxmysql) ────────────────────────────────────────────────────────
local function ensureSchema()
    if not hasDb() then
        Utils.mbtWarn('weapon_rack ~ oxmysql not started; rack contents are in-memory only (reset on restart)')
        return
    end
    -- Chain the CREATEs so each table is guaranteed to exist before any SELECT below
    -- (oxmysql runs queries on a pool → fire-and-forget CREATEs can race a fresh DB).
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS mbt_malisling_racks (
            rack_id VARCHAR(64) NOT NULL PRIMARY KEY,
            data LONGTEXT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]], {}, function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS mbt_malisling_rack_placements (
            id VARCHAR(64) NOT NULL PRIMARY KEY,
            data LONGTEXT NOT NULL
        )
    ]], {}, function()
        -- Placements FIRST (the contents loader skips ids not in locById), then contents.
        exports.oxmysql:execute('SELECT id, data FROM mbt_malisling_rack_placements', {}, function(prows)
            if type(prows) == 'table' then
                for _, row in ipairs(prows) do
                    local ok, loc = pcall(json.decode, row.data)
                    if ok and type(loc) == 'table' and type(loc.id) == 'string' and loc.coords then
                        locById[loc.id]     = loc
                        dynamicLocs[loc.id] = loc
                        TriggerClientEvent('mbt_malisling:weaponRack:spawn', -1, loc)
                    end
                end
                Utils.mbtDebugger('weapon_rack ~ loaded', #prows, 'placements from DB')
            end
            exports.oxmysql:execute('SELECT rack_id, data FROM mbt_malisling_racks', {}, function(rows)
                if type(rows) == 'table' then
                    for _, row in ipairs(rows) do
                        -- Skip rows for racks that no longer exist (renamed/removed).
                        if locById[row.rack_id] then
                            local ok, list = pcall(json.decode, row.data)
                            if ok and type(list) == 'table' and #list > 0 then racks[row.rack_id] = list end
                        end
                    end
                    Utils.mbtDebugger('weapon_rack ~ loaded', #rows, 'rack rows from DB')
                end
                publishAll()
            end)
        end)
    end)
    end)
end

--- Persist (or delete, with data=nil) a runtime placement. JSON-safe coords table.
local function savePlacement(loc)
    if not hasDb() then return end
    exports.oxmysql:execute(
        'INSERT INTO mbt_malisling_rack_placements (id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
        { loc.id, json.encode(loc) })
end

local function deletePlacement(id)
    if not hasDb() then return end
    exports.oxmysql:execute('DELETE FROM mbt_malisling_rack_placements WHERE id = ?', { id })
end

--- Write-through: UPSERT the rack, or DELETE the row when it empties.
local function saveRack(rackId)
    if not hasDb() then return end
    local list = racks[rackId]
    if not list or #list == 0 then
        racks[rackId] = nil
        exports.oxmysql:execute('DELETE FROM mbt_malisling_racks WHERE rack_id = ?', { rackId })
    else
        exports.oxmysql:execute(
            'INSERT INTO mbt_malisling_racks (rack_id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
            { rackId, json.encode(list) })
    end
end

-- ── Helpers ──────────────────────────────────────────────────────────────────────
local function weaponType(name)
    local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]
    return w and w.type
end

--- Per-location access gate: job-locked racks check the player's job; item-placed
--- racks (loc.owner) optionally lock to their owner (Placement.Access = 'owner').
local function canUse(src, loc)
    if loc.owner and (cfg.Placement and cfg.Placement.Access) == 'owner' then
        if identifierOf(src) ~= loc.owner then return false end
    end
    if not loc.job then return true end
    return getPlayerJob(src) == loc.job
end

--- Armory audit log → Discord webhook (fire-and-forget). Reads cfg.Logging fresh
--- each call so the admin menu's live-apply takes effect without a restart.
---@param src number
---@param action 'store'|'take'
---@param loc table        rack location (id/label)
---@param entry table      { name, metadata }
local function logRack(src, action, loc, entry)
    local log = cfg.Logging or {}
    if not log.Enabled or not log.Webhook or log.Webhook == '' then return end

    -- Character name + framework identifier (not the Steam/FiveM account name).
    local pname, pid = getPlayerName(src)
    local serial = (entry.metadata and entry.metadata.serial) or 'n/a'
    local label  = (entry.metadata and entry.metadata.label) or entry.name
    local job    = getPlayerJob(src)
    local stored = action == 'store'

    local payload = {
        username = log.BotName or 'MBT Armory',
        embeds = { {
            title = stored and 'Weapon Stored' or 'Weapon Taken',
            color = stored and 3066993 or 15105570,   -- green / orange
            fields = {
                { name = 'Player', value = ('%s (%s)'):format(pname or 'unknown', pid or src), inline = true },
                { name = 'Job',    value = (job and job ~= '') and job or 'n/a', inline = true },
                { name = 'Rack',   value = loc.label or loc.id, inline = true },
                { name = 'Weapon', value = label,  inline = true },
                { name = 'Serial', value = serial, inline = true },
            },
            footer = { text = ('item: %s · rack: %s'):format(entry.name, loc.id) },
        } },
    }
    PerformHttpRequest(log.Webhook, function() end, 'POST',
        json.encode(payload), { ['Content-Type'] = 'application/json' })
end

--- Shared guard for stow/retrieve: resolves the rack from its id, then runs
--- rate / proximity / job checks. Returns (loc, ped) or (loc, ped, reason).
local function guard(src, data)
    if not cfg.Enabled or type(data) ~= 'table' then return end
    local now = GetGameTimer()
    if lastUse[src] and (now - lastUse[src]) < 800 then return end
    lastUse[src] = now

    local loc = type(data.id) == 'string' and locById[data.id]
    if not loc then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = loc.coords
    if #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) > (cfg.InteractionDistance or 2.0) + 2.5 then return end
    if not canUse(src, loc) then return loc, ped, 'rack_no_access' end
    return loc, ped
end

-- ── Stow ───────────────────────────────────────────────────────────────────────
lib.callback.register('mbt_malisling:weaponRack:stow', function(src, data)
    local loc, _, reason = guard(src, data)
    if reason then return { ok = false, reason = reason } end
    if not loc then return { ok = false } end

    local item = Inventory:GetSlot(src, tonumber(data.slot))
    if not item or type(item.name) ~= 'string' or item.name:sub(1, 7) ~= 'WEAPON_' then return { ok = false } end
    local wtype = weaponType(item.name)
    if not wtype or not (cfg.AllowedTypes and cfg.AllowedTypes[wtype]) then
        return { ok = false, reason = 'rack_wrong_type' }
    end

    local id = loc.id
    racks[id] = racks[id] or {}
    if #racks[id] >= (cfg.Capacity or 4) then return { ok = false, reason = 'rack_full' } end

    -- Forensic backbone: a weapon entering an armory always gets a serial (safe
    -- transition — the item is about to be removed/re-added anyway).
    if MBT.EnsureSerial then MBT.EnsureSerial(src, item) end

    -- Atomic: only commit to the rack if the item actually left the player.
    if not Inventory:RemoveItem(src, item.name, item.count, nil, item.slot) then return { ok = false } end
    racks[id][#racks[id] + 1] = {
        name = item.name, count = item.count, metadata = item.metadata, wtype = wtype,
    }
    saveRack(id)
    publishAll()
    logRack(src, 'store', loc, item)
    return { ok = true }
end)

-- ── Retrieve ───────────────────────────────────────────────────────────────────
lib.callback.register('mbt_malisling:weaponRack:retrieve', function(src, data)
    local loc, _, reason = guard(src, data)
    if reason then return { ok = false, reason = reason } end
    if not loc or not racks[loc.id] then return { ok = false } end

    local index = tonumber(data.index)
    local entry = index and racks[loc.id][index]
    if not entry then return { ok = false } end

    -- Optional gate via the injected bridge (no-op when absent). Free build = nil → never blocks.
    if cfg.RequireCert and MBT.ShootingBridge and MBT.ShootingBridge.CanRetrieve then
        if not MBT.ShootingBridge.CanRetrieve(src, entry.name, entry.metadata) then
            return { ok = false, reason = 'rack_no_cert' }
        end
    end

    -- Claim the entry BEFORE the AddItem yield: ox AddItem yields, so two players at the
    -- same world rack would otherwise both read this entry and both receive the weapon
    -- (item dupe). Remove first; give it back if AddItem fails.
    table.remove(racks[loc.id], index)
    if not Inventory:AddItem(src, entry.name, entry.count, entry.metadata) then
        table.insert(racks[loc.id], index, entry)
        return { ok = false, reason = 'rack_inv_full' }
    end
    saveRack(loc.id)
    publishAll()
    logRack(src, 'take', loc, entry)

    -- Optional equip-on-retrieve: ox uses the returned slot (useSlot); qb finds the
    -- weapon client-side and triggers its normal use-weapon flow.
    local serial = entry.metadata and entry.metadata.serial
    local equipSlot
    if GetResourceState('ox_inventory') == 'started' then
        local ok2, s = pcall(function()
            return exports.ox_inventory:GetSlotIdWithItem(src, entry.name, { serial = serial }, true)
        end)
        if ok2 then equipSlot = s end
    end
    return { ok = true, equipSlot = equipSlot, name = entry.name, serial = serial }
end)

-- ── Runtime placement (admin command + player item) ───────────────────────────────
local function finite(n) return type(n) == 'number' and n == n and n > -1e6 and n < 1e6 end

--- Min spacing from every existing rack (placement collision check).
local function tooClose(x, y, z)
    local min = (cfg.Placement and cfg.Placement.MinSpacing) or 1.5
    for _, loc in pairs(locById) do
        local c = loc.coords
        if #(vec3(x, y, z) - vec3(c.x, c.y, c.z)) < min then return true end
    end
    return false
end

--- Register a runtime rack: merge, persist, broadcast.
local function addRuntimeRack(loc)
    locById[loc.id]     = loc
    dynamicLocs[loc.id] = loc
    savePlacement(loc)
    TriggerClientEvent('mbt_malisling:weaponRack:spawn', -1, loc)
end

local function removeRuntimeRack(id)
    dynamicLocs[id] = nil
    locById[id]     = nil
    racks[id]       = nil
    saveRack(id)            -- clears any persisted contents row for this id
    deletePlacement(id)
    publishAll()
    TriggerClientEvent('mbt_malisling:weaponRack:despawn', -1, id)
end

--- Unique runtime id (restart-safe: os.time prefix avoids reusing old ids).
local function newRackId(prefix)
    dynSeq = dynSeq + 1
    return ('%s_%d_%d'):format(prefix, os.time(), dynSeq)
end

RegisterNetEvent('mbt_malisling:weaponRack:place', function(p)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if type(p) ~= 'table' or not (finite(p.x) and finite(p.y) and finite(p.z)) then return end
    addRuntimeRack({
        id = newRackId('dyn'),
        -- Plain table (not vec4): placements are persisted as JSON.
        coords  = { x = p.x, y = p.y, z = p.z, w = finite(p.w) and p.w or 0.0 },
        prop    = (type(p.prop) == 'string' and p.prop) or nil,
        job     = (type(p.job) == 'string' and p.job) or false,
        label   = (type(p.label) == 'string' and p.label) or 'Armory',
        dynamic = true,
    })
end)

RegisterNetEvent('mbt_malisling:weaponRack:remove', function(id)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if type(id) ~= 'string' or not dynamicLocs[id] then return end
    removeRuntimeRack(id)
end)

-- ── Player placement (inventory item) ─────────────────────────────────────────────
local function placementOn()
    return cfg.Enabled and cfg.Placement and cfg.Placement.Enabled
        and type(cfg.Placement.Item) == 'string' and cfg.Placement.Item ~= ''
end

--- Item used → start the client carry/ghost flow (the item is only consumed on confirm).
local lastPlaceUse = {}
local function onUseRackItem(src)
    if not placementOn() then return end
    if not hasDb() then return end   -- placements need persistence; config racks still work
    local now = GetGameTimer()
    if lastPlaceUse[src] and (now - lastPlaceUse[src]) < 1500 then return end
    lastPlaceUse[src] = now
    TriggerClientEvent('mbt_malisling:weaponRack:startPlace', src)
end

-- ox_inventory path: the item's `server.export = 'mbt_malisling.<item>'` calls this
-- export on use. Returning false cancels ox's own consume (we consume on confirm).
exports((MBT.WeaponRack.Placement and MBT.WeaponRack.Placement.Item) or 'mbt_gunrack',
    function(event, _, inventory)
        if event == 'usingItem' and inventory and inventory.id then
            onUseRackItem(inventory.id)
            return false
        end
    end)
-- Framework path (ESX/QB/QBox usable items) when the bridge provides it.
if registerUsableItem and MBT.WeaponRack.Placement and MBT.WeaponRack.Placement.Item then
    pcall(registerUsableItem, MBT.WeaponRack.Placement.Item, onUseRackItem)
end

--- Ghost confirmed → validate, consume the item, install the rack.
lib.callback.register('mbt_malisling:weaponRack:placeItem', function(src, p)
    if not placementOn() or not hasDb() then return { ok = false } end
    if type(p) ~= 'table' or not (finite(p.x) and finite(p.y) and finite(p.z)) then return { ok = false } end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return { ok = false } end
    if #(GetEntityCoords(ped) - vec3(p.x, p.y, p.z)) > 8.0 then return { ok = false } end

    -- Per-player cap (by identifier) + spacing.
    local owner = identifierOf(src)
    if not owner then return { ok = false } end
    local count = 0
    for _, loc in pairs(dynamicLocs) do
        if loc.owner == owner then count = count + 1 end
    end
    -- Spacing first: when stacking on an existing rack, "too close" is the
    -- actionable message (move away), more useful than a generic "limit reached".
    if tooClose(p.x, p.y, p.z) then return { ok = false, reason = 'rack_too_close' } end
    if count >= (cfg.Placement.MaxPerPlayer or 2) then return { ok = false, reason = 'rack_limit' } end

    -- Atomic: the rack only appears if the item actually left the player.
    if not Inventory:RemoveItem(src, cfg.Placement.Item, 1) then return { ok = false } end

    addRuntimeRack({
        id     = newRackId('plr'),
        coords = { x = p.x, y = p.y, z = p.z, w = finite(p.w) and p.w or 0.0 },
        prop   = cfg.Placement.Prop or nil,
        job    = false,
        label  = cfg.Placement.Label or 'Gun Rack',
        owner  = owner,
        dynamic = true,
    })
    return { ok = true }
end)

--- Owner (or admin) picks an EMPTY item-placed rack back up → item returned.
lib.callback.register('mbt_malisling:weaponRack:pickup', function(src, id)
    if not placementOn() then return { ok = false } end
    if not (cfg.Placement.AllowPickup ~= false) then return { ok = false } end
    local loc = type(id) == 'string' and dynamicLocs[id]
    if not loc or not loc.owner then return { ok = false } end   -- only item-placed racks

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return { ok = false } end
    local c = loc.coords
    if #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) > (cfg.InteractionDistance or 2.0) + 2.5 then return { ok = false } end

    if loc.owner ~= identifierOf(src) and not IsPlayerAceAllowed(src, adminPerm) then
        return { ok = false, reason = 'rack_no_access' }
    end
    if racks[id] and #racks[id] > 0 then return { ok = false, reason = 'rack_not_empty' } end
    if not Inventory:AddItem(src, cfg.Placement.Item, 1) then return { ok = false, reason = 'rack_inv_full' } end

    removeRuntimeRack(id)
    return { ok = true }
end)

--- Client-side ownership checks (pickup target option) need the caller's identifier.
lib.callback.register('mbt_malisling:weaponRack:whoami', function(src)
    return identifierOf(src)
end)

-- Gate for the /mbt_racktune dev offset tuner. Its effect is purely client-local (it
-- re-positions the caller's OWN rack props and prints a config line — no server write), so
-- this gate is for tidiness, not security: only debug builds or admins get the tuner.
lib.callback.register('mbt_malisling:weaponRack:canTune', function(src)
    return (MBT.Debug == true) or IsPlayerAceAllowed(src, adminPerm)
end)

--- Count + list the caller's own item-placed racks (toward the MaxPerPlayer cap).
lib.callback.register('mbt_malisling:weaponRack:myRacks', function(src)
    local owner = identifierOf(src)
    local list = {}
    if owner then
        for id, loc in pairs(dynamicLocs) do
            if loc.owner == owner then
                local c = loc.coords
                list[#list + 1] = { id = id, label = loc.label, x = c.x, y = c.y, z = c.z }
            end
        end
    end
    return { count = #list, max = (cfg.Placement and cfg.Placement.MaxPerPlayer) or 2, list = list }
end)

--- Remove ALL of the caller's own placed racks (test/cleanup convenience). Only
--- empty racks are removed (a rack with weapons must be emptied first).
RegisterNetEvent('mbt_malisling:weaponRack:clearMine', function()
    local src = source
    local owner = identifierOf(src)
    if not owner then return end
    local ids = {}
    for id, loc in pairs(dynamicLocs) do
        if loc.owner == owner and not (racks[id] and #racks[id] > 0) then ids[#ids + 1] = id end
    end
    for _, id in ipairs(ids) do removeRuntimeRack(id) end
    TriggerClientEvent('mbt_malisling:weaponRack:clearedMine', src, #ids)
end)

--- Late-join / re-init: hand a client the runtime-placed racks so it spawns their props.
lib.callback.register('mbt_malisling:weaponRack:getDynamic', function()
    local out = {}
    for _, loc in pairs(dynamicLocs) do out[#out + 1] = loc end
    return out
end)

AddEventHandler('playerDropped', function()
    if source then lastUse[source] = nil; lastPlaceUse[source] = nil end
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    GlobalState.mbt_weaponRacks = {}   -- baseline before the async DB load resolves
    ensureSchema()
end)
