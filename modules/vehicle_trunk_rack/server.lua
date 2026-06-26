-- ─────────────────────────────────────────────────────────────────────────────
-- Vehicle Trunk Weapon Rack — server
--
-- Stow a long gun into a vehicle's trunk and retrieve it later. Persistence is a
-- single self-managed oxmysql table (mbt_malisling_trunk), keyed by plate, so a
-- racked weapon survives resource/server restarts and vehicle despawn — no item
-- loss. The weapon never lives in an inventory stash: its data
-- {name,count,metadata} is held in our table and re-minted into the player's
-- inventory on retrieve via the framework-agnostic Inventory bridge (ox + qb).
--
-- oxmysql is a SOFT, feature-gated dependency: without it this module disables
-- itself and the rest of the script stays DB-free. Every handler also early-exits
-- on cfg.Enabled so the admin menu can toggle it live.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.VehicleTrunkRack then return end

local cfg     = MBT.VehicleTrunkRack
local racks   = {}    -- [PLATE] = { { name, count, metadata, wtype }, ... }
local lastUse = {}    -- [src]   = GetGameTimer()  (rate limit)

local function hasDb() return GetResourceState('oxmysql') == 'started' end

-- ── Persistence (oxmysql) ──────────────────────────────────────────────────────
local function ensureSchema()
    if not hasDb() then
        Utils.mbtWarn('vehicle_trunk_rack ~ oxmysql not started; Trunk Rack persistence disabled')
        return
    end
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS mbt_malisling_trunk (
            plate VARCHAR(12) NOT NULL PRIMARY KEY,
            data LONGTEXT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]], {}, function()
        exports.oxmysql:execute('SELECT plate, data FROM mbt_malisling_trunk', {}, function(rows)
            if type(rows) == 'table' then
                for _, row in ipairs(rows) do
                    local ok, list = pcall(json.decode, row.data)
                    if ok and type(list) == 'table' and #list > 0 then racks[row.plate] = list end
                end
                Utils.mbtDebugger('vehicle_trunk_rack ~ loaded', #rows, 'rack rows from DB')
            end
        end)
    end)
end

--- Write-through: UPSERT the plate's rack, or DELETE the row when it empties.
local function saveRack(plate)
    if not hasDb() then return end
    local list = racks[plate]
    if not list or #list == 0 then
        racks[plate] = nil
        exports.oxmysql:execute('DELETE FROM mbt_malisling_trunk WHERE plate = ?', { plate })
    else
        exports.oxmysql:execute(
            'INSERT INTO mbt_malisling_trunk (plate, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
            { plate, json.encode(list) })
    end
end

-- ── Prop-offset overrides (admin-tunable via /mbt_trunktune, DB-persisted) ────────
-- Per-class (or per-model) prop placement, set in-world by an admin and broadcast
-- live to every client. Scope = 'class:<n>' or 'model:<name>'.
local adminCommand = (MBT.Admin and MBT.Admin.Command) or 'mbtconfig'
local adminPerm    = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)
local trunkOffsets = {}   -- [scope] = { Pos = {x,y,z}, Rot = {x,y,z} }

local function validOffset(d)
    if type(d) ~= 'table' or type(d.Pos) ~= 'table' or type(d.Rot) ~= 'table' then return false end
    for _, a in ipairs({ 'x', 'y', 'z' }) do
        if type(d.Pos[a]) ~= 'number' or d.Pos[a] < -3 or d.Pos[a] > 3 then return false end
        if type(d.Rot[a]) ~= 'number' or d.Rot[a] < -360 or d.Rot[a] > 360 then return false end
    end
    return true
end
-- Trunk rotation is a raw Euler offset on the vehicle boot bone; large pitch+roll
-- gimbal-locks it. Constrain pitch/roll to ±45°, keep yaw free. Runs on every save AND
-- on load, so any corrupt rotation an earlier build persisted is scrubbed automatically.
local TRUNK_MAX_TILT = 45.0
local function clampN(n, lo, hi)
    n = tonumber(n) or 0.0
    return (n < lo and lo) or (n > hi and hi) or n
end
local function norm180(n)
    local m = (tonumber(n) or 0.0) % 360.0
    return (m > 180.0) and (m - 360.0) or m
