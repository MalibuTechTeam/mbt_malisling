-- ─────────────────────────────────────────────────────────────────────────────
-- Custom Weapon Name — server
-- Validates permission + sanitizes, then writes metadata.label on the slot's weapon
-- via the Inventory abstraction (ox + qb). Permission/limits config-driven.
-- ─────────────────────────────────────────────────────────────────────────────

-- Enabled checked at use time (live-apply via menu).
if not MBT.WeaponName then return end

local cfg = MBT.WeaponName
local lastUse = {}  -- [src] = GetGameTimer(), basic rate limit

--- Is this player allowed to rename, per the configured permission model?
local function isAllowed(src)
    local mode = cfg.Permission or 'everyone'
    if mode == 'everyone' then return true end
    if mode == 'ace' then
        return IsPlayerAceAllowed(src, cfg.AcePermission or 'mbt.weaponname')
    end
    if mode == 'job' then
        return playerHasAnyJob(src, cfg.Jobs)   -- global from modules/bridge/jobs.lua
    end
    return false
end

--- Trim, strip control chars/newlines, clamp length. Returns nil if empty.
local function sanitize(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('[%c]', '')                    -- strip control chars + newlines
    name = name:gsub('^%s+', ''):gsub('%s+$', '')   -- trim
    if name == '' then return nil end
    local max = cfg.MaxLength or 24
    if #name > max then name = name:sub(1, max) end
    return name
end

RegisterNetEvent('mbt_malisling:setWeaponName', function(slot, rawName)
    local src = source
    if not cfg.Enabled then return end
    if type(slot) ~= 'number' then return end

    -- Rate limit (input dialog spam / scripted abuse).
    local now = GetGameTimer()
    if lastUse[src] and (now - lastUse[src]) < 1000 then return end
    lastUse[src] = now

    if not isAllowed(src) then
        TriggerClientEvent("mbt_malisling:notifyLabel", src, 'wname_no_perm')
        return
    end

    local name = sanitize(rawName)
    if not name then return end

    local item = Inventory:GetSlot(src, slot)
    if not item or type(item.name) ~= 'string' or item.name:sub(1, 7) ~= 'WEAPON_' then
        TriggerClientEvent("mbt_malisling:notifyLabel", src, 'wname_no_weapon')
        return
    end

    local metadata = item.metadata or {}
    if cfg.OncePerWeapon and metadata.label and metadata.label ~= '' then
        TriggerClientEvent("mbt_malisling:notifyLabel", src, 'wname_locked')
        return
    end

    metadata.label = name
    Inventory:SetMetadata(src, slot, metadata)
    TriggerClientEvent("mbt_malisling:notifyLabel", src, 'wname_done')
end)

AddEventHandler('playerDropped', function()
    if source then lastUse[source] = nil end
end)
