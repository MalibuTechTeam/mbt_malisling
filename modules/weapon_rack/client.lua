-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Rack / Gun Locker — client
--
-- Spawns config-defined rack props, lets a player stow/retrieve a weapon (ox_target
-- or an [E] fallback), and renders racked weapons attached to the prop. Contents
-- replicate via GlobalState (mbt_weaponRacks); the prop is local + identical per
-- client, so only contents sync. Persistence + validation are server-authoritative.
--
-- Weapon props ATTACH to the frozen rack prop, so offsets live in the rack's LOCAL
-- space — heading is automatic, none of the gimbal math the vehicle trunk needs.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.WeaponRack then return end

local cfg = MBT.WeaponRack

local CurrentWeapon = {}
local busy          = false
local spawnedRacks  = {}  -- [id] = { prop, blip, loc }
local rackedProps   = {}  -- [id] = { props = { [i] = obj }, count }
local rackData      = {}  -- [id] = { { weapon, wtype }, ... }  (mirror of GlobalState)

AddEventHandler('ox_inventory:currentWeapon', function(w) CurrentWeapon = w or {} end)

local weaponTypeOf = Utils.weaponType

local function holdingAllowed()
    local t = weaponTypeOf(CurrentWeapon and CurrentWeapon.name)
    return (t and cfg.AllowedTypes and cfg.AllowedTypes[t]) or false
end

local function rackCount(id)
    local l = rackData[id]
    return l and #l or 0
end

--- Local-space attach offset for the i-th weapon of type wtype: per-type config base, shifted along SlotAxis so successive weapons don't overlap.
local function slotOffset(wtype, i)
    local o = (cfg.Offsets and cfg.Offsets[wtype]) or { Pos = { x = 0.0, y = 0.0, z = 1.0 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } }
    local px, py, pz = o.Pos.x or 0.0, o.Pos.y or 0.0, o.Pos.z or 0.0
    local d = (i - 1) * (cfg.SlotSpacing or 0.22)
    local axis = cfg.SlotAxis or 'x'
    if axis == 'y' then py = py + d elseif axis == 'z' then pz = pz + d else px = px + d end
    return px, py, pz, (o.Rot or { x = 0.0, y = 0.0, z = 0.0 })
end

--- Play one anim step ({Dict, Anim, Ms, Flag?}); missing/bad dicts degrade to a wait.
--- Flag defaults to 49 (upper-body loop, fits give/take gestures); pass Flag = 2 for
--- a full-body hold-last-frame clip (e.g. the kneel-and-place rack install).
local function playAnimStep(step)
    if type(step) ~= 'table' then return end
    local ms = step.Ms or 800
    if not step.Dict or step.Dict == '' or not step.Anim or step.Anim == ''
        or not DoesAnimDictExist(step.Dict) then Wait(ms); return end
    lib.requestAnimDict(step.Dict)
    TaskPlayAnim(cache.ped, step.Dict, step.Anim, 4.0, -4.0, ms, step.Flag or 49, 0.0, false, false, false)
    Wait(ms)
    ClearPedTasks(cache.ped)
end

--- Play a config-driven anim SEQUENCE (list of steps, in order).
local function playAnimSequence(steps)
    if type(steps) ~= 'table' or #steps == 0 then return end
    for i = 1, #steps do playAnimStep(steps[i]) end
end

--- Turn the ped toward the rack before the gesture (config toggle).
local function faceRack(id)
    local a = cfg.Animation or {}
    if a.FaceRack == false then return end
    local sr = spawnedRacks[id]
    if not sr or not sr.prop or not DoesEntityExist(sr.prop) then return end
    TaskTurnPedToFaceEntity(cache.ped, sr.prop, 450)
    Wait(450)
end

--- Weapon-handling sound (holster on place / unholster on take), synced to nearby players via the sounds module events.
local function rackSound(action, wtype)
    local a = cfg.Animation or {}
    if a.Sound == false or not wtype then return end
    TriggerEvent(action == 'place' and 'mbt_malisling:onHolster' or 'mbt_malisling:onUnholster', wtype)
end

local function clearProps(id)
    local r = rackedProps[id]
    if not r then return end
    for _, p in pairs(r.props) do if p and DoesEntityExist(p) then DeleteEntity(p) end end
    rackedProps[id] = nil
end

