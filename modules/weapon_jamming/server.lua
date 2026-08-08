if not MBT.Jamming then return end   -- always register; Enabled is live-checked in the handler

local _jamCooldown = {}
local JAM_RATE_MS  = 1000

RegisterNetEvent("mbt_malisling:setWeaponJammed")
AddEventHandler("mbt_malisling:setWeaponJammed", function(slot, jammed)
    if not MBT.Jamming.Enabled then return end   -- live on/off from the dashboard
    local src = source
    if not src or src < 1 then return end
    if type(slot) ~= "number" or type(jammed) ~= "boolean" then return end
    if slot < 1 or slot > 250 or math.floor(slot) ~= slot then return end

    local now = os.time() * 1000
    if _jamCooldown[src] and (now - _jamCooldown[src]) < JAM_RATE_MS then return end
    _jamCooldown[src] = now

    local weaponData = Inventory:GetSlot(src, slot)
    if not weaponData then return end

    weaponData.metadata        = weaponData.metadata or {}
    weaponData.metadata.jammed = jammed
    Inventory:SetMetadata(src, slot, weaponData.metadata)
end)

AddEventHandler("playerDropped", function()
    _jamCooldown[source] = nil
end)
