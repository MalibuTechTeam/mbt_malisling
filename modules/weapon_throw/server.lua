-- Weapon throw drop → routes into WeaponDropServer.Create, defined by
-- modules/weapon_drop/server.lua (loaded earlier in fxmanifest).

RegisterNetEvent("mbt_malisling:createWeaponDrop", function(data)
    local src = source
    if type(data) ~= 'table' or type(data.WeaponInfo) ~= 'table' then return end

    local info = data.WeaponInfo
    if type(info.slot) ~= 'number' then return end
    if type(data.Coords) ~= 'table' and type(data.Coords) ~= 'vector3' then return end

    local coords = vector3(data.Coords.x, data.Coords.y, data.Coords.z)

    -- Must land near the player: stops spoofed Coords planting a drop anywhere.
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - coords) > 50.0 then return end

    WeaponDropServer.Create(src, info.slot, coords, info.hash)
end)
