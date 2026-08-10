-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Inspect
-- Hold the inspect key to examine the held weapon: anim + local overlay (serial /
-- condition / name / ammo). Anim is broadcast to nearby players (distance-based);
-- overlay is local-only. Purely visual / RP.
-- Hold via the +/- command pair: RegisterKeyMapping('+cmd') auto-binds '-cmd' on
-- release — the cleanest FiveM hold pattern, nothing to toggle/leak.
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the block exists; Enabled checked at use time (live-apply via menu).
if not MBT.Inspect then return end

local cfg  = MBT.Inspect
local anim = cfg.Animation

local inspecting    = false
local currentWeapon         -- ox_inventory:currentWeapon payload (has .metadata)

AddEventHandler('ox_inventory:currentWeapon', function(data)
    currentWeapon = data
    -- Swap/holster mid-inspect is handled by the auto-cancel watcher.
end)

--- durability (0-100) → localized condition label, or nil if unknown.
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

--- durability (0-100) → overlay tone: 'good' (green) / 'warn' (orange) / 'bad' (red).
local function conditionTone(durability)
    if durability == nil then return nil end
    if durability >= 60 then return 'good' end
    if durability >= 35 then return 'warn' end
    return 'bad'
end

--- Clip count → vague fill label (locale key) for AmmoMode = 'vague'.
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
    local data = { locale = buildNuiLocale(), show = cfg.Show, style = MBT.UIStyle or 'standard' }

    if cfg.Show.Name then
        -- md.label = future Custom Weapon Name; falls back to the weapon's own name.
        data.name = md.label or (currentWeapon and currentWeapon.name) or 'WEAPON'
    end
    if cfg.Show.Serial then
        data.serial = md.serial or '—'
    end
    if cfg.Show.Condition then
        data.condition = conditionLabel(md.durability) or '—'
        data.conditionTone = conditionTone(md.durability)
    end
    if cfg.Show.Ammo then
        local _, clip = GetAmmoInClip(cache.ped, weaponHash)
        clip = clip or 0
        if cfg.AmmoMode == 'vague' then
            -- "Look at the mag" estimate (Full/Half/Low/Empty) for no-HUD servers.
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
    if not cfg.Enabled then return end
    if inspecting then return end
    if cache.vehicle then return end
    -- Jammed: the jam loop re-plays its own anim every 800ms, so inspecting on top
    -- of it puts two TaskPlayAnim on the same ped and they fight. Clear the jam first.
    -- Reported by a Qbox server owner right after 2.0.1.
    if LocalPlayer.state.JammedState then
        MBT.NotifyLabel('inspect_blocked_jam')
        return
    end
    local has, weaponHash = GetCurrentPedWeapon(cache.ped, true)
    if not has or weaponHash == `WEAPON_UNARMED` then return end
    if not currentWeapon then return end  -- need inventory data to show anything

    inspecting = true

    lib.requestAnimDict(anim.Dict)
    TaskPlayAnim(cache.ped, anim.Dict, anim.Anim, 8.0, -8.0, -1, anim.Flag or 48,
        0.0, false, false, false)

    local data = buildData()
    -- Chain of Custody: fetch from the server ledger by serial (not in item
    -- metadata — see chain_of_custody/server.lua for why).
    local md = (currentWeapon and currentWeapon.metadata) or {}
    if MBT.ChainOfCustody and MBT.ChainOfCustody.Enabled and MBT.ChainOfCustody.ShowInInspect and md.serial then
        local chain = lib.callback.await('mbt_malisling:getCustody', 1000, md.serial)
        if type(chain) == 'table' and #chain > 0 then data.custody = chain end
    end
    -- Companion (paid) may add proficiency rows to the SAME card (one themed, anchored
    -- overlay renders base + companion rows together). Absent → just the base rows.
    if MBT.ShootingBridge and MBT.ShootingBridge.OnInspectRows then
        local extra = MBT.ShootingBridge.OnInspectRows(data)
        if extra then data.companionRows = extra end
    end
    SendNUIMessage({ action = 'showInspect', data = data })
    -- Cinematic: anchor the card to the held weapon (in hand + visible here).
    if MBT.UIStyle == 'cinematic' then
        MBT.Anchor.Start('inspect', function() return MBT.Anchor.WeaponPos(0.12) end)
    end
    TriggerServerEvent('mbt_malisling:syncInspect', 'start')

    -- Auto-cancel: leave inspect the moment it stops making sense. This is also the
    -- only way out when the inspect key collides with the inventory key: the
    -- inventory takes NUI focus on key-down, so the key-up never reaches the game
    -- and '-mbtInspect' never fires.
    CreateThread(function()
        local deadline = GetGameTimer() + ((cfg.MaxHoldSeconds or 15) * 1000)
        while inspecting do
            local h, wh = GetCurrentPedWeapon(cache.ped, true)
            if not h or wh == `WEAPON_UNARMED` or cache.vehicle
                or IsPedShooting(cache.ped) or LocalPlayer.state.JammedState then
                stopInspect()
                break
            end
            -- The swallowed key-up case: nothing above will ever become true, because
            -- nothing about the player changed. Only the clock gets us out.
            if GetGameTimer() > deadline then
                Utils.mbtDebugger("inspect ~ hold timed out; the release never arrived (key shared with another resource?)")
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
    MBT.Anchor.Stop()
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
