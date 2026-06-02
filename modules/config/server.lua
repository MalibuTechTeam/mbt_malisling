-- ─────────────────────────────────────────────────────────────────────────────
-- Admin config — server
--
-- Powers the admin dashboard (modules/admin NUI). On /mbtconfig the server ACE-
-- checks the player and sends a full config snapshot; on save it validates,
-- applies live to MBT.* on every client (broadcast), and persists the runtime-safe
-- fields to runtime_config.json so they survive a restart.
--
-- Built per-section so new sections plug in by extending snapshot()/applyGeneral
-- etc. Phase 1 wires the General section end-to-end; more sections follow.
-- ─────────────────────────────────────────────────────────────────────────────

local CONFIG_FILE     = 'data/runtime_config.json'
local VALID_POSITIONS = { ['bottom-center'] = true, ['top-center'] = true, ['bottom-right'] = true }
local adminCommand    = (MBT.Admin and MBT.Admin.Command) or 'mbtconfig'
-- Default to the command's own ACE so a server with the usual
-- `add_ace group.admin command.* allow` (or a wildcard admin principal) works
-- with NO extra server.cfg lines — same as mbt_elevator.
local adminPerm       = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)

-- ── Snapshot: the config the dashboard reads (full state, incl. overview flags) ──
local function snapshot()
    return {
        -- General (editable)
        Debug             = MBT.Debug and true or false,
        EnableSling       = MBT.EnableSling and true or false,
        EnableFlashlight  = MBT.EnableFlashlight and true or false,
        DropWeaponOnDeath = MBT.DropWeaponOnDeath and true or false,
        UIPosition        = MBT.UI.Position,
        Language          = MBT.Language,            -- read-only in the UI
        -- Overview flags (read-only summary; editable in their own sections later)
        SuppressorHeat    = { Enabled = MBT.SuppressorHeat and MBT.SuppressorHeat.Enabled or false },
        Inspect           = { Enabled = MBT.Inspect and MBT.Inspect.Enabled or false },
        Safety            = { Enabled = MBT.Safety and MBT.Safety.Enabled or false },
        NoDrawZones       = { Enabled = MBT.NoDrawZones and MBT.NoDrawZones.Enabled or false },
        WeaponDrop        = { Logging = { Enabled = MBT.WeaponDrop and MBT.WeaponDrop.Logging and MBT.WeaponDrop.Logging.Enabled or false } },
        TacticalSling     = { Enabled = MBT.TacticalSling and MBT.TacticalSling.Enabled or false },
    }
end

-- ── Validate only the runtime-safe (editable) fields ─────────────────────────────
local function validate(d)
    if type(d) ~= 'table' then return false end
    if type(d.Debug) ~= 'boolean' then return false end
    if type(d.EnableSling) ~= 'boolean' then return false end
    if type(d.EnableFlashlight) ~= 'boolean' then return false end
    if type(d.DropWeaponOnDeath) ~= 'boolean' then return false end
    if type(d.UIPosition) ~= 'string' or not VALID_POSITIONS[d.UIPosition] then return false end
    return true
end

-- ── Apply the editable fields to MBT.* (server side) ─────────────────────────────
local function applyToMBT(d)
    MBT.Debug             = d.Debug
    MBT.EnableSling       = d.EnableSling
    MBT.EnableFlashlight  = d.EnableFlashlight
    MBT.DropWeaponOnDeath = d.DropWeaponOnDeath
    MBT.UI.Position       = d.UIPosition
end

--- Only the editable subset is persisted (overview flags belong to their sections).
local function persistable(d)
    return {
        Debug             = d.Debug,
        EnableSling       = d.EnableSling,
        EnableFlashlight  = d.EnableFlashlight,
        DropWeaponOnDeath = d.DropWeaponOnDeath,
        UIPosition        = d.UIPosition,
    }
end

local function loadRuntimeConfig()
    local raw = LoadResourceFile(GetCurrentResourceName(), CONFIG_FILE)
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or not validate(data) then
        Utils.mbtWarn('runtime_config.json invalid or from an old format, ignoring')
        return
    end
    applyToMBT(data)
    Utils.mbtDebugger('Runtime config loaded from', CONFIG_FILE)
end

--- Send the dashboard to an authorized admin.
local function openFor(src)
    TriggerClientEvent('mbt_malisling:openAdmin', src, {
        config  = snapshot(),
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'v2',
    })
end

-- Command registered SERVER-side (like mbt_elevator) so FiveM auto-registers its
-- ACE — a wildcard admin principal then works with no extra server.cfg lines.
RegisterCommand(adminCommand, function(source)
    if source == 0 then return end  -- console
    if IsPlayerAceAllowed(source, adminPerm) then
        openFor(source)
    else
        TriggerClientEvent('mbt_malisling:notifyLabel', source, 'admin_no_perm')
    end
end, false)

-- Keybind / client request path — server re-validates ACE.
RegisterNetEvent('mbt_malisling:requestConfig', function()
    local src = source
    if IsPlayerAceAllowed(src, adminPerm) then openFor(src) end
end)

RegisterNetEvent('mbt_malisling:adminSave', function(data)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if not validate(data) then
        Utils.mbtWarn('adminSave ~ invalid payload from player', src)
        return
    end
    applyToMBT(data)
    SaveResourceFile(GetCurrentResourceName(), CONFIG_FILE, json.encode(persistable(data)), -1)
    TriggerClientEvent('mbt_malisling:applyConfig', -1, persistable(data))
    Utils.mbtDebugger('Admin config saved by player', src)
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadRuntimeConfig()
end)
