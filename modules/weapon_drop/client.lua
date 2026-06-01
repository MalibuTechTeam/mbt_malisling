-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon drop — client
--
-- ox path: listens to ox_inventory:createDrop (fires for EVERY drop — native
--   drag-drop, death, throw), asks the server whether the drop holds a weapon,
--   and if so renders the weapon model via CreateWeaponObject + ox_target, and
--   hides ox's own bag prop. Native walk-in pickup keeps working.
--
-- qb path (fallback): spawns malisling's own ground-drop prop from the server's
--   GroundDrop broadcast; loot hands the item straight back.
-- ─────────────────────────────────────────────────────────────────────────────

local isOx = GetResourceState('ox_inventory') == 'started'
local CurrentWeapon = {}

AddEventHandler('ox_inventory:currentWeapon', function(currentWeapon)
    CurrentWeapon = currentWeapon or {}
end)

-- ── Despawn timer (shared) ──────────────────────────────────────────────────────
-- Starts a per-drop timer that blinks the prop in the final seconds, then calls
-- onExpire(). Cancelled by setting drops[dropId] = nil before it fires (the loop
-- checks the prop still exists). Used by both the ox and qb paths.
---@param dropId string|number
---@param prop number              the rendered weapon prop entity
---@param stillValid fun():boolean returns false once the drop was removed otherwise
---@param onExpire fun()           called when the timer runs out
local function startDespawnTimer(dropId, prop, stillValid, onExpire)
    local cfg = (MBT.WeaponDrop or {}).Despawn
    if not cfg or not cfg.Enabled or not prop then return end
    CreateThread(function()
        local total = (cfg.Seconds or 300) * 1000
        local blink = (cfg.BlinkLastSec or 0) * 1000
        local elapsed = 0
        while elapsed < total do
            if not stillValid() or not DoesEntityExist(prop) then return end
            -- Blink window: toggle visibility roughly twice a second.
            if blink > 0 and (total - elapsed) <= blink then
                SetEntityVisible(prop, (math.floor(elapsed / 250) % 2) == 0, false)
                Wait(250); elapsed = elapsed + 250
            else
                Wait(1000); elapsed = elapsed + 1000
            end
        end
        if stillValid() and DoesEntityExist(prop) then
            SetEntityVisible(prop, true, false)
            onExpire()
        end
    end)
end

-- ── Drop-on-death (shared) ─────────────────────────────────────────────────────
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

-- ── Manual drop (export, shared) ───────────────────────────────────────────────
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

