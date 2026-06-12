-- ─────────────────────────────────────────────────────────────────────────────
-- Ammo Sharing — server
--
-- Hand a portion of your ammo to a nearby player. Same offer/consent/transfer
-- shape as the weapon handoff, but moves an ammo item (resolved from the held
-- weapon's ox ammo name, or the giver's largest ammo stack). Atomic with
-- rollback; the receiver consents first. All validation server-side.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.AmmoSharing then return end

local cfg     = MBT.AmmoSharing
local pending = {}   -- [receiverSrc] = { from, item, amount, expires }
local lastUse = {}

local function maxDist() return (cfg.MaxDistance or 2.5) + 2.0 end

--- Resolve the ammo item to share: the held weapon's ox ammo item if the giver
--- has it, else their largest ammo stack. Returns name, available count.
local function resolveAmmo(src, heldWeapon)
    local items = Inventory:GetInventoryItems(src)
    if type(items) ~= 'table' then return nil end

    -- Preferred: the held weapon's ammo item name (ox data field 'ammoname').
    local prefer
    local w = heldWeapon and MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[heldWeapon]
    if w then prefer = w.ammoname or w.ammoName end

    local bestName, bestCount = nil, 0
    for _, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string'
            and item.name:sub(1, 4) == 'ammo' and (item.count or 0) > 0 then
            if prefer and item.name == prefer then return item.name, item.count end
            if item.count > bestCount then bestName, bestCount = item.name, item.count end
        end
    end
    if bestName then return bestName, bestCount end
    return nil
end

RegisterNetEvent('mbt_malisling:ammo:offer', function(data)
    local src = source
    if not cfg.Enabled or type(data) ~= 'table' then return end

    local now = GetGameTimer()
    if lastUse[src] and (now - lastUse[src]) < 1500 then return end
    lastUse[src] = now

    local target = tonumber(data.target)
    if not target or target == src or not GetPlayerName(target) or pending[target] then return end

    local pedA, pedB = GetPlayerPed(src), GetPlayerPed(target)
    if pedA == 0 or pedB == 0 or #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) > maxDist() then
        TriggerClientEvent('mbt_malisling:ammo:result', src, 'ammo_no_target'); return
    end

    local name, have = resolveAmmo(src, data.weapon)
    if not name then TriggerClientEvent('mbt_malisling:ammo:result', src, 'ammo_none'); return end
    local amount = math.min(cfg.ShareAmount or 30, have)
    if amount < 1 then TriggerClientEvent('mbt_malisling:ammo:result', src, 'ammo_none'); return end

    pending[target] = { from = src, item = name, amount = amount, expires = now + (cfg.RequestTimeoutMs or 8000) }
    TriggerClientEvent('mbt_malisling:ammo:incoming', target, {
        fromName = GetPlayerName(src), amount = amount, item = name,
        timeoutMs = cfg.RequestTimeoutMs or 8000,
    })
    TriggerClientEvent('mbt_malisling:ammo:result', src, 'ammo_sent')
end)

lib.callback.register('mbt_malisling:ammo:respond', function(src, accept)
    local offer = pending[src]
    pending[src] = nil
    if not offer or GetGameTimer() > offer.expires then return { ok = false } end
    local giver = offer.from

    if not accept then
        TriggerClientEvent('mbt_malisling:ammo:result', giver, 'ammo_declined')
        return { ok = true }
    end

    local pedA, pedB = GetPlayerPed(giver), GetPlayerPed(src)
    if pedA == 0 or pedB == 0 or #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) > maxDist() then
        return { ok = false }
    end

    -- Atomic with rollback: pull from giver, give to receiver.
    if not Inventory:RemoveItem(giver, offer.item, offer.amount) then
        TriggerClientEvent('mbt_malisling:ammo:result', giver, 'ammo_none')
        return { ok = false }
    end
    if not Inventory:AddItem(src, offer.item, offer.amount) then
        Inventory:AddItem(giver, offer.item, offer.amount)   -- rollback
        TriggerClientEvent('mbt_malisling:ammo:result', giver, 'ammo_full')
        return { ok = false }
    end

    TriggerClientEvent('mbt_malisling:ammo:anim', giver, { role = 'give', other = src })
    TriggerClientEvent('mbt_malisling:ammo:anim', src,   { role = 'take', other = giver })
    TriggerClientEvent('mbt_malisling:ammo:result', giver, 'ammo_done')
    return { ok = true }
end)

CreateThread(function()
    while true do
        Wait(2000)
        local now = GetGameTimer()
        for receiver, offer in pairs(pending) do
            if now > offer.expires then
                pending[receiver] = nil
                TriggerClientEvent('mbt_malisling:ammo:expired', receiver)
                TriggerClientEvent('mbt_malisling:ammo:result', offer.from, 'ammo_declined')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local s = source
    if not s then return end
    lastUse[s] = nil
    pending[s] = nil
end)