local function renderRack(id)
    clearProps(id)
    local sr   = spawnedRacks[id]
    local list = rackData[id]
    if not sr or not sr.prop or not DoesEntityExist(sr.prop) or not list or #list == 0 then return end
    local props = {}
    for i, e in ipairs(list) do
        local hash = joaat(e.weapon)
        if hash and hash ~= 0 then
            lib.requestWeaponAsset(hash, 1000, 31, 1)
            local obj = CreateWeaponObject(hash, 50, 0.0, 0.0, 0.0, true, 1.0, 0)
            RemoveWeaponAsset(hash)   -- object keeps its model; don't leave the asset resident
            if obj and DoesEntityExist(obj) then
                SetEntityCollision(obj, false, false)
                local px, py, pz, rot = slotOffset(e.wtype, i)
                -- isPed = FALSE: target is a prop, not a ped. Local-space attach.
                AttachEntityToEntity(obj, sr.prop, 0, px, py, pz, rot.x, rot.y, rot.z,
                    false, false, false, false, 2, true)
                props[i] = obj
            end
        end
    end
    rackedProps[id] = { props = props, count = #list }
end

--- Content signature (weapon names + order/count) so refreshAll skips unchanged racks: the whole map is ONE GlobalState bag, so every stow/retrieve fires for ALL clients and without this diff each would re-render EVERY rack.
local rackSig = {}   -- [id] = last rendered signature
local function listSig(list)
    if not list then return '' end
    local parts = {}
    for i = 1, #list do parts[i] = list[i].weapon or '?' end
    return table.concat(parts, '|')
end

--- Re-render only the spawned racks whose GlobalState contents actually changed.
local function refreshAll(value)
    local map = (type(value) == 'table') and value or (GlobalState.mbt_weaponRacks or {})
    for id in pairs(spawnedRacks) do
        local list = map[id]
        list = (type(list) == 'table' and #list > 0) and list or nil
        local sig = listSig(list)
        if sig ~= rackSig[id] then
            rackData[id] = list
            rackSig[id]  = sig
            renderRack(id)
        end
    end
end

AddStateBagChangeHandler('mbt_weaponRacks', 'global', function(_, _, value)
    refreshAll(value)
end)

-- ── Stow / Retrieve ────────────────────────────────────────────────────────────
local function doStow(id)
    if busy or not cfg.Enabled then return end
    if cache.vehicle or not holdingAllowed() then return end
    busy = true
    local slot  = CurrentWeapon.slot
    local wtype = weaponTypeOf(CurrentWeapon.name)
    local a = cfg.Animation or {}
    -- Server-validate BEFORE the place animation: no access → notify only, never the
    -- gesture.
    faceRack(id)
    local res = lib.callback.await('mbt_malisling:weaponRack:stow', false, { id = id, slot = slot })
    busy = false
    if res and res.ok then
        playAnimSequence(a.Place)
        rackSound('place', wtype)
    elseif res and res.reason then
        MBT.NotifyLabel(res.reason)
    end
end

local function retrieveIndex(id, index)
    if busy or not cfg.Enabled then return end
    busy = true
    local a = cfg.Animation or {}
    faceRack(id)
    local res = lib.callback.await('mbt_malisling:weaponRack:retrieve', false, { id = id, index = index })
    busy = false
    if res and res.ok then
        playAnimSequence(a.Take)
        local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[res.name]
        rackSound('take', w and w.type)
        if cfg.EquipOnRetrieve then
            if GetResourceState('ox_inventory') == 'started' and res.equipSlot then
                exports.ox_inventory:useSlot(res.equipSlot)
            elseif GetResourceState('qb-inventory') == 'started' and res.name
                and PlayerData and PlayerData.items then
                for _, it in pairs(PlayerData.items) do
                    -- qb item names are lowercase; res.name is UPPER.
                    if it.name and it.name:upper() == res.name
                        and (not res.serial or (it.info and it.info.serie == res.serial)) then
                        TriggerServerEvent('qb-inventory:server:useItem', it)
                        break
                    end
                end
            end
        end
    elseif res and res.reason then
        MBT.NotifyLabel(res.reason)
    end
end

-- ── Weapon picker (custom NUI, key-driven — no mouse focus) ──
--- durability (0-100) → localized condition label + tone, like the Inspect overlay.
local function conditionInfo(dur)
    if dur == nil then return nil, nil end
    local label
    local tiers = MBT.Inspect and MBT.Inspect.ConditionTiers
    if tiers then
        for i = 1, #tiers do
            if dur >= tiers[i].Min then label = Translate(tiers[i].Key) break end
        end
    end
    local tone = (dur >= 60 and 'good') or (dur >= 35 and 'warn') or 'bad'
    return label, tone
end

local picker = nil   -- { id, idx, n }

local function closePicker(takeIdx)
    if not picker then return end
    local id = picker.id
    picker = nil
    SendNUIMessage({ action = 'hideRackPicker', data = {} })
    if takeIdx then retrieveIndex(id, takeIdx) end
end

local function openPicker(id)
    if picker then return end
    local list = rackData[id]
    if not list or #list == 0 then return end
    local entries = {}
    for i, e in ipairs(list) do
        local cond, tone = conditionInfo(e.dur)
        entries[i] = {
            name      = e.label or e.weapon,   -- engraved custom name, or weapon code
            serial    = e.serial,
            condition = cond,
            tone      = tone,
        }
    end
    picker = { id = id, idx = 1, n = #entries }
    SendNUIMessage({ action = 'showRackPicker',
        data = { locale = buildNuiLocale(), weapons = entries, index = 1, style = MBT.UIStyle or 'standard' } })

    CreateThread(function()
        local sr = spawnedRacks[id]
        while picker do
            Wait(0)
            -- Block conflicting inputs while picking (incl. attack).
            for _, c in ipairs({ 172, 173, 191, 177, 38, 24, 25, 140, 141, 142 }) do
                DisableControlAction(0, c, true)
            end
            if IsDisabledControlJustPressed(0, 172) then        -- ↑
                picker.idx = (picker.idx - 2) % picker.n + 1
                SendNUIMessage({ action = 'updateRackPicker', data = { index = picker.idx } })
            elseif IsDisabledControlJustPressed(0, 173) then    -- ↓
                picker.idx = picker.idx % picker.n + 1
                SendNUIMessage({ action = 'updateRackPicker', data = { index = picker.idx } })
            elseif IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 38) then
                closePicker(picker.idx)                          -- ENTER / E → take
            elseif IsDisabledControlJustPressed(0, 177) then
                closePicker(nil)                                 -- BACKSPACE → cancel
            end
            -- Auto-close when walking away or if the rack vanished.
            if picker and sr and sr.prop and DoesEntityExist(sr.prop)
                and #(GetEntityCoords(cache.ped) - GetEntityCoords(sr.prop)) > (cfg.InteractionDistance or 2.0) + 1.5 then
                closePicker(nil)
            end
        end
    end)
end

local function doRetrieve(id)
    local list = rackData[id]
    if not list or #list == 0 then return end
    if #list == 1 then retrieveIndex(id, 1); return end
    openPicker(id)
end

-- ── Spawn / despawn the rack props ──
-- Own identifier (for owner-only pickup), prefetched: canInteract runs every frame on
-- hover so it must NOT await. Gotcha: early after a resource start the framework player
-- isn't loaded, so the bridge returns a fallback (server id as string); caching that
-- would never match the real owner identifier → owner could never pick their rack up.
-- Reject the fallback and retry until we get the real char identifier.
local myIdentifier = nil
local myServerId = tostring(GetPlayerServerId(PlayerId()))
CreateThread(function()
    Wait(2000)
    while not myIdentifier do
        local id = lib.callback.await('mbt_malisling:weaponRack:whoami', false)
        if id and id ~= '' and id ~= myServerId then myIdentifier = id break end
        Wait(3000)
    end
end)

local doPickup   -- forward declaration (defined with the placement flow below)

local function addTarget(id, prop)
    if GetResourceState('ox_target') ~= 'started' then return end
    exports.ox_target:addLocalEntity(prop, {
        {
            name        = 'mbt_rack_stow_' .. id,
            icon        = 'fa-solid fa-box-archive',
            label       = Translate('rack_stow'),
            distance    = cfg.InteractionDistance or 2.0,
            canInteract = function()
                return cfg.Enabled and not cache.vehicle and holdingAllowed()
                    and rackCount(id) < (cfg.Capacity or 4)
            end,
            onSelect = function() doStow(id) end,
        },
        {
            name        = 'mbt_rack_retrieve_' .. id,
            icon        = 'fa-solid fa-hand',
            label       = Translate('rack_retrieve'),
            distance    = cfg.InteractionDistance or 2.0,
            canInteract = function()
                return cfg.Enabled and not cache.vehicle and rackCount(id) > 0
            end,
            onSelect = function() doRetrieve(id) end,
        },
        {
            -- Owner-only: dismount an EMPTY item-placed rack, get the item back.
            name        = 'mbt_rack_pickup_' .. id,
            icon        = 'fa-solid fa-screwdriver-wrench',
            label       = Translate('rack_pickup'),
            distance    = cfg.InteractionDistance or 2.0,
            canInteract = function()
                local sr = spawnedRacks[id]
                local owner = sr and sr.loc and sr.loc.owner
                -- Permissive on unresolved identifier so the owner always sees it
                -- (server re-checks owner/ACE on pickup anyway).
                return cfg.Enabled and not cache.vehicle and owner
                    and cfg.Placement and cfg.Placement.Enabled and cfg.Placement.AllowPickup ~= false
                    and rackCount(id) == 0 and (not myIdentifier or myIdentifier == owner)
            end,
            onSelect = function() doPickup(id) end,
        },
    })
end

local function spawnRack(loc)
    local model = loc.prop or cfg.DefaultProp
    if not lib.requestModel(model, 5000) then
        Utils.mbtWarn(('weapon_rack ~ prop model for rack "%s" failed to load'):format(tostring(loc.id)))
        return
    end
    local c = loc.coords
    local prop = CreateObject(model, c.x, c.y, c.z, false, false, false)
    if not prop or not DoesEntityExist(prop) then SetModelAsNoLongerNeeded(model); return end
    SetEntityHeading(prop, c.w or 0.0)
    FreezeEntityPosition(prop, true)
    SetModelAsNoLongerNeeded(model)

    local blip
    if cfg.Blip and cfg.Blip.Enabled then
        blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, cfg.Blip.Sprite or 110)
        SetBlipColour(blip, cfg.Blip.Color or 1)
        SetBlipScale(blip, cfg.Blip.Scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(loc.label or cfg.Blip.Label or 'Armory')
        EndTextCommandSetBlipName(blip)
    end

    spawnedRacks[loc.id] = { prop = prop, blip = blip, loc = loc }
    addTarget(loc.id, prop)

    -- Initial contents from GlobalState (covers join after weapons were racked).
    local g = GlobalState.mbt_weaponRacks
    local list = type(g) == 'table' and g[loc.id]
    rackData[loc.id] = (type(list) == 'table' and #list > 0) and list or nil
    renderRack(loc.id)
end

local function despawnRack(id)
    clearProps(id)
    local sr = spawnedRacks[id]
    if not sr then return end
    if sr.prop and DoesEntityExist(sr.prop) then
        if GetResourceState('ox_target') == 'started' then
            pcall(function() exports.ox_target:removeLocalEntity(sr.prop, {
                'mbt_rack_stow_' .. id, 'mbt_rack_retrieve_' .. id, 'mbt_rack_pickup_' .. id }) end)
        end
        DeleteEntity(sr.prop)
    end
    if sr.blip then RemoveBlip(sr.blip) end
    spawnedRacks[id] = nil
    rackData[id] = nil
end

-- Keep the world in sync with cfg.Enabled (dashboard toggle spawns/despawns without a
-- restart) and the Locations list.
CreateThread(function()
    while not MBT.WeaponsInfo do Wait(250) end
    -- Spawn existing runtime-placed (admin) racks (covers late join / re-init).
    local dyn = lib.callback.await('mbt_malisling:weaponRack:getDynamic', false)
    if type(dyn) == 'table' then
        for _, loc in ipairs(dyn) do
            if type(loc) == 'table' and type(loc.id) == 'string' and not spawnedRacks[loc.id] then
                spawnRack(loc)
            end
        end
    end
    while true do
        if cfg.Enabled then
            for _, loc in ipairs(cfg.Locations or {}) do
                if type(loc) == 'table' and type(loc.id) == 'string' and loc.coords
                    and not spawnedRacks[loc.id] then
                    spawnRack(loc)
                end
            end
        else
            for id in pairs(spawnedRacks) do despawnRack(id) end
        end
        Wait(3000)
    end
end)

-- ── [E] fallback when ox_target isn't installed ──
if GetResourceState('ox_target') ~= 'started' then
    CreateThread(function()
        local shown = false
        while true do
            local sleep = 600
            if cfg.Enabled and not cache.vehicle and next(spawnedRacks) then
                local pc = GetEntityCoords(cache.ped)
                local near, nd = nil, (cfg.InteractionDistance or 2.0)
                for id, sr in pairs(spawnedRacks) do
                    local d = #(pc - GetEntityCoords(sr.prop))
                    if d < nd then near, nd = id, d end
                end
                local canStow     = near and holdingAllowed() and rackCount(near) < (cfg.Capacity or 4)
                local canRetrieve = near and rackCount(near) > 0
                if canStow or canRetrieve then
                    sleep = 0
                    if not shown then
                        lib.showTextUI('[E] ' .. (canStow and Translate('rack_stow') or Translate('rack_retrieve')))
                        shown = true
                    end
                    if IsControlJustReleased(0, 38) then
                        if canStow then doStow(near) else doRetrieve(near) end
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

-- ── Setup helper: /mbt_rackcoords ──
-- Prints + copies a ready-to-paste MBT.WeaponRack.Locations line for a FIXED rack
-- (item-based placement is a separate flow, below). Stand where you want it, facing
-- it, and run it; tweak the heading (last number) and prop as needed.
local rackCoordSeq = 0
RegisterCommand('mbt_rackcoords', function()
    local c = GetEntityCoords(cache.ped)
    local h = GetEntityHeading(cache.ped)
    rackCoordSeq = rackCoordSeq + 1
    -- Default prop name printed for convenience; swap for your rack/locker model.
    local line = ("{ id = 'rack_%d', coords = vec4(%.2f, %.2f, %.2f, %.1f), prop = `xm_prop_xm_gunlocker_01a`, job = false, label = 'Armory' },")
        :format(rackCoordSeq, c.x, c.y, c.z, h)
    -- Console echo is Debug-gated; clipboard + notify below always deliver it.
    Utils.mbtDebugger('Weapon Rack location -> paste into MBT.WeaponRack.Locations:\n' .. line)
    if lib.setClipboard then lib.setClipboard(line) end
    lib.notify({
        type = 'success', title = 'Weapon Rack',
        description = 'Location line copied to clipboard + printed to F8.',
    })
end, false)

-- ── Player placement (inventory item): carry ghost → rotate → mount ──
-- Use the rack item → ped CARRIES the locker (box-carry loop, walkable) while a ghost
-- preview floats in front; ←/→ rotates, E confirms (install gesture, then solidify),
-- BACKSPACE cancels.
local placing = false

local function showPlaceHints()
    SendNUIMessage({ action = 'showHint', data = { style = MBT.UIStyle or 'standard', items = {
        { k = '←/→',  l = Translate('rack_hint_rotate') },
        { k = 'SHIFT', l = Translate('rack_hint_fast') },
        { k = 'E',     l = Translate('rack_hint_place') },
        { k = 'BSPC',  l = Translate('rack_hint_cancel') },
    } } })
end

local function hidePlaceHints()
    SendNUIMessage({ action = 'hideHint', data = {} })
end

local function startCarry()
    local a = (cfg.Placement and cfg.Placement.CarryAnim) or {}
    if not a.Dict or not DoesAnimDictExist(a.Dict) then return end
    lib.requestAnimDict(a.Dict)
    TaskPlayAnim(cache.ped, a.Dict, a.Anim, 4.0, -4.0, -1, a.Flag or 50, 0.0, false, false, false)
end

local function stopCarry()
    local a = (cfg.Placement and cfg.Placement.CarryAnim) or {}
    if a.Dict and a.Anim then StopAnimTask(cache.ped, a.Dict, a.Anim, 2.0) end
    ClearPedTasks(cache.ped)
end

RegisterNetEvent('mbt_malisling:weaponRack:startPlace', function()
    if placing or not cfg.Enabled or not cfg.Placement or not cfg.Placement.Enabled then return end
    if cache.vehicle then return end
    placing = true

    local model = cfg.Placement.Prop or cfg.DefaultProp
    if not lib.requestModel(model, 5000) then placing = false return end
    local ghost = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    if not ghost or not DoesEntityExist(ghost) then
        SetModelAsNoLongerNeeded(model); placing = false; return
    end
    SetEntityAlpha(ghost, 160, false)
    SetEntityCollision(ghost, false, false)
    SetModelAsNoLongerNeeded(model)

    startCarry()
    showPlaceHints()
    local rotOff = 0.0
    local heading = GetEntityHeading(cache.ped)

    --- Raycast where the CAMERA aims (build-mode feel: ghost sits under your crosshair, not glued in front of the ped).
    local function camAimPoint()
        local cam = GetGameplayCamCoord()
        local rot = GetGameplayCamRot(2)
        local rx, rz = math.rad(rot.x), math.rad(rot.z)
        local dir = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
        local dest = cam + dir * 9.0
        local ray = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1, cache.ped, 0)
        local _, hit, coords = GetShapeTestResult(ray)
        if hit == 1 then return coords end
        return nil
    end

    CreateThread(function()
        local lastX, lastY, lastZ, lastW = 0.0, 0.0, 0.0, 0.0
        while placing do
            Wait(0)
            -- ←/→ rotate (SHIFT = fast) · E confirm · BACKSPACE cancel
            for _, c in ipairs({ 174, 175, 38, 177, 21, 24, 25 }) do DisableControlAction(0, c, true) end
            local step = IsDisabledControlPressed(0, 21) and 4.0 or 1.5
            if IsDisabledControlPressed(0, 174) then rotOff = (rotOff - step) % 360.0 end
            if IsDisabledControlPressed(0, 175) then rotOff = (rotOff + step) % 360.0 end

            -- Ghost at the camera aim point (clamped to reach), ground-snapped;
            -- falls back to "1.7m ahead" when aiming at sky / out of reach.
            local pc  = GetEntityCoords(cache.ped)
            local aim = camAimPoint()
            if aim and #(pc - aim) > 6.0 then aim = nil end
            local p = aim or GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.7, 0.0)
            local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 0.6, false)
            lastX, lastY, lastZ = p.x, p.y, found and gz or p.z
            lastW = (heading + rotOff) % 360.0
            SetEntityCoords(ghost, lastX, lastY, lastZ, false, false, false, false)
            SetEntityHeading(ghost, lastW)

            if IsDisabledControlJustPressed(0, 38) then            -- E → mount it
                placing = false
                hidePlaceHints()
                stopCarry()
                if DoesEntityExist(ghost) then DeleteEntity(ghost) end
                -- Validate + install FIRST; play the gesture only on server accept
                -- (nothing plays on "too close"/"limit").
                local res = lib.callback.await('mbt_malisling:weaponRack:placeItem', false,
                    { x = lastX, y = lastY, z = lastZ, w = lastW })
                if res and res.ok then
                    playAnimStep(cfg.Placement.InstallAnim)   -- mount gesture (degrades safely)
                    MBT.NotifyLabel('rack_placed')
                elseif res and res.reason then
                    MBT.NotifyLabel(res.reason)
                end
            elseif IsDisabledControlJustPressed(0, 177) then       -- BACKSPACE → cancel
                placing = false
                hidePlaceHints()
                stopCarry()
                if DoesEntityExist(ghost) then DeleteEntity(ghost) end
            end
        end
        -- Safety: never leak the ghost.
        if not placing and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    end)
end)

--- Owner pickup: short dismount gesture → item back, rack gone (server-validated).
function doPickup(id)
    if busy or placing then return end
    busy = true
    playAnimStep(cfg.Placement and cfg.Placement.PickupAnim)   -- dismount gesture
    local res = lib.callback.await('mbt_malisling:weaponRack:pickup', false, id)
    busy = false
    if res and res.ok then
        MBT.NotifyLabel('rack_picked_up')
    elseif res and res.reason then
        MBT.NotifyLabel(res.reason)
    end
end

-- ── Runtime placement (admin) — spawn/despawn pushed by the server ──
RegisterNetEvent('mbt_malisling:weaponRack:spawn', function(loc)
    if type(loc) ~= 'table' or type(loc.id) ~= 'string' or spawnedRacks[loc.id] then return end
    if not cfg.Enabled then return end
    spawnRack(loc)
end)

RegisterNetEvent('mbt_malisling:weaponRack:despawn', function(id)
    if type(id) == 'string' then despawnRack(id) end
end)

-- Quick placement: drop a rack ~1.3m in front of you (admin only, enforced
-- server-side). Runtime-only (resets on restart). /mbt_removerack clears the nearest.
RegisterCommand('mbt_placerack', function()
    local ped = cache.ped
    local c   = GetEntityCoords(ped)
    local f   = GetEntityForwardVector(ped)
    local x, y = c.x + f.x * 1.3, c.y + f.y * 1.3
    local found, gz = GetGroundZFor_3dCoord(x, y, c.z + 1.0, false)
    TriggerServerEvent('mbt_malisling:weaponRack:place', {
        x = x, y = y, z = found and gz or c.z,
        w = GetEntityHeading(ped) % 360.0,   -- front follows your facing
    })
end, false)

RegisterCommand('mbt_removerack', function()
    local pc = GetEntityCoords(cache.ped)
    local near, nd = nil, 5.0
    for id, sr in pairs(spawnedRacks) do
        if sr.loc and sr.loc.dynamic and sr.prop and DoesEntityExist(sr.prop) then
            local d = #(pc - GetEntityCoords(sr.prop))
            if d < nd then near, nd = id, d end
        end
    end
    if near then
        TriggerServerEvent('mbt_malisling:weaponRack:remove', near)
    else
        lib.notify({ type = 'error', title = 'Weapon Rack', description = 'No placed rack within 5m.' })
    end
end, false)

-- How many placed racks YOU own (toward MaxPerPlayer) + where they are.
RegisterCommand('mbt_rackcount', function()
    local r = lib.callback.await('mbt_malisling:weaponRack:myRacks', false)
    if type(r) ~= 'table' then return end
    Utils.mbtDebugger(('You own %d/%d placed racks:'):format(r.count, r.max))
    for _, e in ipairs(r.list or {}) do
        Utils.mbtDebugger(('   %s @ %.1f, %.1f, %.1f  (%s)'):format(e.id, e.x, e.y, e.z, e.label or ''))
    end
    lib.notify({ type = 'inform', title = 'Weapon Rack',
        description = ('You own %d/%d placed racks (full list in F8).'):format(r.count, r.max) })
end, false)

-- Remove ALL your own EMPTY placed racks anywhere on the map (test/cleanup).
RegisterCommand('mbt_clearmyracks', function()
    TriggerServerEvent('mbt_malisling:weaponRack:clearMine')
end, false)

RegisterNetEvent('mbt_malisling:weaponRack:clearedMine', function(n)
    lib.notify({ type = 'success', title = 'Weapon Rack',
        description = ('Removed %d of your placed racks.'):format(tonumber(n) or 0) })
end)

-- ── Dev tuner: /mbt_racktune — dial the per-TYPE rack offset live, copy the config line ──
-- Stand near a rack holding a weapon and run it. Tunes the offset for the TYPE of the
-- FIRST stored weapon (MBT.WeaponRack.Offsets[wtype]). TAB = POS/ROT, arrows + Q/E move,
-- SHIFT = bigger step, ENTER copies the config line, BACKSPACE exits. Admin/Debug only
-- (gated server-side). Effect is local until restart; persist via the printed line.
local rackTuning = nil

local function nearestRackWithWeapon()
    local pc = GetEntityCoords(cache.ped)
    local bestId, bestD, bestType = nil, 4.0, nil
    for id, sr in pairs(spawnedRacks) do
        local list = rackData[id]
        if sr and sr.prop and DoesEntityExist(sr.prop) and list and #list > 0 then
            local d = #(pc - GetEntityCoords(sr.prop))
            if d < bestD then bestId, bestD, bestType = id, d, list[1].wtype end
        end
    end
    return bestId, bestType
end

RegisterCommand('mbt_racktune', function()
    if rackTuning then return end
    if not lib.callback.await('mbt_malisling:weaponRack:canTune', false) then
        lib.notify({ type = 'error', title = 'Weapon Rack', description = '/mbt_racktune is admin/debug only.' })
        return
    end
    local id, wtype = nearestRackWithWeapon()
    if not id then
        lib.notify({ type = 'inform', title = 'Weapon Rack',
            description = 'Stand near a rack holding a weapon, then run /mbt_racktune.' })
        return
    end
    cfg.Offsets = cfg.Offsets or {}
    local b = cfg.Offsets[wtype] or { Pos = { x = 0.0, y = 0.0, z = 1.0 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } }
    -- Own copy so live edits never depend on the original table's exact shape.
    cfg.Offsets[wtype] = {
        Pos = { x = (b.Pos and b.Pos.x) or 0.0, y = (b.Pos and b.Pos.y) or 0.0, z = (b.Pos and b.Pos.z) or 0.0 },
        Rot = { x = (b.Rot and b.Rot.x) or 0.0, y = (b.Rot and b.Rot.y) or 0.0, z = (b.Rot and b.Rot.z) or 0.0 },
    }
    rackTuning = { id = id, wtype = wtype }
    renderRack(id)

    local mode = 'pos'   -- 'pos' | 'rot'
    CreateThread(function()
        while rackTuning do
            Wait(0)
            local o = cfg.Offsets[rackTuning.wtype]
            for _, c in ipairs({ 172, 173, 174, 175, 21, 44, 38, 37, 191, 177 }) do DisableControlAction(0, c, true) end
            if IsDisabledControlJustPressed(0, 37) then mode = (mode == 'pos') and 'rot' or 'pos' end  -- TAB toggle
            local fast = IsDisabledControlPressed(0, 21)
            local step = (mode == 'pos') and (fast and 0.05 or 0.005) or (fast and 5.0 or 1.0)
            local moved = true
            if mode == 'pos' then
                if     IsDisabledControlPressed(0, 172) then o.Pos.z = o.Pos.z + step   -- ↑ up
                elseif IsDisabledControlPressed(0, 173) then o.Pos.z = o.Pos.z - step   -- ↓ down
                elseif IsDisabledControlPressed(0, 174) then o.Pos.x = o.Pos.x - step   -- ← left
                elseif IsDisabledControlPressed(0, 175) then o.Pos.x = o.Pos.x + step   -- → right
                elseif IsDisabledControlPressed(0, 44)  then o.Pos.y = o.Pos.y - step   -- Q in (toward rack)
                elseif IsDisabledControlPressed(0, 38)  then o.Pos.y = o.Pos.y + step   -- E out
                else moved = false end
            else
                if     IsDisabledControlPressed(0, 172) then o.Rot.x = (o.Rot.x + step) % 360   -- ↑ pitch+
                elseif IsDisabledControlPressed(0, 173) then o.Rot.x = (o.Rot.x - step) % 360   -- ↓ pitch-
                elseif IsDisabledControlPressed(0, 174) then o.Rot.z = (o.Rot.z - step) % 360   -- ← yaw-
                elseif IsDisabledControlPressed(0, 175) then o.Rot.z = (o.Rot.z + step) % 360   -- → yaw+
                elseif IsDisabledControlPressed(0, 44)  then o.Rot.y = (o.Rot.y - step) % 360   -- Q roll-
                elseif IsDisabledControlPressed(0, 38)  then o.Rot.y = (o.Rot.y + step) % 360   -- E roll+
                else moved = false end
            end
            if moved then renderRack(rackTuning.id) end

            SetTextFont(4); SetTextScale(0.42, 0.42); SetTextColour(255, 255, 255, 255); SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString(('RACK TUNE  ~y~%s~s~  [%s]   pos %.3f / %.3f / %.3f   rot %.0f / %.0f / %.0f    arrows+Q/E=move · TAB=pos/rot · SHIFT=fast · ENTER=copy · BKSP=exit')
                :format(rackTuning.wtype, mode:upper(), o.Pos.x, o.Pos.y, o.Pos.z, o.Rot.x, o.Rot.y, o.Rot.z))
            DrawText(0.5, 0.86)

            if IsDisabledControlJustPressed(0, 191) then   -- ENTER → copy + print the config line
                local line = ("['%s'] = { Pos = { x = %.3f, y = %.3f, z = %.3f }, Rot = { x = %.1f, y = %.1f, z = %.1f } },")
                    :format(rackTuning.wtype, o.Pos.x, o.Pos.y, o.Pos.z, o.Rot.x, o.Rot.y, o.Rot.z)
                Utils.mbtDebugger('Weapon Rack offset -> paste into MBT.WeaponRack.Offsets:\n' .. line)
                if lib.setClipboard then lib.setClipboard(line) end
                lib.notify({ type = 'success', title = 'Weapon Rack',
                    description = ('Offset for "%s" copied to clipboard + printed to F8.'):format(rackTuning.wtype) })
            elseif IsDisabledControlJustPressed(0, 177) then   -- BACKSPACE → exit (keeps the tuned look locally)
                rackTuning = nil
            end
        end
    end)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawnedRacks) do despawnRack(id) end
end)
