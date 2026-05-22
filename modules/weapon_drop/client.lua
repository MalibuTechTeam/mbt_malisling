local CurrentWeapon = {}
local groundProps = {}  -- [dropId] = entity

AddEventHandler('ox_inventory:currentWeapon', function(currentWeapon)
    CurrentWeapon = currentWeapon or {}
end)

-- ── Drop-on-death ──────────────────────────────────────────────────────────────
if MBT.DropWeaponOnDeath then
    AddEventHandler('gameEventTriggered', function(event, data)
        if event ~= 'CEventNetworkEntityDamage' then return end
        if data[1] == cache.ped and IsEntityDead(cache.ped) then
            if CurrentWeapon and CurrentWeapon.slot and CurrentWeapon.hash then
                DeleteEntity(GetWeaponObjectFromPed(cache.ped))
                TriggerServerEvent('mbt_malisling:dropWeapon', {
                    slot       = CurrentWeapon.slot,
                    weaponHash = CurrentWeapon.hash,
                })
            end
        end
    end)
end

-- ── Manual drop (export) ───────────────────────────────────────────────────────
function dropCurrentWeapon()
    if not CurrentWeapon or not CurrentWeapon.hash or not CurrentWeapon.slot then return end

    local playerPed = cache.ped
    local boneIndex = GetPedBoneIndex(playerPed, 57005)
    local bonePos = GetWorldPositionOfEntityBone(playerPed, boneIndex)
    local weaponModel = GetWeapontypeModel(CurrentWeapon.hash)
    local currentWeapon = Utils.tableDeepCopy(CurrentWeapon)
    lib.requestModel(weaponModel)
    equippedWeapon.dropped = true
    -- Temporary physics object: let it fall and settle so we know where the
    -- weapon lands, then hand those coords to the server.
    local weaponObj = CreateObject(weaponModel, bonePos.x, bonePos.y, bonePos.z, true, true, true)
    ActivatePhysics(weaponObj)
    TriggerEvent("ox_inventory:disarm", true)
    while IsEntityInAir(weaponObj) do Wait(100) end
    local deadline = GetGameTimer() + 800
    repeat
        Wait(50)
        local vel = GetEntityVelocity(weaponObj)
        if math.abs(vel.x) < 0.05 and math.abs(vel.y) < 0.05 and math.abs(vel.z) < 0.05 then break end
    until GetGameTimer() > deadline
    local weaponCoords = GetEntityCoords(weaponObj)
    DeleteObject(weaponObj)
    SetModelAsNoLongerNeeded(weaponModel)
    TriggerServerEvent("mbt_malisling:createWeaponDrop", {
        WeaponInfo = currentWeapon,
        Coords     = weaponCoords,
    })
end

exports('dropCurrentWeapon', dropCurrentWeapon)

-- ── Ground drop prop: spawn / despawn ──────────────────────────────────────────
-- The dropped weapon is rendered by malisling itself via CreateWeaponObject so
-- weapon models render correctly (ox_inventory's drop renderer rejects them).
local function spawnGroundDrop(dropId, coords, weaponHash)
    if groundProps[dropId] and DoesEntityExist(groundProps[dropId]) then return end

    lib.requestWeaponAsset(weaponHash, 1000, 31, 1)
    local obj = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
    if not obj or not DoesEntityExist(obj) then return end

    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, true)
    groundProps[dropId] = obj

    Target.AddEntity(obj, {
        name     = 'mbt_pickup_' .. dropId,
        icon     = 'fa-solid fa-hand',
        label    = Translate('pickup_weapon'),
        distance = 2.0,
        onSelect = function()
            -- On success the server broadcasts removeGroundDrop to every client.
            lib.callback.await('mbt_malisling:lootGroundDrop', false, dropId)
        end,
    })
end

RegisterNetEvent('mbt_malisling:spawnGroundDrop', function(dropId, coords, weaponHash)
    spawnGroundDrop(dropId, coords, weaponHash)
end)

RegisterNetEvent('mbt_malisling:removeGroundDrop', function(dropId)
    local obj = groundProps[dropId]
    if obj then
        Target.RemoveEntity(obj)
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        groundProps[dropId] = nil
    end
end)

-- Late-join sync: pull every drop that already exists when this client starts.
CreateThread(function()
    Wait(2000)
    local existing = lib.callback.await('mbt_malisling:getGroundDrops', false)
    if type(existing) == 'table' then
        for dropId, drop in pairs(existing) do
            spawnGroundDrop(dropId, drop.coords, drop.weaponHash)
        end
    end
end)