end
local function sanitizeOffset(d)
    return {
        Pos = { x = clampN(d.Pos.x, -3.0, 3.0), y = clampN(d.Pos.y, -3.0, 3.0), z = clampN(d.Pos.z, -3.0, 3.0) },
        Rot = { x = clampN(norm180(d.Rot.x), -TRUNK_MAX_TILT, TRUNK_MAX_TILT),
                y = clampN(norm180(d.Rot.y), -TRUNK_MAX_TILT, TRUNK_MAX_TILT),
                z = (tonumber(d.Rot.z) or 0.0) % 360.0 },
    }
end
local function validScope(s)
    if type(s) ~= 'string' then return false end
    local kind, key = s:match('^(%a+):(.+)$')
    if kind == 'class' then return tonumber(key) ~= nil end
    if kind == 'model' then return #key > 0 and #key <= 48 end
    return false
end

local function ensureOffsetSchema()
    if not hasDb() then return end
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS mbt_malisling_trunk_offsets (
            scope VARCHAR(48) NOT NULL PRIMARY KEY,
            data LONGTEXT NOT NULL
        )
    ]], {}, function()
        exports.oxmysql:execute('SELECT scope, data FROM mbt_malisling_trunk_offsets', {}, function(rows)
            if type(rows) ~= 'table' then return end
            for _, row in ipairs(rows) do
                local ok, d = pcall(json.decode, row.data)
                if ok and validOffset(d) then trunkOffsets[row.scope] = sanitizeOffset(d) end
            end
            Utils.mbtDebugger('vehicle_trunk_rack ~ loaded', #rows, 'offset overrides from DB')
        end)
    end)
end

