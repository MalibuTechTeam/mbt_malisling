-- ─────────────────────────────────────────────────────────────────────────────
-- Concealed Carry — client
--
-- Toggle concealment of holstered small weapons, clothing-aware:
--   • Clothing check on component 11 (top/jacket): bare-torso blocklist → refused;
--     light tops → quality 'poor'; anything else → 'good'. Config overrides win.
--   • The keybind sends a REQUEST; the server validates and publishes the
--     replicated statebag. Prop teardown/respawn reuses the existing core flows
--     (syncDeletion / checkInventory) — and the core's spawn guard reads
--     MBT.IsTypeConcealed (defined here) to keep concealed props from spawning.
--   • Waistband-adjust TELL: random rolls, boosted after sprint/jump, networked
--     naturally (the carrier plays it) → visible only to nearby players.
--   • Changing clothes re-checks (with a grace period for staged outfit scripts)
--     and force-reveals when concealment is no longer possible.
-- A weapon IN HAND is visible by nature: concealment only covers the holstered
-- prop, so the "drawn while concealed" race can't exist.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ConcealedCarry then return end

local cfg = MBT.ConcealedCarry

local myState   = nil    -- { [wtype] = quality } mirror of our own statebag
local lastTop   = nil    -- component 11 drawable at last check
local boostTill = 0      -- tell-chance boost window after sprint/jump

-- ── Predicate consumed by the core prop-spawn guard ────────────────────────────
---@param serverId number
---@param wtype string
---@return boolean
function MBT.IsTypeConcealed(serverId, wtype)
    if not cfg.Enabled then return false end
    local st = Player(serverId) and Player(serverId).state.mbt_concealed
    return type(st) == 'table' and st[wtype] ~= nil
end

-- ── Clothing evaluation ──────────────────────────────────────────────────────────
local function pedSex()
    local m = GetEntityModel(cache.ped)
    if m == `mp_m_freemode_01` then return 'male' end
    if m == `mp_f_freemode_01` then return 'female' end
    return IsPedMale(cache.ped) and 'male' or 'female'
end

--- → 'good' | 'poor' | 'none', plus the drawable id (for the debug command).
local function clothingQuality()
    local sex = pedSex()
    local c   = cfg.Clothing or {}
    local d   = GetPedDrawableVariation(cache.ped, 11)

    local overrides = (sex == 'male') and c.OverridesMale or c.OverridesFemale
    if overrides and overrides[d] then return overrides[d], d end
    local bare = (sex == 'male') and c.BareTorsoMale or c.BareTorsoFemale
    if bare and bare[d] then return 'none', d end
    local light = (sex == 'male') and c.LightTopsMale or c.LightTopsFemale
    if light and light[d] then return 'poor', d end
    return 'good', d
end

-- ── State helpers ────────────────────────────────────────────────────────────────
--- Interaction lock: states where toggling makes no sense or enables abuse.
local function toggleBlocked()
    local ped = cache.ped
    if cache.vehicle then return true end
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedSwimming(ped) then return true end
    if IsPedCuffed(ped) then return true end
    return false
end

--- The concealable type the player can act on right now: a currently concealed
--- one first (so the key always un-conceals), else one with a slung prop.
local function actionableType()
    if type(myState) == 'table' then
        for wtype in pairs(myState) do return wtype end
    end
    for wtype in pairs(cfg.ConcealableTypes or {}) do
        if GetLocalSlungProp and GetLocalSlungProp(wtype) then return wtype end
    end
    return nil
end

local function applyState(newState)
    myState = (type(newState) == 'table' and next(newState)) and newState or nil
end

-- ── Toggle ───────────────────────────────────────────────────────────────────────
local toggling = false
local function toggleConcealed()
    if toggling or not cfg.Enabled or toggleBlocked() then return end
    local wtype = actionableType()
    if not wtype then MBT.NotifyLabel('concealed_no_weapon') return end

    toggling = true
    local quality = clothingQuality()
    local res = lib.callback.await('mbt_malisling:concealed:toggle', false,
        { wtype = wtype, quality = quality })
    toggling = false
    if not res or not res.ok then
        if res and res.reason then MBT.NotifyLabel(res.reason) end
        return
    end

    if res.concealed then
        myState = myState or {}
        myState[wtype] = res.quality
        lastTop = select(2, clothingQuality())
        -- Tear the slung prop down everywhere through the existing deletion flow.
        TriggerServerEvent('mbt_malisling:syncDeletion', wtype)
        MBT.NotifyLabel('concealed_on')
    else
        if myState then myState[wtype] = nil; if not next(myState) then myState = nil end end
        -- Respawn through the existing re-sync flow.
        TriggerServerEvent('mbt_malisling:checkInventory')
        MBT.NotifyLabel('concealed_off')
    end
