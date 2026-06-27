-- ─────────────────────────────────────────────────────────────────────────────
-- Physical Weapon Handoff — server
-- Giver offers the weapon they're HOLDING; receiver accepts/declines. On accept
-- the item moves atomically (RemoveItem→AddItem, with rollback) carrying full
-- metadata (serial/condition/name). One pending offer per receiver; offers
-- expire. All checks server-side.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.Handoff then return end

local cfg     = MBT.Handoff
local pending = {}   -- [receiverSrc] = { from, slot, name, count, expires }
local lastUse = {}   -- [src] = GetGameTimer() (rate limit)

local function maxDist() return (cfg.MaxDistance or 2.5) + 2.0 end

--- The item in the giver's slot, only if it's still the weapon they offered.
local function slotWeapon(src, slot, name, serial)
    local item = Inventory:GetSlot(src, slot)
    if not item or item.name ~= name then return nil end
    if type(item.name) ~= 'string' or item.name:sub(1, 7) ~= 'WEAPON_' then return nil end
    -- Anti bait-and-switch: if the offer carried a serial, the slot must STILL hold
    -- that exact weapon (else a giver swaps a same-name gun with a different serial).
    if serial ~= nil and (not item.metadata or item.metadata.serial ~= serial) then return nil end
    return item
end

-- ── Offer ───────────────────────────────────────────────────────────────────────
RegisterNetEvent('mbt_malisling:handoff:offer', function(data)
    local src = source
    if not cfg.Enabled or type(data) ~= 'table' then return end

    local now = GetGameTimer()
    if lastUse[src] and (now - lastUse[src]) < 1500 then return end
    lastUse[src] = now

    local target = tonumber(data.target)
    local slot   = tonumber(data.slot)
    if not target or not slot or target == src then return end
    if not GetPlayerName(target) then return end                  -- online?
    if pending[target] then return end                            -- busy with an offer

    local pedA, pedB = GetPlayerPed(src), GetPlayerPed(target)
    if pedA == 0 or pedB == 0 then return end
    if #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) > maxDist() then
        TriggerClientEvent('mbt_malisling:handoff:result', src, 'handoff_no_target'); return
    end

    local item = slotWeapon(src, slot, data.name)
    if not item then return end

    pending[target] = {
        from = src, slot = slot, name = item.name, count = item.count,
        serial = item.metadata and item.metadata.serial,
        expires = now + (cfg.RequestTimeoutMs or 8000),
    }
    local md = item.metadata or {}
    TriggerClientEvent('mbt_malisling:handoff:incoming', target, {
        fromName  = GetPlayerName(src),
        fromId    = src,
        weapon    = item.name,
        label     = md.label,            -- engraved custom name, if any
        serial    = md.serial,
        timeoutMs = cfg.RequestTimeoutMs or 8000,
    })
    TriggerClientEvent('mbt_malisling:handoff:result', src, 'handoff_sent')
end)

-- ── Respond ─────────────────────────────────────────────────────────────────────
lib.callback.register('mbt_malisling:handoff:respond', function(src, accept)
    local offer = pending[src]
    pending[src] = nil
    if not offer then return { ok = false } end
    if GetGameTimer() > offer.expires then return { ok = false } end

    local giver = offer.from
    if not accept then
        TriggerClientEvent('mbt_malisling:handoff:result', giver, 'handoff_declined')
        return { ok = true, declined = true }
    end

    -- Re-validate everything at accept time.
    local pedA, pedB = GetPlayerPed(giver), GetPlayerPed(src)
    if pedA == 0 or pedB == 0
        or #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) > maxDist() then
        TriggerClientEvent('mbt_malisling:handoff:result', giver, 'handoff_failed')
        return { ok = false }
    end
    local item = slotWeapon(giver, offer.slot, offer.name, offer.serial)
    if not item then
        TriggerClientEvent('mbt_malisling:handoff:result', giver, 'handoff_failed')
        return { ok = false }
    end

    -- Forensic backbone: a weapon changing hands always gets a serial first.
    if MBT.EnsureSerial then MBT.EnsureSerial(giver, item) end

    -- Atomic move with rollback: the weapon must never vanish.
    local meta = item.metadata
    if not Inventory:RemoveItem(giver, item.name, item.count, nil, item.slot) then
        TriggerClientEvent('mbt_malisling:handoff:result', giver, 'handoff_failed')
        return { ok = false }
    end
    if not Inventory:AddItem(src, item.name, item.count, meta) then
        Inventory:AddItem(giver, item.name, item.count, meta)   -- rollback
        TriggerClientEvent('mbt_malisling:handoff:result', giver, 'handoff_failed')
        return { ok = false, reason = 'handoff_inv_full' }
    end

    -- Synced give/take gesture on both peds (each client faces the other).
    TriggerClientEvent('mbt_malisling:handoff:anim', giver, { role = 'give', other = src })
    TriggerClientEvent('mbt_malisling:handoff:anim', src,   { role = 'take', other = giver })
    TriggerClientEvent('mbt_malisling:handoff:result', giver, 'handoff_done')

    -- Optional equip-on-accept. ox: hand the receiver the exact slot to useSlot.
    -- qb: return name+serial so the client can find the item and use it.
    local equipSlot
    if cfg.EquipOnAccept and GetResourceState('ox_inventory') == 'started' then
        local ok2, s = pcall(function()
            return exports.ox_inventory:GetSlotIdWithItem(src, item.name,
                { serial = meta and meta.serial }, true)
        end)
        if ok2 then equipSlot = s end
    end
    return { ok = true, equipSlot = equipSlot, name = item.name, serial = meta and meta.serial }
end)

-- ── Expiry sweep ─────────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(2000)
        local now = GetGameTimer()
        for receiver, offer in pairs(pending) do
            if now > offer.expires then
                pending[receiver] = nil
                TriggerClientEvent('mbt_malisling:handoff:expired', receiver)
                TriggerClientEvent('mbt_malisling:handoff:result', offer.from, 'handoff_declined')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local s = source
    if not s then return end
    lastUse[s] = nil
    pending[s] = nil
    for receiver, offer in pairs(pending) do
        if offer.from == s then
            pending[receiver] = nil
            TriggerClientEvent('mbt_malisling:handoff:expired', receiver)
        end
    end
end)
