if not MBT.Jamming["Enabled"] then return end

RegisterNetEvent("mbt_malisling:setWeaponJammed")
AddEventHandler("mbt_malisling:setWeaponJammed", function(slot, jammed)
    local src = source
    if not src or src < 1 then return end
    if type(slot) ~= "number" or type(jammed) ~= "boolean" then return end

    local weaponData = Inventory:GetSlot(src, slot)
    if not weaponData then return end

    weaponData.metadata        = weaponData.metadata or {}
    weaponData.metadata.jammed = jammed
    Inventory:SetMetadata(src, slot, weaponData.metadata)
end)