if isOx then
    -- ═══ OX PATH ═══════════════════════════════════════════════════════════════
    local weaponDrops = {}  -- [dropId] = { prop = entity, coords = vec3 }
    local bagModel = joaat(GetConvar('inventory:dropmodel', 'prop_med_bag_01b'))

    local function removeWeaponDropProp(dropId)
        local d = weaponDrops[dropId]
        if not d then return end
        Target.RemoveZone(dropId)
        if d.prop and DoesEntityExist(d.prop) then
            DeleteEntity(d.prop)
        end
        weaponDrops[dropId] = nil
    end

    local function spawnWeaponDropProp(dropId, coords, weaponHash)
        if weaponDrops[dropId] then return end

        local cfg = MBT.WeaponDrop or {}
        -- Both features off → leave the drop fully native; malisling does nothing.
        if not cfg.WeaponModelProp and not cfg.OxTargetPickup then return end

        local zoneCoords = vector3(coords.x, coords.y, coords.z)
        local prop

        if cfg.WeaponModelProp then
            lib.requestWeaponAsset(weaponHash, 1000, 31, 1)
            local obj = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
            if obj and DoesEntityExist(obj) then
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                -- Collision OFF: the interaction is a coords-based ox_target zone,
                -- not entity raycast, so the prop needs no collision — and this
                -- lets the player walk onto the drop for the native walk-in pickup.
                SetEntityCollision(obj, false, true)
                prop = obj
                zoneCoords = GetEntityCoords(obj)
            end
        end

        weaponDrops[dropId] = { prop = prop, coords = zoneCoords }

        -- Proactively hide ox's bag right now (the bag-hide loop is a safety net
        -- for re-entry, but the initial swap is what the player actually sees).
        if prop then
            local bag = GetClosestObjectOfType(zoneCoords.x, zoneCoords.y, zoneCoords.z,
                2.0, bagModel, false, false, false)
            if bag ~= 0 and bag ~= prop and IsEntityVisible(bag) then
                SetEntityVisible(bag, false, 0)
                SetEntityCollision(bag, false, false)
            end
        end

        if cfg.OxTargetPickup then
            Target.AddZone(dropId, zoneCoords, 1.0, {
                name     = 'mbt_wdrop_' .. dropId,
                icon     = 'fa-solid fa-hand',
                label    = Translate('pickup_weapon'),
                distance = 2.5,
                onSelect = function()
                    exports.ox_inventory:openInventory('drop', dropId)
                end,
            })
        end

        -- Despawn timer: on expiry ask the server to clear the ox drop. ox empties
        -- it and broadcasts ox_inventory:removeDrop to everyone, which removes our
        -- prop on all clients (removeWeaponDropProp). Real despawn, not just local.
        if prop then
            startDespawnTimer(dropId, prop,
                function() return weaponDrops[dropId] ~= nil end,
                function() TriggerServerEvent('mbt_malisling:despawnWeaponDrop', dropId) end)
        end
    end

    -- Fires for every ox drop (native drag-drop, death, throw).
    RegisterNetEvent('ox_inventory:createDrop', function(dropId, dropData)
        if not dropId or type(dropData) ~= 'table' or not dropData.coords then return end
        local coords = dropData.coords
        CreateThread(function()
            -- CustomDrop creates the drop with items already in it, and the
            -- native drag-drop also has the item swapped in by the time
            -- createDrop reaches us. No wait needed before the callback.
            local weaponHash = lib.callback.await('mbt_malisling:checkWeaponDrop', false, dropId)
            Utils.mbtDebugger("createDrop ~ dropId:", dropId, "weaponHash:", weaponHash)
            if weaponHash and weaponHash ~= 0 then
                spawnWeaponDropProp(dropId, coords, weaponHash)
            end
        end)
    end)

    RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
        removeWeaponDropProp(dropId)
    end)

    -- Hide ox's own bag prop for weapon drops so only the weapon model shows.
    -- ox spawns the bag when the player nears the drop; this loop finds it and
    -- makes it invisible + non-collidable (so ox_target's raycast hits the
    -- weapon prop, not the invisible bag).
    CreateThread(function()
        while true do
            local sleep = 1000
            if next(weaponDrops) then
                local pcoords = GetEntityCoords(cache.ped)
                for _, d in pairs(weaponDrops) do
                    -- Only hide ox's bag for drops where we spawned a weapon model.
                    if d.prop and #(pcoords - d.coords) < 30.0 then
                        sleep = 0
                        local bag = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z,
                            2.0, bagModel, false, false, false)
                        if bag ~= 0 and bag ~= d.prop and IsEntityVisible(bag) then
                            SetEntityVisible(bag, false, 0)
                            SetEntityCollision(bag, false, false)
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)
else
    -- ═══ QB PATH (fallback) ════════════════════════════════════════════════════
    local groundProps = {}  -- [dropId] = entity

    local function spawnGroundDrop(dropId, coords, weaponHash)
        if groundProps[dropId] and DoesEntityExist(groundProps[dropId]) then return end

        lib.requestWeaponAsset(weaponHash, 1000, 31, 1)
        local obj = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
        if not obj or not DoesEntityExist(obj) then return end

        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, false, true)
        local propCoords = GetEntityCoords(obj)
        groundProps[dropId] = obj

        Target.AddZone(dropId, propCoords, 1.0, {
            name     = 'mbt_wdrop_' .. dropId,
            icon     = 'fa-solid fa-hand',
            label    = Translate('pickup_weapon'),
            distance = 2.5,
            onSelect = function()
                -- On success the server broadcasts removeGroundDrop to all clients.
                lib.callback.await('mbt_malisling:lootGroundDrop', false, dropId)
            end,
        })

        -- Despawn timer: the whole qb drop is ours, so tell the server to drop it
        -- for everyone (server broadcasts removeGroundDrop). The local prop is
        -- removed by that broadcast; here we just trigger expiry.
        startDespawnTimer(dropId, obj,
            function() return groundProps[dropId] ~= nil end,
            function() TriggerServerEvent('mbt_malisling:despawnGroundDrop', dropId) end)
    end

    RegisterNetEvent('mbt_malisling:spawnGroundDrop', function(dropId, coords, weaponHash)
        spawnGroundDrop(dropId, coords, weaponHash)
    end)

    RegisterNetEvent('mbt_malisling:removeGroundDrop', function(dropId)
        local obj = groundProps[dropId]
        if obj then
            Target.RemoveZone(dropId)
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
end
