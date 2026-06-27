if GetResourceState('qb-inventory') ~= 'started' or GetResourceState('ox_inventory') == 'started' then return end

if GetResourceState('qb-core') ~= 'started' then
    Utils.mbtWarn("mbt_malisling: qb-inventory requires qb-core to be running.")
    return
end

-- QBCore set up by bridge/qb/server.lua (loads first: bridge/ < inventory/).

-- ── Integration warnings (admin dashboard chips) ──
-- qb-weapons' weapdraw.lua breaks the weapon-on-back sling. Detect at RUNTIME by reading
-- qb-weapons' fxmanifest and checking whether weapdraw is still wired in.
local function qbWeapdrawActive()
    if GetResourceState('qb-weapons') ~= 'started' then return false end
    local manifest = LoadResourceFile('qb-weapons', 'fxmanifest.lua')
    if not manifest then return true end  -- unreadable → assume qb default (weapdraw on)
    for line in manifest:gmatch('[^\r\n]+') do
        if line:gsub('%-%-.*$', ''):find('weapdraw') then return true end   -- strip trailing comment first
    end
    return false  -- weapdraw not loaded (commented out or removed)
end

-- Warning provider the config module merges into openAdmin. Lives here so it only
-- exists on qb-inventory setups; ox never sees it.
MBT.IntegrationWarnings = MBT.IntegrationWarnings or {}
MBT.IntegrationWarnings[#MBT.IntegrationWarnings + 1] = function()
    if qbWeapdrawActive() then
        return {
            code = 'qb_weapdraw',
            msg  = 'qb-weapons weapdraw is active — disable weapdraw.lua for correct holster/switch animations.',
        }
    end
end

-- qb stores info.attachments as { { component = <GTA hash/name> }, ... }; the slung-prop
-- renderer wants metadata.components = { '<ox key>', ... } into MBT.WeaponsInfo.Components.
-- Reverse-map so accessories show on qb too (mirrors the client bridge helper).
local function qbAttachmentsToComponents(attachments)
    if type(attachments) ~= 'table' or not next(attachments) then return nil end
    local comps = MBT.WeaponsInfo and MBT.WeaponsInfo.Components
    if not comps then return nil end
    local out = {}
    for _, att in pairs(attachments) do
        local c = type(att) == 'table' and att.component or att
        if c then
            local hash = type(c) == 'string' and joaat(c) or c
            for key, def in pairs(comps) do
                local list = def.client and def.client.component
                if list then
                    for _, gh in ipairs(list) do
                        if gh == hash then out[#out + 1] = key; break end
                    end
                end
            end
        end
    end
    return out[1] and out or nil
end

-- ── Normalisation helper ──
-- Maps qb-inventory item fields to the ox_inventory-compatible names core/server.lua expects.
local function normalizeItem(item)
    if not item then return nil end
    local info = item.info or {}
    local metadata = {}
    for k, v in pairs(info) do metadata[k] = v end
    -- qb uses .quality (0-100) for durability and .serie for serial
    metadata.durability = metadata.durability or info.quality
    metadata.serial     = metadata.serial     or info.serie
    metadata.components = metadata.components or qbAttachmentsToComponents(info.attachments)
    -- qb item names are LOWERCASE; MBT/WeaponsInfo/ox are uppercase. Canonicalize for lookup,
    -- keep the raw qb name for qb-inventory export calls.
    local rawName = item.name
    local name = rawName
    if type(rawName) == 'string' and rawName:sub(1, 7):upper() == 'WEAPON_' then
        name = rawName:upper()
    end
    return {
        name     = name,
        rawName  = rawName,
        count    = item.amount,
        slot     = item.slot,
        metadata = metadata,
        label    = item.label or item.name,
    }
end

-- qb-inventory item names are always lowercase → lower any name MBT passes
-- (weapon names arrive uppercase; this maps them back for qb).
local function qbName(name) return type(name) == 'string' and name:lower() or name end

-- ── Global inventory interface ──
Inventory = {}

---Mimics ox_inventory:GetSlot(source, slot)
function Inventory:GetSlot(source, slot)
    local item = exports['qb-inventory']:GetItemBySlot(tonumber(source), tonumber(slot))
    return normalizeItem(item)
end

---Mimics ox_inventory:RemoveItem(source, name, count, metadata, slot)
function Inventory:RemoveItem(source, name, count, _, slot)
    return exports['qb-inventory']:RemoveItem(tonumber(source), qbName(name), count, slot) ~= false
end

---Mimics ox_inventory:GetInventoryItems(source) — keyed by SLOT, not name, so two
---weapons of the same name with distinct serials don't collapse (pat-down, custody, ammo, multi).
function Inventory:GetInventoryItems(source)
    local Player = QBCore.Functions.GetPlayer(tonumber(source))
    if not Player then return {} end
    local result = {}
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item.name and item.amount and item.amount > 0 then
            result[item.slot] = normalizeItem(item)
        end
    end
    return result
end

---Mimics ox_inventory:SetMetadata via qb-inventory's SetItemData (no destructive remove+re-add).
function Inventory:SetMetadata(source, slot, metadata)
    local item = exports['qb-inventory']:GetItemBySlot(tonumber(source), tonumber(slot))
    if not item then return false end
    -- Merge into qb-style info, preserving untouched fields
    local newInfo = item.info or {}
    for k, v in pairs(metadata) do newInfo[k] = v end
    -- Sync normalized fields back to qb names
    if metadata.durability then newInfo.quality = metadata.durability end
    if metadata.serial     then newInfo.serie   = metadata.serial     end
    return exports['qb-inventory']:SetItemData(tonumber(source), item.name, 'info', newInfo, tonumber(slot)) ~= false
end

---Mimics ox_inventory:AddItem — returns success boolean. Used by GroundDrop to hand a looted weapon back.
function Inventory:AddItem(source, name, count, metadata)
    local info = {}
    if type(metadata) == 'table' then
        for k, v in pairs(metadata) do info[k] = v end
        -- Denormalize ox-style names back to qb's
        if metadata.durability then info.quality = metadata.durability end
        if metadata.serial     then info.serie   = metadata.serial     end
    end
    return exports['qb-inventory']:AddItem(tonumber(source), qbName(name), count, false, info) ~= false
end

-- ── Flashlight state persistence ──
-- Stores flashlight on/off into item.info.flashlightState on holster.
AddStateBagChangeHandler('WeaponFlashlightState', nil, function(bagName, key, value)
    if not value then return end
    -- gsub returns (string, count); assign first so the count isn't passed to tonumber as a base.
    local netId        = bagName:gsub('player:', '')
    local playerSource = tonumber(netId)
    if not playerSource then return end

    for slot, payload in pairs(value) do
        local item = exports['qb-inventory']:GetItemBySlot(playerSource, tonumber(slot))
        if item then
            local newInfo = item.info or {}
            -- Serial guard: only write if the gun in this slot is still the one the state was
            -- captured for (slot may have been refilled), else one weapon's torch leaks onto another.
            local serial = newInfo.serial or newInfo.serie
            if not (payload.Serial and serial and serial ~= payload.Serial) then
                newInfo.flashlightState = payload.FlashlightState == true
                exports['qb-inventory']:SetItemData(playerSource, item.name, 'info', newInfo, tonumber(slot))
            end
        end
    end
end)

-- ── Ammo item resolution (qb) ──
-- Map weapon `ammotype` (AMMO_PISTOL) → loose ammo item name (`<type>_ammo`); used by Ammo Sharing.
-- NB: if your server RENAMED its ammo items (not the qb-core defaults below), EXTEND this map
-- with your names or the share can't find the right stack. (See README qb section.)
local QB_AMMO = {
    ['AMMO_PISTOL']  = 'pistol_ammo',
    ['AMMO_SMG']     = 'smg_ammo',
    ['AMMO_RIFLE']   = 'rifle_ammo',
    ['AMMO_MG']      = 'mg_ammo',
    ['AMMO_SHOTGUN'] = 'shotgun_ammo',
    ['AMMO_SNIPER']  = 'snp_ammo',
}

---Ammo item name for a weapon, from its qb ammotype.
---@param weaponName string  canonical WEAPON_ name
---@return string|nil
function getAmmoItemName(weaponName)
    local shared = QBCore and QBCore.Shared and QBCore.Shared.Weapons
    local w = shared and (shared[joaat(weaponName)] or shared[weaponName:lower()])
    local at = w and w.ammotype
    return at and QB_AMMO[at] or nil
end

-- ── Weapon data fallback ───────────────────────────────────────────────────────
function loadInventoryWeaponsData()
    local file  = LoadResourceFile(GetCurrentResourceName(), 'data/weapons_fallback.lua')
    local chunk = assert(load(file, '@@mbt_malisling/data/weapons_fallback.lua'))
    return chunk()
end