lib.callback.register('mbt_malisling:getTrunkOffsets', function()
    local out = {}
    for scope, d in pairs(trunkOffsets) do out[#out + 1] = { scope = scope, data = d } end
    return out
end)

RegisterNetEvent('mbt_malisling:trunkOffset:save', function(payload)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if type(payload) ~= 'table' or not validScope(payload.scope) or not validOffset(payload.data) then return end
    local d = sanitizeOffset(payload.data)
    trunkOffsets[payload.scope] = d
    if hasDb() then
        exports.oxmysql:execute(
            'INSERT INTO mbt_malisling_trunk_offsets (scope, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
            { payload.scope, json.encode(d) })
    end
    TriggerClientEvent('mbt_malisling:trunkOffset:apply', -1, { scope = payload.scope, data = d })
end)

RegisterNetEvent('mbt_malisling:trunkOffset:reset', function(payload)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if type(payload) ~= 'table' or not validScope(payload.scope) then return end
    trunkOffsets[payload.scope] = nil
    if hasDb() then
        exports.oxmysql:execute('DELETE FROM mbt_malisling_trunk_offsets WHERE scope = ?', { payload.scope })
    end
    TriggerClientEvent('mbt_malisling:trunkOffset:apply', -1, { scope = payload.scope, data = false })
end)

-- ── Helpers ────────────────────────────────────────────────────────────────────
--- Server-side plate (never trust the client). Blank/whitespace → nil (refused).
local function vehPlate(veh)
    local p = GetVehicleNumberPlateText(veh)
    if type(p) ~= 'string' then return nil end
    p = p:gsub('%s+', '')
    if p == '' then return nil end
    return p
end

local weaponType = Utils.weaponType

--- Access control for the trunk rack (the interaction happens at the REAR, so the player is
--- normally standing outside behind the boot). Outside access uses the vehicle LOCK status —
--- but GetVehicleDoorLockStatus isn't reliable on every FXServer build, so unlike the old code
--- we DENY on a read failure (no fail-open that let a nearby thief drain a locked trunk). Only
--- the locked statuses block access; 0 (none) / 1 (unlocked) allow it. A server owner can override
--- with a trusted keys/ownership check via cfg.CanAccessOutside(src, veh, plate) -> bool.
local function isAccessible(src, ped, veh, plate)
    if GetVehiclePedIsIn(ped, false) == veh then return true end
    if type(cfg.CanAccessOutside) == 'function' then
        return cfg.CanAccessOutside(src, veh, plate) == true
    end
    local ok, lock = pcall(GetVehicleDoorLockStatus, veh)
    if not ok or type(lock) ~= 'number' then return false end   -- can't verify → deny (no fail-open)
    return not (lock == 2 or lock == 3 or lock == 4 or lock == 7 or lock == 8 or lock == 10)
end

--- Publish the render-only rack (weapon + type, no metadata) to the vehicle bag.
local function publish(veh, plate)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local list = racks[plate] or {}
    local render = {}
    for i = 1, #list do render[i] = { weapon = list[i].name, wtype = list[i].wtype } end
    Entity(veh).state:set('mbt_trunkRack', (#render > 0) and render or false, true)
end

--- Shared guard for stow/retrieve: resolves veh, near/rate/lock checks.
---@return number|nil veh, number|nil ped, string|nil plate, string|nil reason
local function guard(src, data)
    if not cfg.Enabled or type(data) ~= 'table' then return end
    local now = GetGameTimer()
    if lastUse[src] and (now - lastUse[src]) < 800 then return end
    lastUse[src] = now

    local veh = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > (cfg.InteractionDistance or 2.5) + 2.5 then return end
    local plate = vehPlate(veh)
    if not plate then return veh, ped, nil, 'trunk_no_plate' end
    if not isAccessible(src, ped, veh, plate) then return veh, ped, nil, 'trunk_locked' end
    return veh, ped, plate
end

-- ── Stow ───────────────────────────────────────────────────────────────────────
lib.callback.register('mbt_malisling:trunkRack:stow', function(src, data)
    local veh, _, plate, reason = guard(src, data)
    if reason then return { ok = false, reason = reason } end
    if not veh or not plate then return { ok = false } end

    local item = Inventory:GetSlot(src, tonumber(data.slot))
    if not item or type(item.name) ~= 'string' or item.name:sub(1, 7) ~= 'WEAPON_' then return { ok = false } end
    local wtype = weaponType(item.name)
    if not wtype or not (cfg.AllowedTypes and cfg.AllowedTypes[wtype]) then
        return { ok = false, reason = 'trunk_wrong_type' }
    end

    racks[plate] = racks[plate] or {}
    if #racks[plate] >= (cfg.Capacity or 2) then return { ok = false, reason = 'trunk_full' } end

    -- Atomic: only commit to the rack if the item actually left the player.
    if not Inventory:RemoveItem(src, item.name, item.count, nil, item.slot) then return { ok = false } end
    racks[plate][#racks[plate] + 1] = {
        name = item.name, count = item.count, metadata = item.metadata, wtype = wtype,
    }
    saveRack(plate)
    publish(veh, plate)
    return { ok = true }
end)

-- ── Retrieve ───────────────────────────────────────────────────────────────────
lib.callback.register('mbt_malisling:trunkRack:retrieve', function(src, data)
    local veh, _, plate, reason = guard(src, data)
    if reason then return { ok = false, reason = reason } end
    if not veh or not plate or not racks[plate] then return { ok = false } end

    local index = tonumber(data.index)
    local entry = index and racks[plate][index]
    if not entry then return { ok = false } end

    -- Claim the entry BEFORE the AddItem yield. ox AddItem yields, so two players
    -- retrieving from the same trunk at once would otherwise both read this entry and
    -- both receive the weapon (item dupe). Remove first; give it back if AddItem fails.
    table.remove(racks[plate], index)
    if not Inventory:AddItem(src, entry.name, entry.count, entry.metadata) then
        table.insert(racks[plate], index, entry)
        return { ok = false, reason = 'trunk_inv_full' }
    end
    saveRack(plate)
    publish(veh, plate)

    -- Optional equip-on-retrieve: ox uses the returned slot (useSlot); qb finds the
    -- weapon client-side and triggers its normal use-weapon flow. We just return the
    -- identifiers the client needs.
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

-- ── Re-publish (late-join / respawned vehicle) ──────────────────────────────────
lib.callback.register('mbt_malisling:trunkRack:getRack', function(_, netId)
    if not cfg.Enabled then return false end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local plate = vehPlate(veh)
    if not plate or not racks[plate] then return false end
    publish(veh, plate)
    return true
end)

AddEventHandler('playerDropped', function()
    if source then lastUse[source] = nil end
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ensureSchema()
    ensureOffsetSchema()
end)
