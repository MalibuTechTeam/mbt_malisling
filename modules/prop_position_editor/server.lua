-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon-Prop Position Editor — server
-- Persists per-type (+ per-job) prop attach offsets in oxmysql (mbt_malisling_positions),
-- overriding config.lua defaults. Admin-only (ACE), validated server-side, broadcast live.
-- oxmysql is soft/feature-gated: without it the editor can't save; rest stays DB-free.
-- ─────────────────────────────────────────────────────────────────────────────

local adminCommand = (MBT.Admin and MBT.Admin.Command) or GetCurrentResourceName()
local adminPerm    = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)

local WTYPES = { side = true, back = true, back2 = true, melee = true, melee2 = true, melee3 = true, extinguisher = true, sling = true }
-- Valid wtypes = the base set, per-variant sling virtual types 'sling:<id>', and the extra
-- multi-weapon lanes '<slot>#<n>' — a lane is an ordinary position with its own key, which
-- is what lets it be edited, overridden per job and persisted like any other. Without this
-- the editor would refuse to save one AND drop it again on load.
local function validWtype(w)
    if WTYPES[w] == true then return true end
    if type(w) ~= 'string' then return false end
    if w:match('^sling:[%w%-_]+$') then return true end
    local slot, lane = w:match('^(%w+)#(%d+)$')
    return (slot ~= nil and WTYPES[slot] == true and tonumber(lane) ~= nil and tonumber(lane) >= 2)
end
local BONES  = { [24816] = true, [24818] = true, [57005] = true, [36029] = true,
                 [58271] = true, [51826] = true, [11816] = true, [23553] = true }

-- Snapshot the config.lua defaults BEFORE any DB override, so Reset can restore them.
local CONFIG_DEFAULTS = json.decode(json.encode(MBT.PropInfo or {}))

local function hasDb() return GetResourceState('oxmysql') == 'started' end

-- DB overrides mirrored in memory so a client joining AFTER load can fetch them on init.
-- The propPos:apply broadcast only reaches connected clients → without this, saved
-- positions revert to config defaults on every restart.
local saved = {}   -- [scope.."\0"..wtype] = { scope = ..., wtype = ..., data = ... }
local function savedKey(scope, wtype) return scope .. '\0' .. wtype end
local function rememberSaved(scope, wtype, data)
    saved[savedKey(scope, wtype)] = { scope = scope, wtype = wtype, data = data }
