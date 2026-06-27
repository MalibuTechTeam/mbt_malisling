-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Weight / Carry Penalty — server
-- Returns carried WEAPON_* items (name + count). CLIENT resolves groups via
-- GetWeapontypeGroup (client native, not reliable server-side) and applies the penalty.
-- qb keys GetInventoryItems by name (duplicates collapse) so we return the real count.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.WeaponWeight then return end   -- always register; Enabled is live-checked in the callback

lib.callback.register('mbt_malisling:getCarriedWeapons', function(src)
    if not MBT.WeaponWeight.Enabled then return {} end   -- disabled → no weapons → no penalty
    local items = Inventory:GetInventoryItems(src)
    if type(items) ~= 'table' then return {} end

    local weapons = {}
    for _, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string'
            and item.name:sub(1, 7) == 'WEAPON_' then
            weapons[#weapons + 1] = { name = item.name, count = tonumber(item.count) or 1 }
        end
    end
    return weapons
end)
