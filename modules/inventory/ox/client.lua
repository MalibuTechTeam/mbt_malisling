if GetResourceState('ox_inventory') ~= 'started' then return end

Inventory = exports['ox_inventory']

-- ── Holster prompt ─────────────────────────────────────────────────────────────
-- ox_inventory's patched Weapon.Equip fires 'mbt_malisling:holster_request' and
-- then blocks on LocalPlayer.state.malisling_holster_result. This handler shows
-- the React NUI prompt, waits for player input, then writes the boolean result
-- so Weapon.Equip can either continue the equip (true) or return early (false).
--
-- Key mappings registered here match those in qb/client.lua so both inventory
-- backends share the same keybind settings page entries.

local holsterState = nil  -- nil=idle, true=waiting, 'confirmed'|'cancelled'=result

RegisterCommand('confirmHolster', function()
    if holsterState == true then holsterState = 'confirmed' end
end, false)

RegisterCommand('cancelHolster', function()
    if holsterState == true then holsterState = 'cancelled' end
end, false)

RegisterKeyMapping('confirmHolster',
    MBT.HolsterControls["Confirm"]["Label"],
    MBT.HolsterControls["Confirm"]["Input"],
    MBT.HolsterControls["Confirm"]["Key"])

RegisterKeyMapping('cancelHolster',
    MBT.HolsterControls["Cancel"]["Label"],
    MBT.HolsterControls["Cancel"]["Input"],
    MBT.HolsterControls["Cancel"]["Key"])

AddEventHandler('mbt_malisling:holster_request', function(data)
    if holsterState ~= nil then
        -- Re-entrant call: another prompt is already active — auto-cancel
        LocalPlayer.state:set('malisling_holster_result', false, false)
        return
    end

    holsterState = true

    SendNUIMessage({ action = 'showHolster', data = {
        weaponLabel = data.weaponLabel,
        position    = MBT.UI and MBT.UI.Position or 'bottom-center',
        confirm     = { label = MBT.HolsterControls["Confirm"]["Label"], display = 'RMB' },
        cancel      = { label = MBT.HolsterControls["Cancel"]["Label"],  display = 'BACKSPACE' },
        locale      = buildNuiLocale(),
    }})

    local deadline = GetGameTimer() + 16000
    while holsterState == true and GetGameTimer() < deadline do Wait(50) end
    if holsterState == true then holsterState = 'cancelled' end

    SendNUIMessage({ action = 'hideHolster' })

    LocalPlayer.state:set('malisling_holster_result', holsterState == 'confirmed', false)
    holsterState = nil
end)
