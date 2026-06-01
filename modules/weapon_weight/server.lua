-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Weight / Carry Penalty — server
--
-- Returns the list of WEAPON_* items a player carries (name + count) via the
-- Inventory abstraction (ox + qb). The CLIENT resolves each weapon's group with
-- GetWeapontypeGroup (a client native — not reliable server-side) and applies the
-- move-rate penalty. GetInventoryItems is keyed by name on qb, so duplicates
-- collapse into one entry; we return the real count so a stack still weighs right.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.WeaponWeight or not MBT.WeaponWeight.Enabled then return end

lib.callback.register('mbt_malisling:getCarriedWeapons', function(src)
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
