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
    CreateThread(function()
        -- executeSync (not fire-and-forget execute): the CREATE must COMMIT before
        -- the SELECT below, or a fresh DB races (table-doesn't-exist on first boot).
        exports.oxmysql:executeSync([[
            CREATE TABLE IF NOT EXISTS mbt_malisling_custody (
                serial VARCHAR(64) NOT NULL,
                chain  LONGTEXT NOT NULL,
                PRIMARY KEY (serial)
            )
        ]], {})
        local rows = exports.oxmysql:executeSync('SELECT serial, chain FROM mbt_malisling_custody', {})
        if rows then
            for _, row in ipairs(rows) do
                local ok, data = pcall(json.decode, row.chain)
                if ok and type(data) == 'table' then custody[row.serial] = data end
            end
        end
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

--- Records the holder for each serialled weapon the player actually carries (called after
--- sling sync). Serials are read from the player's REAL server-side inventory, NOT from the
--- client payload — trusting client metadata would let a client append itself to any serial's
--- ledger. Serial-less legacy guns get a deferred EnsureSerial repair off the equip path.
---@param source number
function MBT.ChainOfCustody.RecordHolders(source)
    if not MBT.ChainOfCustody.Enabled then return end   -- live on/off from the dashboard
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

--- Inspect overlay → fetch a weapon's chain by serial.
lib.callback.register('mbt_malisling:getCustody', function(_, serial)
    if not MBT.ChainOfCustody.Enabled or not MBT.ChainOfCustody.ShowInInspect then return {} end
    if type(serial) ~= 'string' then return {} end
    return custody[serial] or {}
end)
