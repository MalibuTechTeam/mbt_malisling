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

--- Resolve the ammo item to share for the held weapon. Uses the inventory bridge's
--- getAmmoItemName (ox: weapon `ammoname`; qb: weapon `ammotype` → `<type>_ammo`) to
--- find the exact compatible ammo item; falls back to the giver's largest ammo
--- stack (name starting 'ammo', ox-style). Returns (itemName, availableCount).
local function resolveAmmo(src, heldWeapon)
    local items = Inventory:GetInventoryItems(src)
    if type(items) ~= 'table' then return nil end

    local prefer = (getAmmoItemName and heldWeapon) and getAmmoItemName(heldWeapon) or nil
    local preferLc = prefer and prefer:lower() or nil

    local bestName, bestCount = nil, 0
    for _, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string' and (item.count or 0) > 0 then
            local nm = item.name
            -- Exact match on the weapon's ammo item (case-insensitive).
            if preferLc and nm:lower() == preferLc then return nm, item.count end
            -- Fallback heuristic: any 'ammo'-prefixed item (ox), pick the biggest.
            if nm:sub(1, 4):lower() == 'ammo' and item.count > bestCount then
                bestName, bestCount = nm, item.count
            end
        end
    end
    if bestName then return bestName, bestCount end
    return nil
end

--- How much shareable ammo the giver has for their held weapon (drives the picker).
lib.callback.register('mbt_malisling:ammo:available', function(src, weapon)
    if not cfg.Enabled then return { ok = false } end
    local name, have = resolveAmmo(src, weapon)
    if not name or (have or 0) < 1 then return { ok = false } end
    return { ok = true, have = have, item = name }
end)

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
    -- Honour the requested amount (from the picker), re-clamped server-side to what
    -- the giver actually has. Falls back to ShareAmount when none was sent.
    local want   = tonumber(data.amount) or (cfg.ShareAmount or 30)
    local amount = math.max(1, math.min(math.floor(want), have))
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
    -- The giver may have dropped while an offer they made is still pending under the TARGET's key.
    for target, offer in pairs(pending) do
        if offer.from == s then
            pending[target] = nil
            TriggerClientEvent('mbt_malisling:ammo:expired', target)
        end
    end
end)
