-- ─────────────────────────────────────────────────────────────────────────────
-- Admin config — client
--
-- /mbtconfig asks the server (ACE-checked) to open the admin dashboard. The
-- server replies with openAdmin + the config snapshot, which we forward to the
-- NUI and give it focus. The dashboard saves via the adminSave NUI callback and
-- closes via adminClose. applyConfig re-applies the live-broadcast changes.
-- ─────────────────────────────────────────────────────────────────────────────

-- Throw groups are keyed by group hash in config but by name over the wire.
local THROW_GROUPS = {
    MELEE = `GROUP_MELEE`, PISTOL = `GROUP_PISTOL`, RIFLE = `GROUP_RIFLE`,
    MG = `GROUP_MG`, SMG = `GROUP_SMG`, SHOTGUN = `GROUP_SHOTGUN`,
    STUNGUN = `GROUP_STUNGUN`, SNIPER = `GROUP_SNIPER`, HEAVY = `GROUP_HEAVY`,
}

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
        end
    end
    if d.Jamming and MBT.Jamming then
        MBT.Jamming.Enabled  = d.Jamming.Enabled
        MBT.Jamming.Cooldown = d.Jamming.Cooldown
        if MBT.Jamming.Unjam then MBT.Jamming.Unjam.Presses = d.Jamming.UnjamPresses end
    end
    if d.SuppressorHeat and MBT.SuppressorHeat then
        for k, v in pairs(d.SuppressorHeat) do MBT.SuppressorHeat[k] = v end
    end
    if d.Safety and MBT.Safety then
        for k, v in pairs(d.Safety) do MBT.Safety[k] = v end
    end
    if d.ConditionHUD and MBT.ConditionHUD then
        MBT.ConditionHUD.Enabled = d.ConditionHUD.Enabled
    end
    if d.ChargeWeapon and MBT.ChargeWeapon then
        for k, v in pairs(d.ChargeWeapon) do MBT.ChargeWeapon[k] = v end
    end
    if d.WeaponWeight and MBT.WeaponWeight then
        for k, v in pairs(d.WeaponWeight) do MBT.WeaponWeight[k] = v end
    end
    -- Interaction
    if d.Inspect and MBT.Inspect then
        MBT.Inspect.Enabled     = d.Inspect.Enabled
        MBT.Inspect.MaxDistance = d.Inspect.MaxDistance
        MBT.Inspect.AmmoMode    = d.Inspect.AmmoMode
        if d.Inspect.Show and MBT.Inspect.Show then
            for k, v in pairs(d.Inspect.Show) do MBT.Inspect.Show[k] = v end
        end
    end
    if d.WeaponName and MBT.WeaponName then
        for k, v in pairs(d.WeaponName) do MBT.WeaponName[k] = v end
    end
    if d.ShowcasePoses and MBT.ShowcasePoses then
        MBT.ShowcasePoses.Enabled = d.ShowcasePoses.Enabled
        MBT.ShowcasePoses.Sync    = d.ShowcasePoses.Sync
    end
    if d.Throw and MBT.Throw then
        MBT.Throw.Enabled = d.Throw.Enabled
        if d.Throw.Groups and MBT.Throw.Groups then
            for name, hash in pairs(THROW_GROUPS) do
                if MBT.Throw.Groups[hash] and d.Throw.Groups[name] ~= nil then
                    MBT.Throw.Groups[hash].Allowed = d.Throw.Groups[name]
                end
            end
        end
    end
    -- World
    if d.NoDrawZones and MBT.NoDrawZones then
        MBT.NoDrawZones.Enabled        = d.NoDrawZones.Enabled
        MBT.NoDrawZones.AllowMelee     = d.NoDrawZones.AllowMelee
        MBT.NoDrawZones.HudIndicator   = d.NoDrawZones.HudIndicator
        MBT.NoDrawZones.NotifyCooldown = d.NoDrawZones.NotifyCooldown
    end
    if d.VehicleHiding and MBT.VehicleHiding then
        MBT.VehicleHiding.Enabled      = d.VehicleHiding.Enabled
        MBT.VehicleHiding.UseRoofCheck = d.VehicleHiding.UseRoofCheck
    end
    if d.TacticalSling and MBT.TacticalSling then
        MBT.TacticalSling.Enabled = d.TacticalSling.Enabled
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
