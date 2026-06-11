-- ─────────────────────────────────────────────────────────────────────────────
-- Chain of Custody (Forensics) — server
--
-- A server-side ledger of who has carried each weapon, keyed by the weapon's
-- SERIAL. Deliberately NOT stored in the item metadata: writing metadata on the
-- equip path re-fires ox_inventory:updateInventory, which the sling system reacts
-- to by re-spawning the slung prop while the weapon is in hand (visual bug).
--
-- Optionally persisted to a self-managed oxmysql table `mbt_weapon_custody`
-- (documented "no DB" exception, feature-gated on oxmysql). Without oxmysql the
-- ledger is in-memory only (resets on restart). The Inspect overlay reads a
-- weapon's chain via the `mbt_malisling:getCustody` callback (by serial).
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ChainOfCustody or not MBT.ChainOfCustody.Enabled then return end

local hasDb   = GetResourceState('oxmysql') == 'started'
local custody = {}   -- [serial] = { { name, id, at }, ... } (oldest first)

if hasDb then
    CreateThread(function()
        exports.oxmysql:execute([[
            CREATE TABLE IF NOT EXISTS mbt_weapon_custody (
                serial VARCHAR(64) NOT NULL,
                chain  LONGTEXT NOT NULL,
                PRIMARY KEY (serial)
            )
        ]], {})
        local rows = exports.oxmysql:executeSync('SELECT serial, chain FROM mbt_weapon_custody', {})
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
        'INSERT INTO mbt_weapon_custody (serial, chain) VALUES (?, ?) ON DUPLICATE KEY UPDATE chain = VALUES(chain)',
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

--- Called from core/server.lua AFTER the sling sync with the player's slung
--- weapons. Records the holder for each weapon that has a serial. Weapons WITHOUT
--- one get a deferred background repair (EnsureSerial, well off the equip path) so
--- admin-given/legacy guns join the forensic loop instead of silently skipping it.
---@param source number
---@param playerWeapons table
function MBT.ChainOfCustody.RecordHolders(source, playerWeapons)
    if type(playerWeapons) ~= 'table' then return end
    local missing = nil
    for _, v in pairs(playerWeapons) do
        if type(v) == 'table' and v.metadata and v.metadata.serial then
            record(source, v.metadata.serial)
        elseif type(v) == 'table' and type(v.name) == 'string' then
            missing = missing or {}
            missing[v.name] = true
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
    if not MBT.ChainOfCustody.ShowInInspect then return {} end
    if type(serial) ~= 'string' then return {} end
    return custody[serial] or {}
end)
