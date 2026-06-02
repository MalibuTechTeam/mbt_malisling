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
    -- Keep NUI focus: the panel stays open after save (shows a confirmation pill).
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

--- Apply an editable config snapshot to MBT.* on this client.
local function applyConfig(d)
    if type(d) ~= 'table' then return end
    MBT.Debug             = d.Debug
    MBT.EnableSling       = d.EnableSling
    MBT.EnableFlashlight  = d.EnableFlashlight
    MBT.DropWeaponOnDeath = d.DropWeaponOnDeath
    if MBT.UI then MBT.UI.Position = d.UIPosition end
    if d.Sounds and MBT.Sounds then
        MBT.Sounds.Enabled     = d.Sounds.Enabled
        MBT.Sounds.MaxDistance = d.Sounds.MaxDistance
        MBT.Sounds.Volume      = d.Sounds.Volume
    end
    if d.WeaponDrop and MBT.WeaponDrop then
        MBT.WeaponDrop.WeaponModelProp = d.WeaponDrop.WeaponModelProp
        MBT.WeaponDrop.OxTargetPickup  = d.WeaponDrop.OxTargetPickup
        if d.WeaponDrop.Despawn and MBT.WeaponDrop.Despawn then
            MBT.WeaponDrop.Despawn.Enabled      = d.WeaponDrop.Despawn.Enabled
            MBT.WeaponDrop.Despawn.Seconds      = d.WeaponDrop.Despawn.Seconds
            MBT.WeaponDrop.Despawn.BlinkLastSec = d.WeaponDrop.Despawn.BlinkLastSec
        end
        if d.WeaponDrop.Logging and MBT.WeaponDrop.Logging then
            MBT.WeaponDrop.Logging.Enabled = d.WeaponDrop.Logging.Enabled
            MBT.WeaponDrop.Logging.Webhook = d.WeaponDrop.Logging.Webhook
            MBT.WeaponDrop.Logging.Console = d.WeaponDrop.Logging.Console
        end
    end
    Utils.mbtDebugger('Admin config applied live')
end

-- Live apply (broadcast to everyone on save).
RegisterNetEvent('mbt_malisling:applyConfig', applyConfig)

-- On (re)start / fresh join, pull the current live config so this client matches
-- runtime_config.json without needing a save. Retries until the server answers.
CreateThread(function()
    local data = lib.callback.await('mbt_malisling:getRuntimeConfig', false)
    if data then applyConfig(data) end
end)
