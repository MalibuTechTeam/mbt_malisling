if GetResourceState('qb-inventory') ~= 'started' or GetResourceState('ox_inventory') == 'started' then return end

if GetResourceState('qb-core') ~= 'started' then
    Utils.mbtWarn("mbt_malisling: qb-inventory requires qb-core to be running.")
    return
end

-- QBCore is set up by modules/bridge/qb/server.lua which loads first (bridge/ < inventory/)

-- ── Integration warnings (admin dashboard chips) ───────────────────────────────
-- qb-weapons' client/weapdraw.lua animates every weapon swap through UNARMED, which
-- breaks the weapon-on-back sling. Detect at RUNTIME (no user config): read qb-weapons'
-- fxmanifest and check whether weapdraw is still wired in. If the owner commented it
-- out, the manifest read shows it's gone → no warning.
local function qbWeapdrawActive()
    if GetResourceState('qb-weapons') ~= 'started' then return false end
    local manifest = LoadResourceFile('qb-weapons', 'fxmanifest.lua')
    if not manifest then return true end  -- running but manifest unreadable → assume qb default (weapdraw on)
    for line in manifest:gmatch('[^\r\n]+') do
        -- strip any trailing `-- comment`, then look for an active weapdraw reference
        if line:gsub('%-%-.*$', ''):find('weapdraw') then return true end
    end
    return false  -- weapdraw not loaded (commented out or removed)
end

-- Register a warning provider the config module merges into the openAdmin payload.
-- Lives here (qb bridge) so it only exists on qb-inventory setups; ox never sees it.
MBT.IntegrationWarnings = MBT.IntegrationWarnings or {}
MBT.IntegrationWarnings[#MBT.IntegrationWarnings + 1] = function()
    if qbWeapdrawActive() then
        return {
            code = 'qb_weapdraw',
            msg  = 'qb-weapons weapdraw is active — disable weapdraw.lua for correct holster/switch animations.',
        }
    end
end

-- qb-weapons stores attachments in info.attachments as { { component = <GTA hash
-- or name> }, ... }. The slung-prop renderer (core applyAttachments) expects
-- metadata.components = { '<ox item key>', ... } indexing MBT.WeaponsInfo.Components
-- (each key's client.component is a list of GTA hashes). Reverse-map so the slung
-- prop shows accessories on qb too (mirrors the client bridge helper).
local function qbAttachmentsToComponents(attachments)
    if type(attachments) ~= 'table' then return nil end
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

-- ── Normalisation helper ───────────────────────────────────────────────────────
-- Maps qb-inventory item field names to the ox_inventory-compatible field names
-- that core/server.lua and the weapon modules expect.
local function normalizeItem(item)
    if not item then return nil end
    local info = item.info or {}
    local metadata = {}
    for k, v in pairs(info) do metadata[k] = v end
    -- qb uses .quality (0-100) for durability and .serie for serial number
    metadata.durability = metadata.durability or info.quality
    metadata.serial     = metadata.serial     or info.serie
    -- qb attachments → ox-style components list (for slung-prop accessories)
    metadata.components = metadata.components or qbAttachmentsToComponents(info.attachments)
    -- qb weapon item names are LOWERCASE ('weapon_pistol'); MBT + MBT.WeaponsInfo +
    -- ox are uppercase. Canonicalize the name so all weapon logic/lookup matches,
    -- and keep the raw qb name for the qb-inventory export calls.
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

-- qb-inventory item names are always lowercase → safe to lower any name MBT passes
-- (weapon names arrive canonicalized to uppercase; this maps them back for qb).
local function qbName(name) return type(name) == 'string' and name:lower() or name end

-- ── Global inventory interface ─────────────────────────────────────────────────
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

---Mimics ox_inventory:GetInventoryItems(source) — returns a table keyed by SLOT
---(not by item name: two weapons of the same name with distinct serials must NOT
---collapse into one — needed by pat-down, serial sweep, custody, ammo, multi-weapon).
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

---Mimics ox_inventory:SetMetadata(source, slot, metadata)
---Uses qb-inventory's SetItemData export (no destructive remove+re-add needed)
function Inventory:SetMetadata(source, slot, metadata)
    local item = exports['qb-inventory']:GetItemBySlot(tonumber(source), tonumber(slot))
    if not item then return false end
    -- Merge new metadata back to qb-style info, preserving fields we don't touch
    local newInfo = item.info or {}
    for k, v in pairs(metadata) do newInfo[k] = v end
    -- Sync normalized fields back to qb field names
    if metadata.durability then newInfo.quality = metadata.durability end
    if metadata.serial     then newInfo.serie   = metadata.serial     end
    return exports['qb-inventory']:SetItemData(tonumber(source), item.name, 'info', newInfo, tonumber(slot)) ~= false
end

---Mimics ox_inventory:AddItem(source, name, count, metadata) — returns success boolean.
---Used by the GroundDrop system to hand a looted weapon back to the player.
function Inventory:AddItem(source, name, count, metadata)
    local info = {}
    if type(metadata) == 'table' then
        for k, v in pairs(metadata) do info[k] = v end
        -- Denormalize ox-style field names back to qb's
        if metadata.durability then info.quality = metadata.durability end
        if metadata.serial     then info.serie   = metadata.serial     end
    end
    return exports['qb-inventory']:AddItem(tonumber(source), qbName(name), count, false, info) ~= false
end

-- ── Flashlight state persistence ───────────────────────────────────────────────
-- Stores flashlight on/off state into item.info.flashlightState when player holsters.
AddStateBagChangeHandler('WeaponFlashlightState', nil, function(bagName, key, value)
    if not value then return end
    -- gsub returns (string, count); assign first so the count isn't passed to
    -- tonumber as a (out-of-range) base.
    local netId        = bagName:gsub('player:', '')
    local playerSource = tonumber(netId)
    if not playerSource then return end

    for slot, payload in pairs(value) do
        local item = exports['qb-inventory']:GetItemBySlot(playerSource, tonumber(slot))
        if item then
            local newInfo = item.info or {}
            -- Serial guard: only write the flashlight state if the gun in this slot is
            -- still the same one the state was captured for (slot may have been refilled
            -- with a different weapon) — otherwise one weapon's torch leaks onto another.
            local serial = newInfo.serial or newInfo.serie
            if not (payload.Serial and serial and serial ~= payload.Serial) then
                newInfo.flashlightState = payload.FlashlightState == true
                exports['qb-inventory']:SetItemData(playerSource, item.name, 'info', newInfo, tonumber(slot))
            end
        end
    end
end)

-- ── Ammo item resolution (qb) ──────────────────────────────────────────────────
-- qb weapons carry an `ammotype` (e.g. AMMO_PISTOL); the loose ammo items are named
-- `<type>_ammo`. Map ammotype → qb ammo item name. (qb-core/shared/weapons.lua +
-- shared/items.lua.) Used by Ammo Sharing.
-- NB (qb only): Ammo Sharing matches the giver's ammo by these item names. If your server
-- RENAMED its ammo items (not the qb-core defaults below), EXTEND this map with your names,
-- otherwise the share can't find the right stack. (Documented in the README qb section.)
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
