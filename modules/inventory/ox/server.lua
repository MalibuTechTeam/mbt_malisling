if GetResourceState('ox_inventory') ~= 'started' then return end

if not lib.checkDependency('ox_inventory', '2.30.0') then
    Utils.mbtWarn("mbt_malisling has not been tested with this version of ox_inventory!")
end

if GetConvarInt('inventory:weaponanims', 1) == 0 then
    Utils.mbtWarn("You have enabled the sling feature, but you have disabled the weapons animation convar in ox_inventory. This will cause issues with animations and the sling feature. Please set inventory:weaponanims to 1")
end

---Global inventory interface — used by core/server.lua, weapon_drop, weapon_throw
Inventory = exports['ox_inventory']

---Returns the raw weapons data table from ox_inventory's own data file.
---Called by loadWeaponsInfo() in core/server.lua.
function loadInventoryWeaponsData()
    local weaponsFile  = LoadResourceFile("ox_inventory", 'data/weapons.lua')
    local weaponsChunk = assert(load(weaponsFile, '@@ox_inventory/data/weapons.lua'))
    return weaponsChunk()
end

---Ammo item name for a weapon (ox uses an `ammoname` field on each weapon).
function getAmmoItemName(weaponName)
    local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[weaponName]
    return w and (w.ammoname or w.ammoName) or nil
end

-- ── Flashlight state persistence ───────────────────────────────────────────────
AddStateBagChangeHandler('WeaponFlashlightState', nil, function(bagName, key, value)
    if not value then return end

    local netId        = bagName:gsub('player:', '')
    local playerSource = tonumber(netId)

    for slot, payload in pairs(value) do
        local weaponData = Inventory:GetSlot(playerSource, slot)
        if not weaponData or not weaponData.metadata then return end

        -- Serial guard: the slot may have been refilled with a DIFFERENT weapon by now.
        -- Only write back if the slot's gun still matches (serial), else one weapon's torch
        -- state stamps onto another.
        if payload.Serial and weaponData.metadata.serial
            and weaponData.metadata.serial ~= payload.Serial then
            goto continue
        end

        Utils.mbtDebugger("Receiving WeaponFlashlightState ", payload.FlashlightState)
        Utils.mbtDebugger(weaponData)

        weaponData.metadata.flashlightState = payload.FlashlightState == true
        Inventory:SetMetadata(playerSource, weaponData.slot, weaponData.metadata)

        Utils.mbtDebugger(
            "State of flashlight for weapon " .. weaponData.label ..
            " with serial " .. weaponData.metadata.serial ..
            " in slot " .. weaponData.slot ..
            " changed to " .. tostring(weaponData.metadata.flashlightState)
        )
        ::continue::
    end
end)

-- ── appendMalisling ──
-- Patches ox_inventory's Weapon.Equip to delegate the holster prompt to mbt_malisling via
-- TriggerEvent + LocalPlayer.state. Not SendNUIMessage: that targets the *calling resource's*
-- NUI, so injected code would show the prompt in ox_inventory's NUI, not malisling's React app.
-- Hook inserts before `sleep = anim and anim[3] or 1200`; Weapon.Equip blocks until malisling
-- writes malisling_holster_result, then equips or returns early (cancel = stay on sling).
-- The patch is applied automatically by modules/ox_patch/installer.js (the Lua sandbox can't:
-- SaveResourceFile is cross-resource blocked, io.open(write) denied); install_ox_patch.ps1 is
-- the manual fallback. This function just reports whether the patch is present.
local function appendMalisling()
    local resourcePath = GetResourcePath('ox_inventory')
    if not resourcePath then return end

    local filePath = resourcePath:gsub('\\', '/') .. '/modules/weapon/client.lua'
    local rf = io.open(filePath, 'r')
    if not rf then return end
    local st = rf:read('*a')
    rf:close()

    local hasHook   = st:find('mbt_malisling:holster_request', 1, true)
    local hasAppend = st:find('mbt_malisling:sendAnim', 1, true)

    if hasHook and hasAppend then
        Utils.mbtDebugger("appendMalisling ~ patch completa, OK")
        return
    end

    -- This check runs before the auto-patcher on first boot, so keep it calm — it self-resolves.
    Utils.mbtDebugger(
        "appendMalisling ~ patch not present yet (hook=" .. tostring(hasHook ~= nil) ..
        " sendAnim=" .. tostring(hasAppend ~= nil) .. "). The auto-patcher will apply it at startup."
    )
end

appendMalisling()

