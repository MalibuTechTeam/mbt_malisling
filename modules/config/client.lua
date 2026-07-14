-- ── Admin config — client ──
-- /mbtsling asks the server (ACE-checked) to open the dashboard; the server replies with
-- openAdmin + config snapshot, which we forward to the NUI. Saves via adminSave, closes via
-- adminClose. applyConfig re-applies the live-broadcast changes.

-- Throw groups are keyed by group hash in config but by name over the wire.
local THROW_GROUPS = {
    MELEE = `GROUP_MELEE`, PISTOL = `GROUP_PISTOL`, RIFLE = `GROUP_RIFLE`,
    MG = `GROUP_MG`, SMG = `GROUP_SMG`, SHOTGUN = `GROUP_SHOTGUN`,
    STUNGUN = `GROUP_STUNGUN`, SNIPER = `GROUP_SNIPER`, HEAVY = `GROUP_HEAVY`,
}

-- The admin command is registered SERVER-side so its ACE auto-registers; the server pushes
-- openAdmin to us. This optional keybind fires the same server-validated request path.
if MBT.Admin and type(MBT.Admin.Key) == 'string' and MBT.Admin.Key ~= '' then
    RegisterCommand('mbt_malisling:openAdmin', function()
        TriggerServerEvent('mbt_malisling:requestConfig')   -- server re-checks ACE
    end, false)
    RegisterKeyMapping('mbt_malisling:openAdmin', '[MBT] Open admin dashboard', 'keyboard', MBT.Admin.Key)
end

