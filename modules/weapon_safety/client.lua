-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Safety Toggle
--
-- Toggle the safety on the held firearm. With safety ON the weapon cannot fire
-- (DisablePlayerFiring every frame) and a SAFE/FIRE indicator shows the state; a
-- metallic click plays on toggle. State is tracked per weapon (by serial) so each
-- gun remembers its own safety. Purely RP — combat logic lives in mbt_shooting,
-- which reads the state via the 'mbt_weaponSafety' statebag or IsWeaponSafetyOn().
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the feature block exists; Enabled is checked at use time so the admin
-- menu can toggle it live (cfg is the live MBT.Safety table).
if not MBT.Safety then return end

local cfg = MBT.Safety

local currentWeapon          -- ox_inventory:currentWeapon payload
local safetyBySerial = {}    -- [serial] = true (PerWeapon mode)
local globalSafety   = cfg.DefaultOn or false  -- single-flag mode
local hudShown       = false

AddEventHandler('ox_inventory:currentWeapon', function(data)
    currentWeapon = data
end)

--- True for a real firearm in hand (not unarmed, not melee/thrown).
local function heldFirearm()
    local has, hash = GetCurrentPedWeapon(cache.ped, true)
    if not has or hash == `WEAPON_UNARMED` then return false, nil end
    local group = GetWeapontypeGroup(hash)
    if group == `GROUP_MELEE` or group == `GROUP_THROWN` or group == `GROUP_UNARMED` then
        return false, nil
    end
    return true, hash
end

--- Stable key for the held weapon's safety state.
local function weaponKey()
    if cfg.PerWeapon then
        return currentWeapon and currentWeapon.metadata and currentWeapon.metadata.serial
            or (currentWeapon and currentWeapon.name)
    end
    return '__global__'
end

local function isSafetyOn()
    if not cfg.PerWeapon then return globalSafety end
    local key = weaponKey()
    if key == nil then return false end
    if safetyBySerial[key] == nil then return cfg.DefaultOn or false end
    return safetyBySerial[key]
end

local function setSafety(on)
    if cfg.PerWeapon then
        local key = weaponKey()
        if key ~= nil then safetyBySerial[key] = on end
    else
        globalSafety = on
    end
    -- Expose to mbt_shooting / other resources.
    LocalPlayer.state:set('mbt_weaponSafety', on, true)
end

local function playClick()
    local s = cfg.Sound
    if not s or not s.Enabled then return end
    if s.Mode == 'nui' then
        SendNUIMessage({ action = 'playHolsterSound', data = { file = s.Nui.File, volume = s.Nui.Volume or 0.5 } })
    else
        PlaySoundFrontend(-1, s.Native.Name, s.Native.Set, false)
    end
end

local function setHud(state)  -- state: 'safe' | 'fire' | nil(hide)
    if not cfg.HudIndicator then return end
    if state == nil then
        if hudShown then SendNUIMessage({ action = 'hideSafety', data = {} }); hudShown = false end
        return
    end
    SendNUIMessage({ action = 'showSafety', data = { state = state, locale = buildNuiLocale() } })
    hudShown = true
end

--- Short "work the safety" gesture: a truncated, slowed pistol-reload partial.
--- TaskPlayAnim only — never touches ammo. Cosmetic, fire-and-forget.
local function playToggleAnim()
    local a = cfg.Animation
    if not a or not a.Enabled then return end
    if not DoesAnimDictExist(a.Dict) then return end
    lib.requestAnimDict(a.Dict)
    TaskPlayAnim(cache.ped, a.Dict, a.Anim, 8.0, -8.0, a.Dur or 750, a.Flag or 48, 0.0, false, false, false)
    if a.Speed then SetEntityAnimSpeed(cache.ped, a.Dict, a.Anim, a.Speed) end
end

local function toggle()
    if not cfg.Enabled then return end
    local ok = heldFirearm()
    if not ok then
        MBT.NotifyLabel('safety_no_weapon')
        return
    end
    local newState = not isSafetyOn()
    setSafety(newState)
    playClick()
    playToggleAnim()
    setHud(newState and 'safe' or 'fire')
end

RegisterCommand(cfg.Command, toggle, false)
RegisterKeyMapping(cfg.Command, '[MBT] Toggle weapon safety', 'keyboard', cfg.Key)

-- Enforcement + HUD sync. Tight loop only while a firearm is in hand.
CreateThread(function()
    while true do
        if not cfg.Enabled then
            if hudShown then setHud(nil) end
            Wait(500)
            goto continue
        end
        local ok = heldFirearm()
        if ok then
            local on = isSafetyOn()
            setHud(on and 'safe' or 'fire')
            if on then
                -- Block firing but still allow aiming (realistic: safety on, you
                -- can raise/aim the weapon, it just won't fire).
                DisablePlayerFiring(cache.playerId, true)
                DisableControlAction(0, 24, true)  -- INPUT_ATTACK
                DisableControlAction(0, 257, true) -- INPUT_ATTACK2
                Wait(0)
            else
                Wait(200)
            end
        else
            setHud(nil)
            -- Keep the statebag in sync with "no firearm" = not safetied-blocking.
            Wait(300)
        end
        ::continue::
    end
end)

exports('IsWeaponSafetyOn', function() return isSafetyOn() end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and hudShown then
        SendNUIMessage({ action = 'hideSafety', data = {} })
    end
end)
