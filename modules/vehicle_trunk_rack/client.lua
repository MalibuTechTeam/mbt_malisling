-- ─────────────────────────────────────────────────────────────────────────────
-- Vehicle Trunk Weapon Rack — client
--
-- Realistic stow/retrieve of a long gun in a vehicle's trunk:
--   • ox_target option on the boot (bone-limited), gated to on-foot + long gun.
--   • Boot physically opens, a "place/take" anim plays, the weapon prop appears
--     racked in the trunk (synced to everyone via the vehicle statebag), boot shuts.
-- Persistence + validation are server-authoritative (server.lua). This file only
-- drives the interaction, animation, and renders the synced props.
--
-- ox_target is a soft dependency; without it a proximity [E] prompt is used.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.VehicleTrunkRack then return end

local cfg = MBT.VehicleTrunkRack
local DEFAULT_OFFSET = { Pos = { x = 0.0, y = -0.55, z = 0.45 }, Rot = { x = 0.0, y = 90.0, z = 0.0 } }

local CurrentWeapon = {}
local busy          = false
local rackedProps   = {}  -- [veh] = { [index] = propEntity }

AddEventHandler('ox_inventory:currentWeapon', function(w) CurrentWeapon = w or {} end)

-- ── Helpers ────────────────────────────────────────────────────────────────────
local function holdingLongGun()
    local name = CurrentWeapon and CurrentWeapon.name
    if not name then return false end
    local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]
    local t = w and w.type
    return t and cfg.AllowedTypes and cfg.AllowedTypes[t] or false
end

local function rackList(veh)
    local s = Entity(veh).state.mbt_trunkRack
    return (type(s) == 'table') and s or nil
end

local function rackCount(veh)
    local s = rackList(veh)
    return s and #s or 0
end

local function bootBone(veh)
    local b = GetEntityBoneIndexByName(veh, 'boot')
    if b == -1 then b = GetEntityBoneIndexByName(veh, 'bootlid') end
    return b
end

local function openBoot(veh)
    if NetworkGetEntityIsNetworked(veh) and not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local deadline = GetGameTimer() + 600
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < deadline do Wait(50) end
    end
    SetVehicleDoorOpen(veh, 5, false, false)   -- door 5 = boot
end

local function shutBoot(veh)
    if DoesEntityExist(veh) then SetVehicleDoorShut(veh, 5, false) end
end

local function playAnim(dict, name, ms)
    ms = ms or 1500
    if not dict or dict == '' or not name or name == '' or not DoesAnimDictExist(dict) then Wait(ms); return end
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, name, 4.0, -4.0, ms, 49, 0.0, false, false, false)
    Wait(ms)
    ClearPedTasks(cache.ped)
end

-- ── Stow / Retrieve flows ────────────────────────────────────────────────────────
local function doStow(veh)
    if busy or not cfg.Enabled or not veh or veh == 0 then return end
    if cache.vehicle or not holdingLongGun() then return end
    if GetEntitySpeed(veh) > 1.0 then return end
    busy = true

    local slot  = CurrentWeapon.slot
    local netId = VehToNet(veh)
    local a     = cfg.Animation or {}

    openBoot(veh)
    Wait(a.BootOpenDelayMs or 350)
    CreateThread(function() playAnim(a.PlaceDict, a.PlaceAnim, a.PlaceMs) end)
    local res = lib.callback.await('mbt_malisling:trunkRack:stow', false, { netId = netId, slot = slot })
    Wait(250)
    shutBoot(veh)
    busy = false

    if not res or not res.ok then
        if res and res.reason then MBT.NotifyLabel(res.reason) end
    end
end

local function retrieveIndex(veh, index)
    if busy or not cfg.Enabled or not veh or veh == 0 then return end
    if GetEntitySpeed(veh) > 1.0 then return end
    busy = true

    local netId = VehToNet(veh)
    local a     = cfg.Animation or {}

    openBoot(veh)
    Wait(a.BootOpenDelayMs or 350)
    CreateThread(function() playAnim(a.TakeDict, a.TakeAnim, a.TakeMs) end)
    local res = lib.callback.await('mbt_malisling:trunkRack:retrieve', false, { netId = netId, index = index })
    Wait(250)
    shutBoot(veh)
    busy = false

    if not res or not res.ok then
        if res and res.reason then MBT.NotifyLabel(res.reason) end
    end
end

local function doRetrieve(veh)
    local list = rackList(veh)
    if not list or #list == 0 then return end
    if #list == 1 then
        retrieveIndex(veh, 1)
        return
    end
    -- More than one racked: let the player pick which.
    local options = {}
    for i, e in ipairs(list) do
        options[#options + 1] = {
            title    = e.weapon,
            icon     = 'fa-solid fa-gun',
            onSelect = function() retrieveIndex(veh, i) end,
        }
    end
    lib.registerContext({ id = 'mbt_trunk_pick', title = Translate('trunk_retrieve'), options = options })
    lib.showContext('mbt_trunk_pick')
end

-- ── Statebag render (everyone, incl. late-join via stream-in) ─────────────────────
local function clearProps(veh)
    local t = rackedProps[veh]
    if not t then return end
    for _, p in pairs(t) do if p and DoesEntityExist(p) then DeleteEntity(p) end end
    rackedProps[veh] = nil
