-- ─────────────────────────────────────────────────────────────────────────────
-- Forensic Shell Casings — client
--
-- Two halves:
--   • SHOOTER: while armed, each shot (throttled) reports the landing spot +
--     weapon to the server, which rolls the chance and registers the casing.
--     GTA's own ejected-brass particle already covers the firing visual.
--   • WORLD: a light poll pulls nearby casing positions; each one gets a subtle
--     ground glint (or a physical prop when cfg.Prop is set) and an ox_target
--     sphere ([E]/[G] fallback) to Examine (EvidenceUI card: weapon, masked
--     serial, age) or Collect (scene cleaning).
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ShellCasings then return end

local cfg = MBT.ShellCasings

local CurrentWeapon = {}
AddEventHandler('ox_inventory:currentWeapon', function(w) CurrentWeapon = w or {} end)

-- hash → WEAPON_ name (qb path: no currentWeapon event, resolve from WeaponsInfo).
local hashToName = nil
local function nameFromHash(hash)
    if not hashToName then
        hashToName = {}
        local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons
        if w then for name in pairs(w) do hashToName[joaat(name)] = name end end
    end
    return hashToName[hash]
end

-- ── Shooter half ─────────────────────────────────────────────────────────────────
CreateThread(function()
    local lastSent = 0
    while true do
        local sleep = 500
        if cfg.Enabled then
            local armed, hash = GetCurrentPedWeapon(cache.ped, true)
            if armed and hash ~= `WEAPON_UNARMED` then
                sleep = 0
                if IsPedShooting(cache.ped) then
                    local now = GetGameTimer()
                    if (now - lastSent) >= (cfg.MinIntervalMs or 1200) then
                        lastSent = now
                        local name = (CurrentWeapon and CurrentWeapon.name) or nameFromHash(hash)
                        if name then
                            -- Casing lands beside the ped with a small scatter, ground-snapped.
                            local p = GetOffsetFromEntityInWorldCoords(cache.ped,
                                0.4 + math.random() * 0.5, math.random() * 0.6 - 0.2, 0.0)
                            local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 0.5, false)
                            TriggerServerEvent('mbt_malisling:casing:shot', {
                                x = p.x, y = p.y, z = (found and gz or p.z) + 0.02,
                                weapon = name,
                                serial = CurrentWeapon and CurrentWeapon.metadata
                                    and CurrentWeapon.metadata.serial or nil,
                            })
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ── World half ───────────────────────────────────────────────────────────────────
local nearby     = {}    -- [id] = { id, coords, zone?, prop? }
local hasTarget  = GetResourceState('ox_target') == 'started'
local busy       = false
local shownId    = nil   -- casing currently shown in the EvidenceUI

local function hideEvidence()
    if not shownId then return end
    shownId = nil
    SendNUIMessage({ action = 'hideEvidence', data = {} })
end

local function examineCasing(id)
    if busy then return end
    busy = true
    local data = lib.callback.await('mbt_malisling:casing:examine', false, id)
    busy = false
    if type(data) ~= 'table' then return end
    shownId = id
    SendNUIMessage({ action = 'showEvidence', data = {
        locale = buildNuiLocale(),
        weapon = data.weapon,
        serial = data.serial,        -- already masked server-side; nil = hidden
        agoMin = data.agoMin,
    } })
end

local function removeLocal(id)
    local c = nearby[id]
    if not c then return end
    if c.zone then pcall(function() exports.ox_target:removeZone(c.zone) end) end
    if c.prop and DoesEntityExist(c.prop) then DeleteEntity(c.prop) end
    nearby[id] = nil
    if shownId == id then hideEvidence() end
end

local function collectCasing(id)
    if busy then return end
    busy = true
    -- Bend down and pick it up.
    if DoesAnimDictExist('pickup_object') then
        lib.requestAnimDict('pickup_object')
        TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 4.0, -4.0, 800, 49, 0.0, false, false, false)
        Wait(800)
        ClearPedTasks(cache.ped)
    end
    local ok = lib.callback.await('mbt_malisling:casing:collect', false, id)
    busy = false
    if ok then
        removeLocal(id)
        MBT.NotifyLabel('casing_collected')
    end
