-- ─────────────────────────────────────────────────────────────────────────────
-- Forensic Shell Casings — client
-- SHOOTER half: throttled shots report landing spot + weapon to the server.
-- WORLD half: poll nearby casings, render glint/prop + ox_target ([E]/[G] fallback)
-- to Examine (EvidenceUI: weapon, masked serial, age) or Collect (scene cleaning).
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

-- Dev helper: /mbt_casingzone — capture an ExcludeZone line for MBT.ShellCasings.ExcludeZones
-- (a range/armory where no forensic casings spawn). In Debug it opens a live editor: a ground
-- footprint marker at your spot with ↑/↓ to size the radius (walk to the edge to gauge it),
-- ENTER copies the line, BACKSPACE exits. Without Debug it just prints a line at radius 20.
local casingZoneEditing = false

local function copyCasingZone(c, radius)
    local line = ('{ coords = vec3(%.2f, %.2f, %.2f), radius = %.1f },'):format(c.x, c.y, c.z, radius)
    Utils.mbtDebugger('Casing exclude zone -> paste into MBT.ShellCasings.ExcludeZones:\n' .. line)
    if lib.setClipboard then lib.setClipboard(line) end
    lib.notify({ type = 'success', title = 'Shell Casings',
        description = ('Zone (r=%.0f) copied to clipboard + printed to F8.'):format(radius) })
end

RegisterCommand('mbt_casingzone', function()
    local center = GetEntityCoords(cache.ped)
    if not MBT.Debug then copyCasingZone(center, 20.0); return end   -- non-debug: one-shot, r=20
    if casingZoneEditing then return end
    casingZoneEditing = true
    local radius = 20.0
    CreateThread(function()
        while casingZoneEditing do
            Wait(0)
            for _, c in ipairs({ 172, 173, 21, 191, 177 }) do DisableControlAction(0, c, true) end
            local step = IsDisabledControlPressed(0, 21) and 2.0 or 0.5
            if IsDisabledControlPressed(0, 172) then radius = math.min(200.0, radius + step)       -- ↑ grow
            elseif IsDisabledControlPressed(0, 173) then radius = math.max(1.0, radius - step) end  -- ↓ shrink
            -- Ground footprint (the zone is a 3D sphere server-side; the cylinder shows the area).
            DrawMarker(1, center.x, center.y, center.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                radius * 2.0, radius * 2.0, 4.0, 218, 165, 32, 90, false, false, 2, false, nil, nil, false)
            SetTextFont(4); SetTextScale(0.42, 0.42); SetTextColour(255, 255, 255, 255); SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString(('CASING ZONE   radius %.1f m    ~y~UP/DOWN~s~ resize · SHIFT fast · ENTER copy · BKSP exit'):format(radius))
            DrawText(0.5, 0.86)
            if IsDisabledControlJustPressed(0, 191) then       -- ENTER → copy the tuned line
                copyCasingZone(center, radius)
            elseif IsDisabledControlJustPressed(0, 177) then   -- BACKSPACE → exit
                casingZoneEditing = false
            end
        end
    end)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(nearby) do removeLocal(id) end
end)
