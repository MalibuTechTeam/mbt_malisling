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
    -- coords    = where the weapon prop + ox_target zone sit (scattered when drops
    --             cluster, so neither props nor zones overlap).
    -- bagCoords = the ORIGINAL drop coords where ox spawns its bag prop (un-scattered).
    local weaponDrops = {}  -- [dropId] = { prop, coords, bagCoords }
    local bagModel = joaat(GetConvar('inventory:dropmodel', 'prop_med_bag_01b'))

    --- Hide EVERY ox bag prop at a drop spot (not just the closest one). Clustered
    --- drops stack multiple bags at ~the same point; GetClosestObjectOfType only ever
    --- returns one, so the others stayed visible + collidable and hijacked the native
    --- walk-in pickup → wrong drop opened. GetGamePool enumerates them all.
    local function hideBagsNear(coords)
        if not coords then return end
        for _, obj in ipairs(GetGamePool('CObject')) do
            if GetEntityModel(obj) == bagModel and IsEntityVisible(obj)
                and #(GetEntityCoords(obj) - coords) < 1.5 then
                SetEntityVisible(obj, false, 0)
                SetEntityCollision(obj, false, false)
            end
        end
    end

    --- Ring-scatter clustered drops (golden-angle) so props/zones/bags separate.
    local function clusterOffset(coords)
        local c, n = vector3(coords.x, coords.y, coords.z), 0
        for _, d in pairs(weaponDrops) do
            if d.bagCoords and #(c - d.bagCoords) < 0.6 then n = n + 1 end
        end
        if n == 0 then return 0.0, 0.0 end
        local ang = n * 2.39996323   -- golden angle → even spread
        local r   = 0.26 + 0.1 * n
        return math.cos(ang) * r, math.sin(ang) * r
    end

    local function removeWeaponDropProp(dropId)
        local d = weaponDrops[dropId]
        if not d then return end
        Target.RemoveZone(dropId)
        for _, p in ipairs(d.props or {}) do
            if p and DoesEntityExist(p) then DeleteEntity(p) end
        end
        weaponDrops[dropId] = nil
    end

    --- Render a drop that may hold MORE THAN ONE weapon (ox merges nearby drops).
    --- One model per weapon, ring-spread so they don't overlap; a single pickup
    --- zone for the whole drop.
    local function spawnWeaponDropProp(dropId, coords, hashes)
        if weaponDrops[dropId] then return end
        if type(hashes) ~= 'table' or #hashes == 0 then return end

        local cfg = MBT.WeaponDrop or {}
        -- Both features off → leave the drop fully native; malisling does nothing.
        if not cfg.WeaponModelProp and not cfg.OxTargetPickup then return end

        local bagCoords  = vector3(coords.x, coords.y, coords.z)
        local ox, oy     = clusterOffset(coords)
        local zoneCoords = vector3(coords.x + ox, coords.y + oy, coords.z)
        local props      = {}

        if cfg.WeaponModelProp then
            for i, weaponHash in ipairs(hashes) do
                -- Spread multiple weapons of the same drop in a small ring.
                local sx, sy = 0.0, 0.0
                if #hashes > 1 then
                    local ang = (i - 1) * (6.2831853 / #hashes)
                    sx, sy = math.cos(ang) * 0.22, math.sin(ang) * 0.22
                end
                lib.requestWeaponAsset(weaponHash, 1000, 31, 1)
                local obj = CreateWeaponObject(weaponHash, 50, zoneCoords.x + sx, zoneCoords.y + sy, zoneCoords.z, true, 1.0, 0)
                if obj and DoesEntityExist(obj) then
                    PlaceObjectOnGroundProperly(obj)
                    FreezeEntityPosition(obj, true)
                    -- Collision OFF: the interaction is a coords-based ox_target zone,
                    -- not entity raycast, so the prop needs no collision — and this
                    -- lets the player walk onto the drop for the native walk-in pickup.
                    SetEntityCollision(obj, false, true)
                    props[#props + 1] = obj
                end
            end
        end

        weaponDrops[dropId] = { props = props, coords = zoneCoords, bagCoords = bagCoords }

        -- Proactively hide ox's bag(s) at the drop spot (the loop is a safety net
        -- for re-entry; this initial swap is what the player actually sees).
        if #props > 0 then hideBagsNear(bagCoords) end

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
        -- props on all clients (removeWeaponDropProp). Real despawn, not just local.
        if #props > 0 then
            startDespawnTimer(dropId, props[1],
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
            local hashes = lib.callback.await('mbt_malisling:checkWeaponDrop', false, dropId)
            if type(hashes) == 'table' and #hashes > 0 then
                spawnWeaponDropProp(dropId, coords, hashes)
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
                -- Collect the bag spots in range, then run ONE pool scan (GetGamePool
                -- is heavy — never per-drop-per-frame). Throttled to 300ms.
                local spots, near = {}, false
                for _, d in pairs(weaponDrops) do
                    if d.props and #d.props > 0 and d.bagCoords and #(pcoords - d.coords) < 30.0 then
                        near = true
                        spots[#spots + 1] = d.bagCoords
                    end
                end
                if near then
                    sleep = 300
                    for _, obj in ipairs(GetGamePool('CObject')) do
                        if GetEntityModel(obj) == bagModel and IsEntityVisible(obj) then
                            for i = 1, #spots do
                                if #(GetEntityCoords(obj) - spots[i]) < 1.5 then
                                    SetEntityVisible(obj, false, 0)
                                    SetEntityCollision(obj, false, false)
                                    break
                                end
                            end
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
