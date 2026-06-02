-- ─────────────────────────────────────────────────────────────────────────────
-- Admin config — client
--
-- /mbtconfig asks the server (ACE-checked) to open the admin dashboard. The
-- server replies with openAdmin + the config snapshot, which we forward to the
-- NUI and give it focus. The dashboard saves via the adminSave NUI callback and
-- closes via adminClose. applyConfig re-applies the live-broadcast changes.
-- ─────────────────────────────────────────────────────────────────────────────

-- The /mbtconfig command is registered SERVER-side (modules/config/server.lua)
-- so its ACE auto-registers. The server pushes openAdmin straight to us.
RegisterNetEvent('mbt_malisling:openAdmin', function(payload)
    SendNUIMessage({ action = 'openAdmin', data = payload })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('adminSave', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('mbt_malisling:adminSave', data)
    cb({})
end)

RegisterNUICallback('adminClose', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

-- Server-driven localized notification (shared by config + other modules).
RegisterNetEvent('mbt_malisling:notifyLabel', function(key)
    MBT.NotifyLabel(key)
end)

-- Live apply (broadcast to everyone on save).
RegisterNetEvent('mbt_malisling:applyConfig', function(d)
    if type(d) ~= 'table' then return end
    MBT.Debug             = d.Debug
    MBT.EnableSling       = d.EnableSling
    MBT.EnableFlashlight  = d.EnableFlashlight
    MBT.DropWeaponOnDeath = d.DropWeaponOnDeath
    if MBT.UI then MBT.UI.Position = d.UIPosition end
    Utils.mbtDebugger('Admin config applied live')
end)