end
lib.callback.register('mbt_malisling:getPropPositions', function()
    local out = {}
    for _, row in pairs(saved) do out[#out + 1] = row end
    return out
end)

-- ── Validation ───────────────────────────────────────────────────────────────
local function isVec(v, lo, hi)
    return type(v) == 'table' and type(v.x) == 'number' and v.x >= lo and v.x <= hi
        and type(v.y) == 'number' and v.y >= lo and v.y <= hi
        and type(v.z) == 'number' and v.z >= lo and v.z <= hi
end

local function validData(d)
    if type(d) ~= 'table' then return false end
    if type(d.Bone) ~= 'number' or not BONES[d.Bone] then return false end
    if type(d.isPed) ~= 'boolean' then return false end
    if type(d.RotOrder) ~= 'number' or d.RotOrder < 0 or d.RotOrder > 5 then return false end
    if type(d.FixedRot) ~= 'boolean' then return false end
    if type(d.Pos) ~= 'table' or not isVec(d.Pos.male, -2.0, 2.0) or not isVec(d.Pos.female, -2.0, 2.0) then return false end
    if type(d.Rot) ~= 'table' or not isVec(d.Rot.male, -360.0, 360.0) or not isVec(d.Rot.female, -360.0, 360.0) then return false end
    return true
end

--- Strip to the canonical shape (drops anything extra the client may send).
local function sanitize(d)
    return {
        Bone = d.Bone, isPed = d.isPed, RotOrder = d.RotOrder, FixedRot = d.FixedRot,
        Pos = {
            male   = { x = d.Pos.male.x,   y = d.Pos.male.y,   z = d.Pos.male.z },
            female = { x = d.Pos.female.x, y = d.Pos.female.y, z = d.Pos.female.z },
        },
        Rot = {
            male   = { x = d.Rot.male.x,   y = d.Rot.male.y,   z = d.Rot.male.z },
            female = { x = d.Rot.female.x, y = d.Rot.female.y, z = d.Rot.female.z },
        },
    }
end

-- ── Apply to server-side MBT.* ───────────────────────────────────────────────
local function applyServer(scope, wtype, data)
    if scope == 'default' then
        MBT.PropInfo[wtype] = data
    else
        MBT.CustomPropPosition[scope] = MBT.CustomPropPosition[scope] or {}
        MBT.CustomPropPosition[scope][wtype] = data
    end
end

local function resetServer(scope, wtype)
    if scope == 'default' then
        MBT.PropInfo[wtype] = json.decode(json.encode(CONFIG_DEFAULTS[wtype]))
    elseif MBT.CustomPropPosition[scope] then
        MBT.CustomPropPosition[scope][wtype] = nil
    end
end

-- ── Persistence (oxmysql) ────────────────────────────────────────────────────
local function ensureSchema()
    if not hasDb() then
        Utils.mbtWarn('prop_position_editor ~ oxmysql not started; position saving disabled')
        return
    end
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS mbt_malisling_positions (
            scope VARCHAR(48) NOT NULL,
            wtype VARCHAR(48) NOT NULL,
            data  LONGTEXT NOT NULL,
            PRIMARY KEY (scope, wtype)
        )
    ]], {}, function()
        -- Widen wtype for tables created before per-variant sling wtypes (was VARCHAR(16)
        -- → long variant ids truncated). Idempotent.
        exports.oxmysql:execute('ALTER TABLE mbt_malisling_positions MODIFY COLUMN wtype VARCHAR(48) NOT NULL', {})
        exports.oxmysql:execute('SELECT scope, wtype, data FROM mbt_malisling_positions', {}, function(rows)
            if type(rows) ~= 'table' then return end
            for _, row in ipairs(rows) do
                local ok, data = pcall(json.decode, row.data)
                if ok and validWtype(row.wtype) and validData(data) then
                    local clean = sanitize(data)
                    applyServer(row.scope, row.wtype, clean)
                    rememberSaved(row.scope, row.wtype, clean)
                end
            end
            Utils.mbtDebugger('prop_position_editor ~ loaded', #rows, 'position rows from DB')
        end)
    end)
end

-- ── NUI/admin events (ACE-checked) ───────────────────────────────────────────
RegisterNetEvent('mbt_malisling:propPos:save', function(payload)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then Utils.mbtWarn('propPos:save ~ ACE denied for', src); return end
    if type(payload) ~= 'table' then Utils.mbtWarn('propPos:save ~ payload not a table'); return end
    local scope, wtype, data = payload.scope, payload.wtype, payload.data
    if type(scope) ~= 'string' or not scope:match('^[%w_%-]+$') or #scope > 48 then Utils.mbtWarn('propPos:save ~ bad scope:', tostring(scope)); return end
    if not validWtype(wtype) then Utils.mbtWarn('propPos:save ~ bad wtype:', tostring(wtype)); return end
    if not validData(data) then Utils.mbtWarn('propPos:save ~ validData FAILED; data=', json.encode(data)); return end
    data = sanitize(data)
    applyServer(scope, wtype, data)
    rememberSaved(scope, wtype, data)
    if hasDb() then
        exports.oxmysql:execute(
            'INSERT INTO mbt_malisling_positions (scope, wtype, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
            { scope, wtype, json.encode(data) })
    end
    TriggerClientEvent('mbt_malisling:propPos:apply', -1, { scope = scope, wtype = wtype, data = data })
    Utils.mbtDebugger('propPos saved by', src, scope, wtype)
end)

RegisterNetEvent('mbt_malisling:propPos:reset', function(payload)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if type(payload) ~= 'table' then return end
    local scope, wtype = payload.scope, payload.wtype
    if type(scope) ~= 'string' or not scope:match('^[%w_%-]+$') or #scope > 48 or not validWtype(wtype) then return end
    resetServer(scope, wtype)
    saved[savedKey(scope, wtype)] = nil
    if hasDb() then
        exports.oxmysql:execute('DELETE FROM mbt_malisling_positions WHERE scope = ? AND wtype = ?', { scope, wtype })
    end
    -- default scope → send the restored config default; job scope → send a remove
    -- signal (clients drop the override and fall back to default).
    local out = (scope == 'default') and MBT.PropInfo[wtype] or false
    TriggerClientEvent('mbt_malisling:propPos:apply', -1, { scope = scope, wtype = wtype, data = out })
    Utils.mbtDebugger('propPos reset by', src, scope, wtype)
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ensureSchema()
end)
