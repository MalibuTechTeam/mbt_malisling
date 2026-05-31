-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Inspect
--
-- Hold the inspect key to examine the held weapon: plays an inspection animation
-- and shows a local overlay with serial / condition / name / ammo. The animation
-- is broadcast to nearby players (scope-style, distance-based) so others see you
-- inspecting; the overlay is local-only. Purely visual / RP.
--
-- Hold-to-inspect via the +/- command pair: RegisterKeyMapping('+cmd') auto-binds
-- '-cmd' on release — the cleanest FiveM hold pattern, nothing to toggle/leak.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.Inspect or not MBT.Inspect.Enabled then return end

local cfg  = MBT.Inspect
local anim = cfg.Animation

local inspecting    = false
local currentWeapon         -- ox_inventory:currentWeapon payload (has .metadata)

AddEventHandler('ox_inventory:currentWeapon', function(data)
    currentWeapon = data
    -- A weapon swap / holster mid-inspect is handled by the auto-cancel watcher.
end)

--- durability (0-100) → localized condition label, or nil if unknown.
---@param durability number?
---@return string?
local function conditionLabel(durability)
    if durability == nil then return nil end
    local tiers = cfg.ConditionTiers or {}
    for i = 1, #tiers do
        if durability >= tiers[i].Min then
            return Translate(tiers[i].Key)
        end
    end
    return nil
end

--- Clip count → vague fill label (locale key) for AmmoMode = 'vague'.
---@param clip number
---@param maxClip number
---@return string
local function vagueAmmo(clip, maxClip)
    if clip <= 0 then return Translate('ammo_empty') end
    if not maxClip or maxClip <= 0 then return Translate('ammo_unknown') end
    local r = clip / maxClip
    if r >= 0.85 then return Translate('ammo_full')
    elseif r >= 0.45 then return Translate('ammo_half')
    else return Translate('ammo_low') end
end

--- Assemble the overlay payload from the held weapon + its inventory metadata.
local function buildData()
    local _, weaponHash = GetCurrentPedWeapon(cache.ped, true)
    local md = (currentWeapon and currentWeapon.metadata) or {}
    local data = { locale = buildNuiLocale(), show = cfg.Show }

    if cfg.Show.Name then
        -- md.label = future Custom Weapon Name; fall back to the weapon's own name.
        data.name = md.label or (currentWeapon and currentWeapon.name) or 'WEAPON'
    end
    if cfg.Show.Serial then
        data.serial = md.serial or '—'
    end
    if cfg.Show.Condition then
        data.condition = conditionLabel(md.durability) or '—'
    end
    if cfg.Show.Ammo then
        local _, clip = GetAmmoInClip(cache.ped, weaponHash)
        clip = clip or 0
        if cfg.AmmoMode == 'vague' then
            -- No exact count — a "look at the mag" estimate (Full / Half / Low /
            -- Empty), for no-HUD / hardcore servers. Ratio vs the weapon's clip size.
            local maxClip = GetMaxAmmoInClip(cache.ped, weaponHash, true)
            data.ammo = vagueAmmo(clip, maxClip)
        else
            data.ammo = clip
        end
    end
    return data
end

local stopInspect  -- forward declaration (the watcher in startInspect calls it)

local function startInspect()
    if inspecting then return end
    if cache.vehicle then return end
    local has, weaponHash = GetCurrentPedWeapon(cache.ped, true)
    if not has or weaponHash == `WEAPON_UNARMED` then return end
    if not currentWeapon then return end  -- need inventory data to show anything

    inspecting = true

    lib.requestAnimDict(anim.Dict)
    TaskPlayAnim(cache.ped, anim.Dict, anim.Anim, 8.0, -8.0, -1, anim.Flag or 48,
        0.0, false, false, false)

    SendNUIMessage({ action = 'showInspect', data = buildData() })
    TriggerServerEvent('mbt_malisling:syncInspect', 'start')

    -- Auto-cancel: leave inspect the moment it stops making sense.
    CreateThread(function()
        while inspecting do
            local h, wh = GetCurrentPedWeapon(cache.ped, true)
            if not h or wh == `WEAPON_UNARMED` or cache.vehicle
                or IsPedShooting(cache.ped) then
                stopInspect()
                break
            end
            Wait(150)
        end
    end)
end

function stopInspect()
    if not inspecting then return end
    inspecting = false
    StopAnimTask(cache.ped, anim.Dict, anim.Anim, 4.0)
    RemoveAnimDict(anim.Dict)
    SendNUIMessage({ action = 'hideInspect', data = {} })
    TriggerServerEvent('mbt_malisling:syncInspect', 'stop')
end

RegisterCommand('+mbtInspect', startInspect, false)
RegisterCommand('-mbtInspect', stopInspect, false)
RegisterKeyMapping('+mbtInspect', '[MBT] Inspect weapon', 'keyboard', cfg.Key)

-- Nearby players' inspect animation (overlay stays local to each player).
RegisterNetEvent('mbt_malisling:remoteInspect', function(srcPlayer, action)
    local ped = GetPlayerPed(GetPlayerFromServerId(srcPlayer))
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if action == 'start' then
        lib.requestAnimDict(anim.Dict)
        TaskPlayAnim(ped, anim.Dict, anim.Anim, 8.0, -8.0, -1, anim.Flag or 48,
            0.0, false, false, false)
    else
        StopAnimTask(ped, anim.Dict, anim.Anim, 4.0)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and inspecting then
        ClearPedTasks(cache.ped)
    end
end)
