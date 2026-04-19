local CONFIG_FILE     = 'data/runtime_config.json'
local VALID_POSITIONS = { ['bottom-center'] = true, ['top-center'] = true, ['bottom-right'] = true }
local adminPerm       = MBT.Admin and MBT.Admin.Permission or 'command.mbtconfig'

local function applyToMBT(data)
    MBT.Debug                       = data.debug
    MBT.DropWeaponOnDeath           = data.dropWeaponOnDeath
    MBT.EnableSling                 = data.enableSling
    MBT.EnableFlashlight            = data.enableFlashlight
    MBT.UI.Position                 = data.uiPosition
    MBT.Jamming["Enabled"]          = data.jamming.enabled
    MBT.Jamming["Cooldown"]         = data.jamming.cooldown
    MBT.Jamming["Unjam"]["Presses"] = data.jamming.unjamPresses
    MBT.Throw["Enabled"]            = data.throw.enabled
    MBT.Throw["Key"]                = data.throw.key
end

local function validate(data)
    if type(data) ~= "table" then return false end
    if type(data.debug) ~= "boolean"            then return false end
    if type(data.dropWeaponOnDeath) ~= "boolean" then return false end
    if type(data.enableSling) ~= "boolean"      then return false end
    if type(data.enableFlashlight) ~= "boolean" then return false end
    if type(data.uiPosition) ~= "string" or not VALID_POSITIONS[data.uiPosition] then return false end
    if type(data.jamming) ~= "table" then return false end
    if type(data.jamming.enabled) ~= "boolean" then return false end
    if type(data.jamming.cooldown) ~= "number" or data.jamming.cooldown < 1 or data.jamming.cooldown > 60 then return false end
    if type(data.jamming.unjamPresses) ~= "number" or data.jamming.unjamPresses < 1 or data.jamming.unjamPresses > 20 then return false end
    if type(data.throw) ~= "table" then return false end
    if type(data.throw.enabled) ~= "boolean" then return false end
    if type(data.throw.key) ~= "string" or #data.throw.key < 1 or #data.throw.key > 4 then return false end
    return true
end

local function loadRuntimeConfig()
    local raw = LoadResourceFile(GetCurrentResourceName(), CONFIG_FILE)
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or not validate(data) then
        Utils.mbtWarn("runtime_config.json invalid or corrupted, ignoring")
        return
    end
    applyToMBT(data)
    Utils.mbtDebugger("Runtime config loaded from", CONFIG_FILE)
end

RegisterNetEvent('mbt_malisling:requestConfig')
AddEventHandler('mbt_malisling:requestConfig', function()
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    TriggerClientEvent('mbt_malisling:openConfigPanel', src)
end)

RegisterNetEvent('mbt_malisling:saveConfig')
AddEventHandler('mbt_malisling:saveConfig', function(data)
    local src = source
    if not IsPlayerAceAllowed(src, adminPerm) then return end
    if not validate(data) then
        Utils.mbtWarn("saveConfig ~ payload non valido da player", src)
        return
    end

    applyToMBT(data)
    SaveResourceFile(GetCurrentResourceName(), CONFIG_FILE, json.encode(data), -1)
    TriggerClientEvent('mbt_malisling:applyConfig', -1, data)
    Utils.mbtDebugger("Config salvato da player", src)
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadRuntimeConfig()
end)
