-- ─────────────────────────────────────────────────────────────────────────────
-- Custom Weapon Name — engrave a name on the held firearm, stored server-side in
-- metadata.label (which Weapon Inspect displays). Client only collects name + slot;
-- server validates/sanitizes/writes.
-- ─────────────────────────────────────────────────────────────────────────────

-- Enabled checked at use time (live-apply via menu).
if not MBT.WeaponName then return end

local cfg = MBT.WeaponName
local currentWeapon

AddEventHandler('ox_inventory:currentWeapon', function(data)
    currentWeapon = data
end)

--- Real firearm in hand (not unarmed / melee / thrown)?
local function heldFirearm()
    local has, hash = GetCurrentPedWeapon(cache.ped, true)
    if not has or hash == `WEAPON_UNARMED` then return false end
    local g = GetWeapontypeGroup(hash)
    return g ~= `GROUP_MELEE` and g ~= `GROUP_THROWN` and g ~= `GROUP_UNARMED`
end

local function rename()
    if not cfg.Enabled then return end
    if not heldFirearm() or not currentWeapon or not currentWeapon.slot then
        MBT.NotifyLabel('wname_no_weapon')
        return
    end

    local current = (currentWeapon.metadata and currentWeapon.metadata.label) or ''
    local input = lib.inputDialog(Translate('wname_dialog_title'), {
        {
            type = 'input',
            label = Translate('wname_dialog_field'),
            default = current,
            max = cfg.MaxLength or 24,
            required = true,
        },
    })
    if not input or not input[1] then return end

    TriggerServerEvent('mbt_malisling:setWeaponName', currentWeapon.slot, input[1])
end

RegisterCommand(cfg.Command, rename, false)
if cfg.Key and cfg.Key ~= '' then
    RegisterKeyMapping(cfg.Command, '[MBT] Name your weapon', 'keyboard', cfg.Key)
end
