if GetResourceState('ox_inventory') ~= 'started' then return end

if not lib.checkDependency('ox_inventory', '2.30.0') then
    warn("mbt_malisling has not been tested with this version of ox_inventory!")
end

if GetConvarInt('inventory:weaponanims', 1) == 0 then
    warn("You have enabled the sling feature, but you have disabled the weapons animation convar in ox_inventory. This will cause issues with animations and the sling feature. Please set inventory:weaponanims to 1")
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

-- ── Flashlight state persistence ───────────────────────────────────────────────
AddStateBagChangeHandler('WeaponFlashlightState', nil, function(bagName, key, value)
    if not value then return end

    local netId        = bagName:gsub('player:', '')
    local playerSource = tonumber(netId)

    for slot, payload in pairs(value) do
        local weaponData = Inventory:GetSlot(playerSource, slot)
        if not weaponData then return end

        Utils.mbtDebugger("Receiving WeaponFlashlightState ", payload.FlashlightState)
        Utils.dumpTable(weaponData)

        weaponData.metadata.flashlightState = payload.FlashlightState
        Inventory:SetMetadata(playerSource, weaponData.slot, weaponData.metadata)

        Utils.mbtDebugger(
            "State of flashlight for weapon " .. weaponData.label ..
            " with serial " .. weaponData.metadata.serial ..
            " in slot " .. weaponData.slot ..
            " changed to " .. tostring(weaponData.metadata.flashlightState)
        )
    end
end)

-- ── appendMalisling ─────────────────────────────────────────────────────────────
-- Patches ox_inventory's Weapon.Equip with a minimal hook that delegates the
-- holster prompt to mbt_malisling via TriggerEvent + LocalPlayer.state.
--
-- Why not SendNUIMessage: it sends to the *calling resource's* NUI context, so
-- code injected into ox_inventory's script would show the prompt in ox_inventory's
-- NUI, not in mbt_malisling's React app.
--
-- The hook inserts ~10 lines before `sleep = anim and anim[3] or 1200` (inside the
-- weaponanims block, where `anim` and `data` are both in scope). Weapon.Equip blocks
-- until mbt_malisling writes the result to LocalPlayer.state.malisling_holster_result,
-- then either proceeds with the equip or returns early (cancel = stay on sling).
-- Verifica che la patch manuale sia stata applicata.
-- La patch va applicata una volta sola con install_ox_patch.ps1 (nella cartella di mbt_malisling).
-- fxv2_oal in ox_inventory impedisce qualsiasi modifica a runtime: SaveResourceFile è bloccato
-- da FiveM e io.open viene ignorato perché fxv2_oal serve i client dalla cache bytecode.
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

    warn(
        "La patch ox_inventory non e' completa (hook=" .. tostring(hasHook ~= nil) ..
        " sendAnim=" .. tostring(hasAppend ~= nil) .. "). " ..
        "Esegui install_ox_patch.ps1 (nella cartella di mbt_malisling) con il server spento, " ..
        "poi riavvia il server."
    )
end

appendMalisling()

