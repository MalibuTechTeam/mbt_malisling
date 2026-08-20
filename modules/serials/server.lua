-- ── Weapon Serials — ensure-generation (server) ──
-- Every world weapon gets a metadata.serial: ox covers ox-created weapons, this covers the
-- rest (admin-given, legacy, custom shops).
--
-- SetMetadata re-fires ox_inventory:updateInventory on the owner — the Chain of Custody bug —
-- so: write ONCE per weapon on safe transitions only, never while firing; per-(player,slot)
-- lock with a slot re-read before writing; ox REPLACES the table, so write the full one; and
-- skip count > 1, because stacks are hostile.

if not MBT.Serials then return end

local cfg    = MBT.Serials
local locks  = {}   -- ['src:slot'] = true while a write is in flight
local issued = {}   -- [serial] = true (runtime uniqueness; seeded by every read)
local swept  = {}   -- [src] = true once the on-join sweep ran

local ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

local function generate()
    local s
    repeat
        local b = {}
        for i = 1, 8 do
            local r = math.random(#ALPHABET)
            b[i] = ALPHABET:sub(r, r)
        end
        s = (cfg.Format == 'oxlike') and table.concat(b) or ('MBT-' .. table.concat(b))
    until not issued[s]
    issued[s] = true
    return s
end

--- Ensure the weapon in `item` has a serial; returns it (nil if not ensurable). Safe wherever item is a fresh server read with a .slot — the write only happens after a re-read confirms the slot is unchanged.
---@param src number
---@param item table   server-side item ({ name, slot, count, metadata })
---@return string|nil
function MBT.EnsureSerial(src, item)
    if type(item) ~= 'table' or type(item.name) ~= 'string'
        or item.name:sub(1, 7) ~= 'WEAPON_' then return nil end

    local md = item.metadata
    if md and md.serial then issued[md.serial] = true return md.serial end
    if not cfg.EnsureGeneration then return nil end
    if (item.count or 1) > 1 then
        Utils.mbtDebugger('serials ~ skip stacked weapon', item.name)
        return nil
    end

    local slot = tonumber(item.slot)
    if not slot then return nil end
    local key = src .. ':' .. slot
    if locks[key] then return nil end
    locks[key] = true

    -- Re-read before writing: same weapon, still serial-less? (a parallel hook or
    -- inventory move may have beaten us here)
    local fresh = Inventory:GetSlot(src, slot)
    if not fresh or fresh.name ~= item.name or (fresh.count or 1) > 1 then
        locks[key] = nil
        return nil
    end
    local fmd = fresh.metadata or {}
    if fmd.serial then
        locks[key] = nil
        issued[fmd.serial] = true
        return fmd.serial
    end

    fmd.serial = generate()
    -- Full table back: ox replaces the metadata wholesale; qb merges into info
    -- (and mirrors serial → serie in the bridge).
    Inventory:SetMetadata(src, slot, fmd)
    locks[key] = nil

    -- Keep the caller's copy coherent so it can use the serial immediately.
    item.metadata = item.metadata or {}
    item.metadata.serial = fmd.serial
    return fmd.serial
end

-- ── On-join sweep (deferred background repair) ────────────────────────────────────
--- Walk the player's weapons and ensure serials, gently (one write per 150ms).
local function sweep(src)
    if not cfg.EnsureGeneration or not cfg.SweepOnLoad then return end
    if not GetPlayerName(src) then return end   -- left meanwhile
    local items = Inventory:GetInventoryItems(src)
    if type(items) ~= 'table' then return end
    for _, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string'
            and item.name:sub(1, 7) == 'WEAPON_'
            and not (item.metadata and item.metadata.serial) then
            MBT.EnsureSerial(src, item)
            Wait(150)
            if not GetPlayerName(src) then return end
        end
    end
end

-- First sling sync of a session ≈ "player is in and settled" → sweep a bit later,
-- well off the equip path.
AddEventHandler('mbt_malisling:syncSling', function()
    local src = source
    if not src or src == 0 or swept[src] then return end
    swept[src] = true
    SetTimeout(7500, function() sweep(src) end)
end)

AddEventHandler('playerDropped', function()
    local s = source
    if not s then return end
    swept[s] = nil
    local prefix = s .. ':'
    for k in pairs(locks) do
        if k:sub(1, #prefix) == prefix then locks[k] = nil end
    end
end)