end

--- Clear & respawn (rack is tiny and changes rarely → simplest correct render).
local function renderRack(veh, list)
    clearProps(veh)
    if type(list) ~= 'table' or #list == 0 or not DoesEntityExist(veh) then return end
    local bone = bootBone(veh)
    rackedProps[veh] = {}
    for i, e in ipairs(list) do
        local hash = GetWeapontypeModel(joaat(e.weapon))
        if hash and hash ~= 0 then
            lib.requestWeaponAsset(hash, 1000, 31, 1)
            local obj = CreateWeaponObject(hash, 50, 0.0, 0.0, 0.0, true, 1.0, 0)
            if obj and DoesEntityExist(obj) then
                SetEntityCollision(obj, false, false)
                local off = (cfg.PropOffset and cfg.PropOffset[e.wtype]) or DEFAULT_OFFSET
                local stackZ = off.Pos.z - (i - 1) * 0.09   -- stack multiples
                AttachEntityToEntity(obj, veh, bone,
                    off.Pos.x, off.Pos.y, stackZ,
                    off.Rot.x, off.Rot.y, off.Rot.z,
                    false, false, false, false, 2, true)
                rackedProps[veh][i] = obj
            end
        end
    end
end

AddStateBagChangeHandler('mbt_trunkRack', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    if not veh or veh == 0 then return end
    renderRack(veh, value)
end)

-- Cleanup props for vehicles that no longer exist (despawn / stream-out).
CreateThread(function()
    while true do
        Wait(2000)
        for veh in pairs(rackedProps) do
            if not DoesEntityExist(veh) then clearProps(veh) end
        end
    end
end)

-- Re-publish racks for the closest vehicle (covers respawned vehicles whose bag
-- the server hasn't pushed since the restart). Debounced per net id.
CreateThread(function()
    local queried = {}
    local nextClear = GetGameTimer() + 60000
    while true do
        Wait(1500)
        if cfg.Enabled and not cache.vehicle then
            local now = GetGameTimer()
            if now > nextClear then queried = {}; nextClear = now + 60000 end
            local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0, false)
            if veh and veh ~= 0 and Entity(veh).state.mbt_trunkRack == nil then
                local netId = VehToNet(veh)
                if not queried[netId] then
                    queried[netId] = true
                    lib.callback.await('mbt_malisling:trunkRack:getRack', false, netId)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh in pairs(rackedProps) do clearProps(veh) end
end)

-- ── Interaction (ox_target preferred, [E] fallback) ──────────────────────────────
if GetResourceState('ox_target') == 'started' then
    exports.ox_target:addGlobalVehicle({
        {
            name        = 'mbt_trunk_stow',
            icon        = 'fa-solid fa-box-archive',
            label       = Translate('trunk_stow'),
            bones       = { 'boot', 'bootlid' },
            distance    = (cfg.InteractionDistance or 2.5),
            canInteract = function(entity)
                return cfg.Enabled and not cache.vehicle and holdingLongGun()
                    and rackCount(entity) < (cfg.Capacity or 2)
            end,
            onSelect = function(data) doStow(data.entity) end,
        },
        {
            name        = 'mbt_trunk_retrieve',
            icon        = 'fa-solid fa-hand',
            label       = Translate('trunk_retrieve'),
            bones       = { 'boot', 'bootlid' },
            distance    = (cfg.InteractionDistance or 2.5),
            canInteract = function(entity)
                return cfg.Enabled and not cache.vehicle and rackCount(entity) > 0
            end,
            onSelect = function(data) doRetrieve(data.entity) end,
        },
    })
else
    -- Fallback: [E] prompt at the boot of the closest vehicle.
    CreateThread(function()
        local shown = false
        while true do
            local sleep = 600
            if cfg.Enabled and not cache.vehicle then
                local ped = cache.ped
                local veh = lib.getClosestVehicle(GetEntityCoords(ped), cfg.InteractionDistance or 2.5, false)
                local atBoot = false
                if veh and veh ~= 0 then
                    local bone = bootBone(veh)
                    local bpos = (bone ~= -1) and GetWorldPositionOfEntityBone(veh, bone) or GetEntityCoords(veh)
                    if #(GetEntityCoords(ped) - bpos) < (cfg.InteractionDistance or 2.5) then atBoot = true end
                end
                local canStow     = atBoot and holdingLongGun() and rackCount(veh) < (cfg.Capacity or 2)
                local canRetrieve = atBoot and rackCount(veh) > 0
                if canStow or canRetrieve then
                    sleep = 0
                    local label = canStow and Translate('trunk_stow') or Translate('trunk_retrieve')
                    if not shown then lib.showTextUI('[E] ' .. label); shown = true end
                    if IsControlJustReleased(0, 38) then
                        if canStow then doStow(veh) else doRetrieve(veh) end
                    end
                elseif shown then
                    lib.hideTextUI(); shown = false
                end
            elseif shown then
                lib.hideTextUI(); shown = false
            end
            Wait(sleep)
        end
    end)
end