RegisterNetEvent('mbt_malisling:openAdmin', function(payload)
    SendNUIMessage({ action = 'openAdmin', data = payload or {} })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('adminSave', function(data, cb)
    -- Keep NUI focus: the panel stays open after save (confirmation pill).
    TriggerServerEvent('mbt_malisling:adminSave', data)
    cb({})
end)

RegisterNUICallback('adminClose', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

-- NUI pulls this on mount for reduced-motion (CEF often can't read the OS
-- prefers-reduced-motion setting). config.lua-driven; no focus needed.
RegisterNUICallback('getReduceMotion', function(_, cb)
    cb({ on = MBT.ReduceMotion and true or false })
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
    if d.UIStyle then MBT.UIStyle = d.UIStyle end
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
        -- WeaponDrop.Logging is server-only (config.lua); the client never fires webhooks.
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
    if d.LowReady and MBT.LowReady then
        MBT.LowReady.Enabled = d.LowReady.Enabled
        if d.LowReady.Types then
            MBT.LowReady.Types = { ['back'] = d.LowReady.Types.back and true or false,
                                   ['back2'] = d.LowReady.Types.back2 and true or false }
        end
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
    if d.ChainOfCustody and MBT.ChainOfCustody then
        for k, v in pairs(d.ChainOfCustody) do MBT.ChainOfCustody[k] = v end
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
        if d.Throw.Charge then
            MBT.Throw.Charge = MBT.Throw.Charge or {}
            MBT.Throw.Charge.Enabled       = d.Throw.Charge.Enabled
            MBT.Throw.Charge.ChargeMs      = d.Throw.Charge.ChargeMs
            MBT.Throw.Charge.MaxMultiplier = d.Throw.Charge.MaxMultiplier
            MBT.Throw.Charge.ShowUI        = d.Throw.Charge.ShowUI
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
    if d.VehicleTrunkRack and MBT.VehicleTrunkRack then
        MBT.VehicleTrunkRack.Enabled             = d.VehicleTrunkRack.Enabled
        MBT.VehicleTrunkRack.Capacity            = d.VehicleTrunkRack.Capacity
        MBT.VehicleTrunkRack.InteractionDistance = d.VehicleTrunkRack.InteractionDistance
        MBT.VehicleTrunkRack.EquipOnRetrieve     = d.VehicleTrunkRack.EquipOnRetrieve
        if d.VehicleTrunkRack.AllowedTypes then
            MBT.VehicleTrunkRack.AllowedTypes = {
                ['back']  = d.VehicleTrunkRack.AllowedTypes.back,
                ['back2'] = d.VehicleTrunkRack.AllowedTypes.back2,
            }
        end
    end
    if d.WeaponRack and MBT.WeaponRack then
        MBT.WeaponRack.Enabled             = d.WeaponRack.Enabled
        MBT.WeaponRack.Capacity            = d.WeaponRack.Capacity
        MBT.WeaponRack.InteractionDistance = d.WeaponRack.InteractionDistance
        MBT.WeaponRack.EquipOnRetrieve     = d.WeaponRack.EquipOnRetrieve
        if d.WeaponRack.AllowedTypes then
            MBT.WeaponRack.AllowedTypes = {
                ['back']  = d.WeaponRack.AllowedTypes.back,
                ['back2'] = d.WeaponRack.AllowedTypes.back2,
                ['side']  = d.WeaponRack.AllowedTypes.side,
            }
        end
        if d.WeaponRack.Placement and MBT.WeaponRack.Placement then
            MBT.WeaponRack.Placement.Enabled      = d.WeaponRack.Placement.Enabled
            MBT.WeaponRack.Placement.MaxPerPlayer = d.WeaponRack.Placement.MaxPerPlayer
            MBT.WeaponRack.Placement.AllowPickup  = d.WeaponRack.Placement.AllowPickup
            MBT.WeaponRack.Placement.Access       = d.WeaponRack.Placement.Access
        end
    end
    if d.TacticalSling and MBT.TacticalSling then
        local oldVariant = MBT.TacticalSling.DefaultVariant
        local oldJV = json.encode(MBT.TacticalSling.JobVariants or {})
        MBT.TacticalSling.Enabled = d.TacticalSling.Enabled
        if d.TacticalSling.DefaultVariant then MBT.TacticalSling.DefaultVariant = d.TacticalSling.DefaultVariant end
        if d.TacticalSling.JobVariants then
            local jv = {}
            for job, vid in pairs(d.TacticalSling.JobVariants) do
                if type(job) == 'string' and type(vid) == 'string' and vid ~= '' then jv[job] = vid end
            end
            MBT.TacticalSling.JobVariants = jv
        end
        if d.TacticalSling.Types then
            MBT.TacticalSling.Types = { ['back'] = d.TacticalSling.Types.back and true or false, ['back2'] = d.TacticalSling.Types.back2 and true or false }
        end
        -- Enabled/Types handled live by the strap loop; a Variant change needs a respawn to swap
        -- the model — only when it actually changed (no flicker on unrelated saves).
        if (oldVariant ~= MBT.TacticalSling.DefaultVariant
            or oldJV ~= json.encode(MBT.TacticalSling.JobVariants or {})) and MBT.RefreshSling then
            MBT.RefreshSling()
        end
    end
    if d.ShellCasings and MBT.ShellCasings then
        MBT.ShellCasings.Enabled      = d.ShellCasings.Enabled
        MBT.ShellCasings.AllowCollect = d.ShellCasings.AllowCollect
    end
    if d.Handoff and MBT.Handoff then
        MBT.Handoff.Enabled       = d.Handoff.Enabled
        MBT.Handoff.MaxDistance   = d.Handoff.MaxDistance
        MBT.Handoff.EquipOnAccept = d.Handoff.EquipOnAccept
    end
    if d.ConcealedCarry and MBT.ConcealedCarry then
        MBT.ConcealedCarry.Enabled = d.ConcealedCarry.Enabled
        if d.ConcealedCarry.Tell and MBT.ConcealedCarry.Tell then
            MBT.ConcealedCarry.Tell.Enabled     = d.ConcealedCarry.Tell.Enabled
            MBT.ConcealedCarry.Tell.RollSeconds = d.ConcealedCarry.Tell.RollSeconds
            MBT.ConcealedCarry.Tell.ChanceGood  = d.ConcealedCarry.Tell.ChanceGood
            MBT.ConcealedCarry.Tell.ChancePoor  = d.ConcealedCarry.Tell.ChancePoor
        end
    end
    if d.PatDown and MBT.PatDown then
        MBT.PatDown.Enabled        = d.PatDown.Enabled
        MBT.PatDown.RequireConsent = d.PatDown.RequireConsent
        MBT.PatDown.CuffedBypass   = d.PatDown.CuffedBypass
        MBT.PatDown.ShowAmmo       = d.PatDown.ShowAmmo
        MBT.PatDown.MaxDistance    = d.PatDown.MaxDistance
    end
    if d.AmmoSharing and MBT.AmmoSharing then
        MBT.AmmoSharing.Enabled     = d.AmmoSharing.Enabled
        MBT.AmmoSharing.ShareAmount = d.AmmoSharing.ShareAmount
        MBT.AmmoSharing.MaxDistance = d.AmmoSharing.MaxDistance
    end
    Utils.mbtDebugger('Admin config applied live')
end

-- Live apply (broadcast to everyone on save).
RegisterNetEvent('mbt_malisling:applyConfig', applyConfig)

-- On (re)start / fresh join, pull the current live config so this client matches
-- the saved runtime config without needing a save.
CreateThread(function()
    local data = lib.callback.await('mbt_malisling:getRuntimeConfig', false)
    if data then applyConfig(data) end
end)
