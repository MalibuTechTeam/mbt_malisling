-- ── Concealed Carry — client ──
-- Keybind sends a REQUEST; the server validates and publishes the statebag. Clothing check on
-- component 11: bare torso refused, light tops 'poor', else 'good'.
--
-- PER WEAPON (serial), not per slot: with two pistols on one hip, hiding one must not take the
-- other. Teardown is just a re-report — the reconciliation drops or restores the prop, and the
-- spawn guard reads MBT.IsSerialConcealed (defined here). A drawn weapon is visible by nature.

if not MBT.ConcealedCarry then return end

local cfg = MBT.ConcealedCarry

-- { [serial] = { t = wtype, q = quality } } mirror of our own statebag.
-- Keyed by the weapon, not by the body slot: concealment is an action on a gun, and the
-- rest of the system already refuses to act on "whichever one of that type".
local myState   = nil
local lastTop   = nil    -- component 11 drawable at last check
local boostTill = 0      -- tell-chance boost window after sprint/jump

-- Predicate consumed by the core prop-spawn guard.
function MBT.IsSerialConcealed(serverId, serial)
    if not cfg.Enabled or not serial then return false end
    local st = Player(serverId) and Player(serverId).state.mbt_concealed
    return type(st) == 'table' and st[tostring(serial)] ~= nil
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

--- Everything the key could act on, concealed ones first so a second press always undoes.
--- Reads the REGISTRY, shadows included: MaxPerType caps how many weapons are drawn, not
--- how many exist, and a weapon you can't see is exactly one you might want tucked away.
--- Every concealable weapon the registry still knows we carry.
--- Shadows included: a concealed weapon IS a shadow (suppressed, so no prop), and
--- MaxPerType caps how many are drawn, not how many exist.
---@return table<string, table>  [serial] = { wtype, name }
local function ownedConcealable()
    local owned = {}
    Slung.forEach(cache.serverId, function(_, propType, serial, e)
        if (cfg.ConcealableTypes or {})[propType] then
            owned[serial] = { wtype = propType, name = e.name }
        end
    end, { states = 'all', stale = true })
    return owned
end

--- Drop concealment for weapons that are no longer ours.
--- Concealment used to end only with an explicit toggle or a clothing change, so a gun that
--- was dropped, stowed, handed over or seized stayed "hidden" forever: offered by the
--- picker, reported by a frisk, and still triggering the waistband tell. The registry knows
--- the truth — a weapon that left the inventory left the snapshot — so reconcile against it.
---@param owned table?
local function pruneStaleState(owned)
    if type(myState) ~= 'table' then return end
    owned = owned or ownedConcealable()

    for serial in pairs(myState) do
        if not owned[serial] then
            myState[serial] = nil
            TriggerServerEvent('mbt_malisling:concealed:forceReveal', serial)
        end
    end
    if not next(myState) then myState = nil end
end

