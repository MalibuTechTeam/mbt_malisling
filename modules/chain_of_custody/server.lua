-- ─────────────────────────────────────────────────────────────────────────────
-- Chain of Custody (Forensics) — server
-- Server-side ledger of who carried each weapon, keyed by SERIAL. NOT stored in
-- item metadata on purpose: writing metadata on equip re-fires ox_inventory:
-- updateInventory → sling re-spawns the prop while the weapon is in hand (visual bug).
-- Optionally persisted to self-managed oxmysql `mbt_malisling_custody` (feature-gated;
-- in-memory only without oxmysql). Inspect overlay reads via `mbt_malisling:getCustody`.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ChainOfCustody then return end   -- always register; Enabled is live-checked in the handlers

local hasDb   = GetResourceState('oxmysql') == 'started'
local custody = {}   -- [serial] = { { name, id, at }, ... } (oldest first)

if hasDb then
    -- Chained callbacks, not executeSync: each step must finish before the next (oxmysql
    -- runs on a pool, so fire-and-forget races a fresh DB) but blocking the thread to get
    -- that ordering costs a boot stall that grows with the table.
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS mbt_malisling_custody (
            serial     VARCHAR(64) NOT NULL,
            chain      LONGTEXT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (serial)
        )
    ]], {}, function()
        -- Tables created before updated_at existed. Errors harmlessly once it does.
        exports.oxmysql:execute(
            'ALTER TABLE mbt_malisling_custody ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
            {}, function()
            -- Prune before loading: this is the only table with no natural delete path, so
            -- without it every serial ever issued is read into memory at every boot, forever.
            local days = tonumber(MBT.ChainOfCustody.PruneAfterDays) or 0
            local function load()
                exports.oxmysql:execute('SELECT serial, chain FROM mbt_malisling_custody', {}, function(rows)
                    if type(rows) ~= 'table' then return end
                    for _, row in ipairs(rows) do
                        local ok, data = pcall(json.decode, row.chain)
                        if ok and type(data) == 'table' then custody[row.serial] = data end
                    end
                    Utils.mbtDebugger('chain_of_custody ~ loaded', #rows, 'serials from DB')
                end)
            end
            if days > 0 then
                exports.oxmysql:execute(
                    'DELETE FROM mbt_malisling_custody WHERE updated_at < (NOW() - INTERVAL ? DAY)',
                    { days }, load)
            else
                load()
            end
        end)
    end)
end

local function persist(serial)
    if not hasDb then return end
    exports.oxmysql:execute(
        'INSERT INTO mbt_malisling_custody (serial, chain) VALUES (?, ?) ON DUPLICATE KEY UPDATE chain = VALUES(chain)',
        { serial, json.encode(custody[serial]) })
end

--- Append the current holder to a serial's chain (no-op if already the last one).
local function record(source, serial)
    local name, id = getPlayerName(source)
    if not id then return end
    local chain = type(custody[serial]) == 'table' and custody[serial] or {}

    local last = chain[#chain]
    if last and last.id == id then return end   -- already the most recent holder

    chain[#chain + 1] = { name = name, id = id, at = os.time() }

    -- Cap: always keep the origin (#1) + the most recent (MaxEntries-1).
    local cap = MBT.ChainOfCustody.MaxEntries or 10
    if cap >= 2 and #chain > cap then
        local trimmed = { chain[1] }
        for i = #chain - (cap - 2), #chain do trimmed[#trimmed + 1] = chain[i] end
        chain = trimmed
    end

    custody[serial] = chain
    persist(serial)
end

--- Records the holder for each serialled weapon the player actually carries. Serials are read
--- from the player's REAL server-side inventory, NOT from the client payload — trusting client
--- metadata would let a client append itself to any serial's ledger. Serial-less legacy guns
--- get a deferred EnsureSerial repair off the equip path.
---@param source number
local function doRecord(source)
    local items = Inventory:GetInventoryItems(source)
    if type(items) ~= 'table' then return end
    local missing = nil
    for _, v in pairs(items) do
        if type(v) == 'table' and type(v.name) == 'string' and v.name:sub(1, 7) == 'WEAPON_' then
            if v.metadata and v.metadata.serial then
                record(source, v.metadata.serial)
            else
                missing = missing or {}
                missing[v.name] = true
            end
        end
    end
    if not missing or not MBT.EnsureSerial then return end
    SetTimeout(1200, function()
        if not GetPlayerName(source) then return end
        local items = Inventory:GetInventoryItems(source)
        if type(items) ~= 'table' then return end
        for _, item in pairs(items) do
            if type(item) == 'table' and missing[item.name]
                and not (item.metadata and item.metadata.serial) then
                local serial = MBT.EnsureSerial(source, item)
                if serial then record(source, serial) end
            end
        end
    end)
end

local SETTLE_MS = 1500
local settling  = {}   -- [source] = true while a record is scheduled

--- Called on every sling sync, which is throttled at 100ms — up to ten times a second per
--- player. The DB write is already guarded (`record` no-ops for an unchanged holder), but the
--- inventory read behind it is not, and that is the real cost. Custody is a ledger, not live
--- state: one read per settle window is enough, and it runs at the END of the window so it
--- sees the state the player came to rest in rather than a frame mid-swap.
---@param source number
function MBT.ChainOfCustody.RecordHolders(source)
    if not MBT.ChainOfCustody.Enabled then return end   -- live on/off from the dashboard
    if settling[source] then return end
    settling[source] = true
    SetTimeout(SETTLE_MS, function()
        settling[source] = nil
        if GetPlayerName(source) then doRecord(source) end
    end)
end

AddEventHandler('playerDropped', function() settling[source] = nil end)

--- Inspect overlay → fetch a weapon's chain by serial.
lib.callback.register('mbt_malisling:getCustody', function(_, serial)
    if not MBT.ChainOfCustody.Enabled or not MBT.ChainOfCustody.ShowInInspect then return {} end
    if type(serial) ~= 'string' then return {} end
    return custody[serial] or {}
end)
