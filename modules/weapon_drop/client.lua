-- ── Weapon drop — client ──
-- ox path: on ox_inventory:createDrop (every drop), ask the server if it holds a weapon,
--   render the weapon model via CreateWeaponObject + ox_target, hide ox's bag prop.
-- qb path (fallback): spawn malisling's own ground-drop prop from the server broadcast;
--   loot hands the item straight back.

local isOx = GetResourceState('ox_inventory') == 'started'
local CurrentWeapon = {}

AddEventHandler('ox_inventory:currentWeapon', function(currentWeapon)
    CurrentWeapon = currentWeapon or {}
end)

-- ── Despawn timer (shared) ──
-- Per-drop timer that blinks the prop in the final seconds, then calls onExpire().
-- Cancelled by clearing the drop before it fires (loop checks stillValid + prop exists).
---@param stillValid fun():boolean false once the drop was removed
local function startDespawnTimer(dropId, prop, stillValid, onExpire)
    local cfg = (MBT.WeaponDrop or {}).Despawn
    if not cfg or not cfg.Enabled or not prop then return end
    CreateThread(function()
        local total = (cfg.Seconds or 300) * 1000
        local blink = (cfg.BlinkLastSec or 0) * 1000
        local elapsed = 0
        while elapsed < total do
            if not stillValid() or not DoesEntityExist(prop) then return end
            -- Blink window: toggle visibility ~twice a second.
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

-- ── Drop-on-death (shared) ──
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

-- ── Manual drop (export, shared) ──
function dropCurrentWeapon()
    if not CurrentWeapon or not CurrentWeapon.hash or not CurrentWeapon.slot then return end

    local playerPed = cache.ped
    local boneIndex = GetPedBoneIndex(playerPed, 57005)
    local bonePos = GetWorldPositionOfEntityBone(playerPed, boneIndex)
    local weaponModel = GetWeapontypeModel(CurrentWeapon.hash)
    local currentWeapon = Utils.tableDeepCopy(CurrentWeapon)
    lib.requestModel(weaponModel)
    equippedWeapon.dropped = true
    -- Temporary physics object: let it fall and settle so we know where it lands, then send those coords.
    local weaponObj = CreateObject(weaponModel, bonePos.x, bonePos.y, bonePos.z, true, true, true)
    ActivatePhysics(weaponObj)
    TriggerEvent("ox_inventory:disarm", true)
    local airDeadline = GetGameTimer() + 3000   -- never block forever (dropped over water/off-map)
    while IsEntityInAir(weaponObj) and GetGameTimer() < airDeadline do Wait(100) end
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
    -- ═══ OX PATH ═══
    -- coords    = where prop + ox_target zone sit (scattered when drops cluster, so neither overlap).
    -- bagCoords = the ORIGINAL drop coords where ox spawns its bag prop (un-scattered).
    local weaponDrops = {}  -- [dropId] = { prop, coords, bagCoords }
    local bagModel = joaat(GetConvar('inventory:dropmodel', 'prop_med_bag_01b'))

    --- Hide EVERY ox bag prop at a drop spot. Clustered drops stack multiple bags at ~one point;
    --- GetClosestObjectOfType returns only one, leaving others visible+collidable to hijack walk-in
    --- pickup → wrong drop opened. GetGamePool enumerates them all.
    local function hideBagsNear(coords)
        if not coords then return end
        -- Pool scan only worth it when close enough to see the bag; skip for far drops.
        if #(GetEntityCoords(cache.ped) - coords) > 30.0 then return end
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

    --- (Re)build the weapon models for a drop, ring-spread around its zone. Deletes previous
    --- models first — used on first render and on refresh (ox adds a 2nd weapon to an EXISTING
    --- drop without re-firing createDrop, so the rendered set can go stale).
    local function buildProps(dropId, hashes)
        local d = weaponDrops[dropId]
        if not d then return end
        for _, p in ipairs(d.props) do if p and DoesEntityExist(p) then DeleteEntity(p) end end
        d.props = {}
        if not (MBT.WeaponDrop or {}).WeaponModelProp then d.count = #hashes; return end

        local n = #hashes
        for i, weaponHash in ipairs(hashes) do
            local sx, sy = 0.0, 0.0
            if n > 1 then
                local ang = (i - 1) * (6.2831853 / n)
                sx, sy = math.cos(ang) * 0.22, math.sin(ang) * 0.22
            end
            lib.requestWeaponAsset(weaponHash, 1000, 31, 1)
            local obj = CreateWeaponObject(weaponHash, 50, d.coords.x + sx, d.coords.y + sy, d.coords.z, true, 1.0, 0)
            RemoveWeaponAsset(weaponHash)   -- object keeps its model; release the asset
            if obj and DoesEntityExist(obj) then
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                -- Collision COMPLETELY off (incl. raycast): interaction is a coords-based ox_target
                -- sphere, so props must be transparent to the targeting raycast — else a prop
                -- intercepts the eye and the sphere can't be selected. Also enables walk-in pickup.
                SetEntityCollision(obj, false, false)
                d.props[#d.props + 1] = obj
            end
        end
        d.count = n
        if #d.props > 0 then hideBagsNear(d.bagCoords) end

        -- (Re)start the despawn timer on the current anchor prop. A generation token retires
        -- the previous timer so a rebuild doesn't kill the despawn or leave two timers running.
        d.gen = (d.gen or 0) + 1
        local myGen = d.gen
        if d.props[1] then
            startDespawnTimer(dropId, d.props[1],
                function() return weaponDrops[dropId] ~= nil and weaponDrops[dropId].gen == myGen end,
                function() TriggerServerEvent('mbt_malisling:despawnWeaponDrop', dropId) end)
        end
    end

    --- Render a drop that may hold MORE THAN ONE weapon. One model per weapon, ring-spread; one zone.
    local function spawnWeaponDropProp(dropId, coords, hashes)
        if weaponDrops[dropId] then return end
        if type(hashes) ~= 'table' or #hashes == 0 then return end

        local cfg = MBT.WeaponDrop or {}
        -- Both features off → leave the drop fully native.
        if not cfg.WeaponModelProp and not cfg.OxTargetPickup then return end

        local ox, oy = clusterOffset(coords)
        weaponDrops[dropId] = {
            props     = {},
            coords    = vector3(coords.x + ox, coords.y + oy, coords.z),
            bagCoords = vector3(coords.x, coords.y, coords.z),
            count     = 0,
        }
        buildProps(dropId, hashes)

        -- (buildProps already started the despawn timer, gen-guarded.)
        if cfg.OxTargetPickup then
            Target.AddZone(dropId, weaponDrops[dropId].coords, 1.5, {
                name     = 'mbt_wdrop_' .. dropId,
                icon     = 'fa-solid fa-hand',
                label    = Translate('pickup_weapon'),
                distance = 2.5,
                onSelect = function()
                    exports.ox_inventory:openInventory('drop', dropId)
                end,
            })
        end
    end

    -- Refresh: ox doesn't re-fire createDrop when a weapon is ADDED to an existing drop,
    -- so re-query nearby drops and rebuild their models on count change. Only within 8m, every 1.5s.
    CreateThread(function()
        while true do
            Wait(1500)
            if next(weaponDrops) then
                local pc = GetEntityCoords(cache.ped)
                for dropId, d in pairs(weaponDrops) do
                    if #(pc - d.coords) < 8.0 then
                        local hashes = lib.callback.await('mbt_malisling:checkWeaponDrop', false, dropId)
                        if type(hashes) == 'table' and #hashes ~= (d.count or 0) and weaponDrops[dropId] then
                            buildProps(dropId, hashes)
                        end
                    end
                end
            end
        end
    end)

    -- Fires for every ox drop (native drag-drop, death, throw).
    RegisterNetEvent('ox_inventory:createDrop', function(dropId, dropData)
        if not dropId or type(dropData) ~= 'table' or not dropData.coords then return end
        local coords = dropData.coords
        CreateThread(function()
            -- Items are already in the drop by the time createDrop reaches us
            -- (CustomDrop and native drag-drop both), so no wait before the callback.
            local hashes = lib.callback.await('mbt_malisling:checkWeaponDrop', false, dropId)
            if type(hashes) == 'table' and #hashes > 0 then
                spawnWeaponDropProp(dropId, coords, hashes)
            end
        end)
    end)

    RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
        removeWeaponDropProp(dropId)
    end)

    -- Hide ox's bag prop so only the weapon model shows. ox spawns the bag when the player nears;
    -- we make it invisible + non-collidable (so ox_target's raycast hits the weapon, not the bag).
    -- TARGETED GetClosestObjectOfType per bag spot is far cheaper than a full pool scan, so we poll
    -- fast (50ms) and catch the bag the instant it spawns — killing the "stock bag" flash. Re-hides on respawn.
    CreateThread(function()
        while true do
            local sleep = 1000
            if next(weaponDrops) then
                local pcoords = GetEntityCoords(cache.ped)
                local near = false
                for _, d in pairs(weaponDrops) do
                    if d.props and #d.props > 0 and d.bagCoords and #(pcoords - d.coords) < 30.0 then
                        near = true
                        local s = d.bagCoords
                        local bag = GetClosestObjectOfType(s.x, s.y, s.z, 1.5, bagModel, false, false, false)
                        if bag ~= 0 and IsEntityVisible(bag) then
                            SetEntityVisible(bag, false, 0)
                            SetEntityCollision(bag, false, false)
                        end
                    end
                end
                if near then sleep = 50 end
            end
            Wait(sleep)
        end
    end)
else
    -- ═══ QB PATH (fallback) ═══
    local groundProps = {}  -- [dropId] = entity

    local function spawnGroundDrop(dropId, coords, weaponHash)
        if groundProps[dropId] and DoesEntityExist(groundProps[dropId]) then return end

        lib.requestWeaponAsset(weaponHash, 1000, 31, 1)
        local obj = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
        RemoveWeaponAsset(weaponHash)   -- object keeps its model; release the asset
        if not obj or not DoesEntityExist(obj) then return end

        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, false, true)
        local propCoords = GetEntityCoords(obj)
        groundProps[dropId] = obj

        Target.AddZone(dropId, propCoords, 1.5, {
            name     = 'mbt_wdrop_' .. dropId,
            icon     = 'fa-solid fa-hand',
            label    = Translate('pickup_weapon'),
            distance = 2.5,
            onSelect = function()
                -- On success the server broadcasts removeGroundDrop to all clients.
                lib.callback.await('mbt_malisling:lootGroundDrop', false, dropId)
            end,
        })

        -- Despawn timer: the whole qb drop is ours, so tell the server to drop it for
        -- everyone (it broadcasts removeGroundDrop, which removes the local prop).
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