end

local function addLocal(e)
    local coords = vec3(e.x, e.y, e.z)
    local entry  = { id = e.id, coords = coords }

    if cfg.Prop then
        local model = cfg.Prop
        if lib.requestModel(model, 2000) then
            local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
            if obj and DoesEntityExist(obj) then
                SetEntityCollision(obj, false, false)
                FreezeEntityPosition(obj, true)
                entry.prop = obj
            end
            SetModelAsNoLongerNeeded(model)
        end
    end

    if hasTarget then
        entry.zone = exports.ox_target:addSphereZone({
            coords = coords,
            radius = (cfg.InteractRange or 1.2),
            options = {
                {
                    name     = 'mbt_casing_examine_' .. e.id,
                    icon     = 'fa-solid fa-magnifying-glass',
                    label    = Translate('casing_examine'),
                    onSelect = function() examineCasing(e.id) end,
                },
                {
                    name        = 'mbt_casing_collect_' .. e.id,
                    icon        = 'fa-solid fa-hand-sparkles',
                    label       = Translate('casing_collect'),
                    canInteract = function() return cfg.AllowCollect ~= false end,
                    onSelect    = function() collectCasing(e.id) end,
                },
            },
        })
    end

    nearby[e.id] = entry
end

-- Poll nearby casings (light: every 4s, ids+coords only) and diff the local set.
CreateThread(function()
    while true do
        Wait(4000)
        if cfg.Enabled then
            local list = lib.callback.await('mbt_malisling:casing:getNearby', false)
            if type(list) == 'table' then
                local seen = {}
                for _, e in ipairs(list) do
                    seen[e.id] = true
                    if not nearby[e.id] then addLocal(e) end
                end
                for id in pairs(nearby) do
                    if not seen[id] then removeLocal(id) end
                end
            end
        elseif next(nearby) then
            for id in pairs(nearby) do removeLocal(id) end
        end
    end
end)

-- Ground glint (only when no physical prop is configured) + EvidenceUI auto-hide.
CreateThread(function()
    while true do
        local sleep = 600
        if cfg.Enabled and next(nearby) then
            local pc = GetEntityCoords(cache.ped)
            for id, c in pairs(nearby) do
                local dist = #(pc - c.coords)
                if not c.prop and dist < (cfg.GlintRange or 12.0) then
                    sleep = 0
                    DrawMarker(28, c.coords.x, c.coords.y, c.coords.z + 0.03,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.035, 0.035, 0.02,
                        218, 165, 32, 170, false, false, 2, false, nil, nil, false)
                end
                if shownId == id and dist > 3.0 then hideEvidence() end
            end
        end
        Wait(sleep)
    end
end)

-- [E]/[G] fallback when ox_target isn't installed.
if not hasTarget then
    CreateThread(function()
        local shown = false
        while true do
            local sleep = 500
            if cfg.Enabled and next(nearby) then
                local pc = GetEntityCoords(cache.ped)
                local near, nd = nil, (cfg.InteractRange or 1.2)
                for id, c in pairs(nearby) do
                    local d = #(pc - c.coords)
                    if d < nd then near, nd = id, d end
                end
                if near then
                    sleep = 0
                    if not shown then
                        local label = '[E] ' .. Translate('casing_examine')
                        if cfg.AllowCollect ~= false then
                            label = label .. '  ·  [G] ' .. Translate('casing_collect')
                        end
                        lib.showTextUI(label)
                        shown = true
                    end
                    if IsControlJustReleased(0, 38) then examineCasing(near) end            -- E
                    if cfg.AllowCollect ~= false and IsControlJustReleased(0, 47) then      -- G
                        collectCasing(near)
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

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(nearby) do removeLocal(id) end
end)
