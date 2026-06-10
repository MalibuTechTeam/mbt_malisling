-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Rack / Gun Locker — server
--
-- Place a weapon onto a fixed WORLD rack (defined in MBT.WeaponRack.Locations) and
-- retrieve it later. Same model as the Trunk Rack but anchored to a static config
-- location instead of a vehicle, so the rack itself needs no DB. The weapon never
-- lives in a stash: its {name,count,metadata} is held here and re-minted into the
-- player's inventory on retrieve via the framework-agnostic Inventory bridge (ox+qb).
--
-- Persistence is a single self-managed oxmysql table (mbt_weapon_racks), keyed by the
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

-- Runtime-placed racks (admin /mbt_placerack). Merged into locById so stow/retrieve
-- accept them. NOT persisted yet (reset on restart) — DB persistence + an inventory
-- item are the v1.1 version of this.
local adminCommand = (MBT.Admin and MBT.Admin.Command) or 'mbtconfig'
local adminPerm    = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)
local dynamicLocs  = {}   -- [id] = loc
local dynSeq       = 0

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
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS mbt_weapon_racks (
            rack_id VARCHAR(64) NOT NULL PRIMARY KEY,
            data LONGTEXT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]], {}, function()
        exports.oxmysql:execute('SELECT rack_id, data FROM mbt_weapon_racks', {}, function(rows)
            if type(rows) == 'table' then
                for _, row in ipairs(rows) do
                    -- Skip rows for racks that no longer exist in config (renamed/removed).
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
end

--- Write-through: UPSERT the rack, or DELETE the row when it empties.
local function saveRack(rackId)
    if not hasDb() then return end
    local list = racks[rackId]
    if not list or #list == 0 then
        racks[rackId] = nil
        exports.oxmysql:execute('DELETE FROM mbt_weapon_racks WHERE rack_id = ?', { rackId })
    else
        exports.oxmysql:execute(
            'INSERT INTO mbt_weapon_racks (rack_id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
            { rackId, json.encode(list) })
    end
end

-- ── Helpers ──────────────────────────────────────────────────────────────────────
local function weaponType(name)
    local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]
    return w and w.type
end

--- Per-location job gate. No job set → anyone may use the rack.
local function canUse(src, loc)
    if not loc.job then return true end
    return getPlayerJob(src) == loc.job
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

    -- Atomic: only commit to the rack if the item actually left the player.
    if not Inventory:RemoveItem(src, item.name, item.count, nil, item.slot) then return { ok = false } end
    racks[id][#racks[id] + 1] = {
        name = item.name, count = item.count, metadata = item.metadata, wtype = wtype,
    }
    saveRack(id)
    publishAll()
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

    -- Only remove from the rack after the item is back in the inventory.
    if not Inventory:AddItem(src, entry.name, entry.count, entry.metadata) then
        return { ok = false, reason = 'rack_inv_full' }
    end
    table.remove(racks[loc.id], index)
    saveRack(loc.id)
    publishAll()

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

-- ── Runtime placement (admin) ────────────────────────────────────────────────────
local function finite(n) return type(n) == 'number' and n == n and n > -1e6 and n < 1e6 end

RegisterNetEvent('mbt_malisling:weaponRack:place', function(p)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if type(p) ~= 'table' or not (finite(p.x) and finite(p.y) and finite(p.z)) then return end
    dynSeq = dynSeq + 1
    local id  = 'dyn_' .. dynSeq
    local loc = {
        id = id, coords = vec4(p.x, p.y, p.z, finite(p.w) and p.w or 0.0),
        prop  = (type(p.prop) == 'string' and p.prop) or nil,
        job   = (type(p.job) == 'string' and p.job) or false,
        label = (type(p.label) == 'string' and p.label) or 'Armory',
        dynamic = true,
    }
    locById[id]     = loc
    dynamicLocs[id] = loc
    TriggerClientEvent('mbt_malisling:weaponRack:spawn', -1, loc)
end)

RegisterNetEvent('mbt_malisling:weaponRack:remove', function(id)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if type(id) ~= 'string' or not dynamicLocs[id] then return end
    dynamicLocs[id] = nil
    locById[id]     = nil
    racks[id]       = nil
    saveRack(id)            -- clears any persisted contents row for this id
    publishAll()
    TriggerClientEvent('mbt_malisling:weaponRack:despawn', -1, id)
end)

--- Late-join / re-init: hand a client the runtime-placed racks so it spawns their props.
lib.callback.register('mbt_malisling:weaponRack:getDynamic', function()
    local out = {}
    for _, loc in pairs(dynamicLocs) do out[#out + 1] = loc end
    return out
end)

AddEventHandler('playerDropped', function()
    if source then lastUse[source] = nil end
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    GlobalState.mbt_weaponRacks = {}   -- baseline before the async DB load resolves
    ensureSchema()
end)