---@return table[]  { serial, wtype, name, concealed }
local function candidates()
    local out, seen = {}, {}
    local owned = ownedConcealable()
    pruneStaleState(owned)

    if type(myState) == 'table' then
        for serial, st in pairs(myState) do
            out[#out + 1] = { serial = serial, wtype = st.t,
                              name = st.n or (owned[serial] and owned[serial].name), concealed = true }
            seen[serial] = true
        end
    end

    for serial, o in pairs(owned) do
        if not seen[serial] then
            out[#out + 1] = { serial = serial, wtype = o.wtype, name = o.name, concealed = false }
        end
    end

    -- Stable order: concealed first (they came first above), then by name, then serial.
    table.sort(out, function(a, b)
        if a.concealed ~= b.concealed then return a.concealed end
        if (a.name or '') ~= (b.name or '') then return (a.name or '') < (b.name or '') end
        return a.serial < b.serial
    end)
    return out
end

-- ── Picker (same key-driven NUI list as the weapon rack) ─────────────────────────
-- Deliberately a second copy of the rack's input loop rather than a shared helper: the
-- rack's picker works and is not worth the risk of a refactor here. If a third caller
-- appears, extract it then.
local picker = nil   -- { list, idx, n, onPick }

local function closePicker(pickIdx)
    if not picker then return end
    local p = picker
    picker = nil
    SendNUIMessage({ action = 'hideRackPicker', data = {} })
    -- On its OWN thread, never inside the input loop: the pick awaits a server round trip,
    -- and awaiting inside a loop that is disabling half the player's controls means any
    -- hitch on that trip is a hitch the player feels as being stuck.
    if pickIdx and p.list[pickIdx] then
        CreateThread(function() p.onPick(p.list[pickIdx]) end)
    end
end

local function openPicker(list, onPick)
    if picker then return end

    local entries = {}
    for i, c in ipairs(list) do
        entries[i] = {
            name      = c.name or '?',
            serial    = c.serial,
            condition = c.concealed and Translate('conceal_picker_reveal') or nil,
            tone      = c.concealed and 'warn' or nil,
        }
    end

    picker = { list = list, idx = 1, n = #list, onPick = onPick }
    SendNUIMessage({ action = 'showRackPicker', data = {
        locale  = buildNuiLocale(),
        weapons = entries,
        index   = 1,
        style   = MBT.UIStyle or 'standard',
        title   = Translate('conceal_picker_title'),
        confirm = Translate('conceal_picker_confirm'),
    } })

    CreateThread(function()
        -- Hard deadline. This loop holds down a dozen controls; if it ever failed to close
        -- — a key that never registers, a state we didn't foresee — the player would be
        -- locked out with no way back, and that reads as the game having frozen.
        local deadline = GetGameTimer() + 15000

        while picker do
            Wait(0)
            if GetGameTimer() > deadline then closePicker(nil) break end
            for _, c in ipairs({ 172, 173, 191, 177, 38, 24, 25, 140, 141, 142 }) do
                DisableControlAction(0, c, true)
            end
            if IsDisabledControlJustPressed(0, 172) then
                picker.idx = (picker.idx - 2) % picker.n + 1
                SendNUIMessage({ action = 'updateRackPicker', data = { index = picker.idx } })
            elseif IsDisabledControlJustPressed(0, 173) then
                picker.idx = picker.idx % picker.n + 1
                SendNUIMessage({ action = 'updateRackPicker', data = { index = picker.idx } })
            elseif IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 38) then
                closePicker(picker.idx)
            elseif IsDisabledControlJustPressed(0, 177) then
                closePicker(nil)
            end
            -- Anything that invalidates the action closes it rather than acting later.
            if picker and toggleBlocked() then closePicker(nil) end
        end
    end)
end

-- ── Toggle ───────────────────────────────────────────────────────────────────────
local toggling = false

local function applyToggle(target)
    if not target then return end

    toggling = true
    local quality = clothingQuality()
    local res = lib.callback.await('mbt_malisling:concealed:toggle', false,
        { serial = target.serial, wtype = target.wtype, quality = quality })
    toggling = false
    if not res or not res.ok then
        if res and res.reason then MBT.NotifyLabel(res.reason) end
        return
    end
    local wtype = target.wtype

    -- Quick tuck/pull gesture (config-driven; non-blocking).
    local a = cfg.ActionAnim
    if a and a.Dict and DoesAnimDictExist(a.Dict) then
        lib.requestAnimDict(a.Dict)
        TaskPlayAnim(cache.ped, a.Dict, a.Anim, 4.0, -4.0, a.Ms or 700, 48, 0.0, false, false, false)
    end

    if res.concealed then
        myState = myState or {}
        myState[target.serial] = { t = wtype, q = res.quality, n = target.name }
        lastTop = select(2, clothingQuality())
        MBT.NotifyLabel('concealed_on')
    else
        if myState then
            myState[target.serial] = nil
            if not next(myState) then myState = nil end
        end
        MBT.NotifyLabel('concealed_off')
    end

    -- One path for both directions. The snapshot still lists a concealed weapon — hiding it
    -- is a render-time call every observer makes — so a re-report is enough: the
    -- reconciliation drops the prop on conceal and puts it back on reveal, and there is no
    -- per-type deletion event that could take the OTHER pistol with it.
    TriggerServerEvent('mbt_malisling:checkInventory')
end

local function toggleConcealed()
    if toggling or picker or not cfg.Enabled or toggleBlocked() then return end

    local list = candidates()
    if #list == 0 then MBT.NotifyLabel('concealed_no_weapon') return end
    -- One candidate: act. A menu for a single choice turns an instant gesture into a
    -- click, and this key is pressed in a hurry.
    if #list == 1 then applyToggle(list[1]) return end
    openPicker(list, applyToggle)
end

RegisterCommand('mbtConceal', toggleConcealed, false)
RegisterKeyMapping('mbtConceal', '[MBT] Conceal / reveal weapon', 'keyboard', cfg.Key or 'B')

-- ── Force reveal (clothing no longer covers, or ped changed) ──────────────────────
local function forceRevealAll(notify)
    if not myState then return end
    for serial in pairs(myState) do
        TriggerServerEvent('mbt_malisling:concealed:forceReveal', serial)
    end
    myState = nil
    TriggerServerEvent('mbt_malisling:checkInventory')
    if notify then MBT.NotifyLabel('concealed_revealed') end
end

-- Clothing watcher: re-check while concealed; grace delay so staged outfit
-- scripts (applying components one by one) don't trigger false reveals.
CreateThread(function()
    while true do
        Wait(800)
        if myState and cfg.Enabled then
            -- Also here, not only when the key is pressed: a frisk or the tell animation
            -- must not act on a weapon that left while the player did nothing.
            pruneStaleState()
        end
        if myState and cfg.Enabled then
            local _, d = clothingQuality()
            if lastTop ~= nil and d ~= lastTop then
                Wait(600)   -- short grace: let a staged outfit change settle
                local q, d2 = clothingQuality()
                lastTop = d2
                if q == 'none' then
                    forceRevealAll(true)
                else
                    -- Quality may have shifted good↔poor: the tell loop reads
                    -- myState fresh; update it locally (server re-checks on patdown).
                    for _, st in pairs(myState) do st.q = q end
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
                for _, st in pairs(myState) do quality = st.q or 'good' break end
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

-- ── Debug: why is my outfit evaluated this way? (Debug builds only) ───────────────
if MBT.Debug then
    RegisterCommand('mbt_concealdebug', function()
        local q, d = clothingQuality()
        local sex = pedSex()
        local st = 'none'
        if myState then
            local parts = {}
            for serial, s in pairs(myState) do
                parts[#parts + 1] = ('%s[%s]=%s'):format(s.n or '?', serial, s.q or '?')
            end
            table.sort(parts)
            st = table.concat(parts, ', ')
        end
        Utils.mbtDebugger(('conceal debug ~ model=%s sex=%s | top(comp 11) drawable=%d texture=%d | evaluated quality=%s | active state=%s')
            :format(GetEntityModel(cache.ped), sex, d,
                GetPedTextureVariation(cache.ped, 11), q, st))
        lib.notify({ type = 'inform', title = 'Conceal debug',
            description = ('top %d → %s (state: %s) — full line in F8'):format(d, q, st) })
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and myState then
        -- Leave no hidden props behind if the resource is restarted mid-conceal.
        TriggerServerEvent('mbt_malisling:checkInventory')
    end
end)