end

RegisterCommand('mbtConceal', toggleConcealed, false)
RegisterKeyMapping('mbtConceal', '[MBT] Conceal / reveal weapon', 'keyboard', cfg.Key or 'B')

-- ── Force reveal (clothing no longer covers, or ped changed) ──────────────────────
local function forceRevealAll(notify)
    if not myState then return end
    for wtype in pairs(myState) do
        TriggerServerEvent('mbt_malisling:concealed:forceReveal', wtype)
    end
    myState = nil
    TriggerServerEvent('mbt_malisling:checkInventory')
    if notify then MBT.NotifyLabel('concealed_revealed') end
end

-- Clothing watcher: re-check while concealed; grace delay so staged outfit
-- scripts (applying components one by one) don't trigger false reveals.
CreateThread(function()
    while true do
        Wait(2000)
        if myState and cfg.Enabled then
            local _, d = clothingQuality()
            if lastTop ~= nil and d ~= lastTop then
                Wait(1500)   -- grace: let the outfit settle
                local q, d2 = clothingQuality()
                lastTop = d2
                if q == 'none' then
                    forceRevealAll(true)
                else
                    -- Quality may have shifted good↔poor: the tell loop reads
                    -- myState fresh; update it locally (server re-checks on patdown).
                    for wtype in pairs(myState) do myState[wtype] = q end
                end
            elseif lastTop == nil then
                lastTop = d
            end
        end
    end
end)

-- Ped model change (skin swap): concealment can't survive a new body.
lib.onCache('ped', function()
    if myState then forceRevealAll(true) end
end)

-- ── The tell: waistband adjust, carrier-played (networked naturally) ──────────────
CreateThread(function()
    while true do
        local t = cfg.Tell or {}
        Wait(math.max(5, t.RollSeconds or 25) * 1000)
        if myState and cfg.Enabled and t.Enabled ~= false and not cache.vehicle
            and not IsEntityDead(cache.ped) and not IsPedSwimming(cache.ped)
            and not IsPedRagdoll(cache.ped) then
            -- Skip while any weapon is drawn — the gun is visible anyway.
            local armed, wh = GetCurrentPedWeapon(cache.ped, true)
            if not armed or wh == `WEAPON_UNARMED` then
                local quality = 'good'
                for _, q in pairs(myState) do quality = q break end
                local chance = (quality == 'poor') and (t.ChancePoor or 0.45) or (t.ChanceGood or 0.15)
                if GetGameTimer() < boostTill then chance = chance * (t.MoveBoost or 2.0) end
                if math.random() < chance and t.Dict and DoesAnimDictExist(t.Dict) then
                    lib.requestAnimDict(t.Dict)
                    TaskPlayAnim(cache.ped, t.Dict, t.Anim, 4.0, -4.0, t.Ms or 1600, 48,
                        0.0, false, false, false)
                end
            end
        end
    end
end)

-- Movement boost tracker (cheap: only while concealed).
CreateThread(function()
    while true do
        Wait(700)
        if myState and cfg.Enabled then
            if IsPedSprinting(cache.ped) or IsPedJumping(cache.ped) then
                boostTill = GetGameTimer() + 10000
            end
        end
    end
end)

-- ── Debug: why is my outfit evaluated this way? ───────────────────────────────────
RegisterCommand('mbt_concealdebug', function()
    local q, d = clothingQuality()
    local sex = pedSex()
    local st  = 'none'
    if myState then
        for wtype, qq in pairs(myState) do st = ('%s=%s'):format(wtype, qq) break end
    end
    print(('[mbt_malisling] conceal debug ~ model=%s sex=%s | top(comp 11) drawable=%d texture=%d | evaluated quality=%s | active state=%s')
        :format(GetEntityModel(cache.ped), sex, d,
            GetPedTextureVariation(cache.ped, 11), q, st))
    lib.notify({ type = 'inform', title = 'Conceal debug',
        description = ('top %d → %s (state: %s) — full line in F8'):format(d, q, st) })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and myState then
        -- Leave no hidden props behind if the resource is restarted mid-conceal.
        TriggerServerEvent('mbt_malisling:checkInventory')
    end
end)
