RegisterCommand('mbtconfig', function()
    TriggerServerEvent('mbt_malisling:requestConfig')
end, false)

RegisterNetEvent('mbt_malisling:openConfigPanel')
AddEventHandler('mbt_malisling:openConfigPanel', function()

    SendNUIMessage({
        action = 'openConfig',
        data   = {
            debug             = MBT.Debug,
            dropWeaponOnDeath = MBT.DropWeaponOnDeath,
            enableSling       = MBT.EnableSling,
            enableFlashlight  = MBT.EnableFlashlight,
            uiPosition        = MBT.UI.Position,
            jamming = {
                enabled      = MBT.Jamming["Enabled"],
                cooldown     = MBT.Jamming["Cooldown"],
                unjamPresses = MBT.Jamming["Unjam"]["Presses"],
            },
            throw = {
                enabled = MBT.Throw["Enabled"],
                key     = MBT.Throw["Key"],
            },
            locale = buildNuiLocale(),
        }
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('configSave', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('mbt_malisling:saveConfig', data)
    cb({})
end)

RegisterNUICallback('configClose', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNetEvent('mbt_malisling:applyConfig')
AddEventHandler('mbt_malisling:applyConfig', function(data)
    MBT.Debug                         = data.debug
    MBT.DropWeaponOnDeath             = data.dropWeaponOnDeath
    MBT.EnableSling                   = data.enableSling
    MBT.EnableFlashlight              = data.enableFlashlight
    MBT.UI.Position                   = data.uiPosition
    MBT.Jamming["Enabled"]            = data.jamming.enabled
    MBT.Jamming["Cooldown"]           = data.jamming.cooldown
    MBT.Jamming["Unjam"]["Presses"]   = data.jamming.unjamPresses
    MBT.Throw["Enabled"]              = data.throw.enabled
    MBT.Throw["Key"]                  = data.throw.key
    Utils.mbtDebugger("Config applied from server")
end)
