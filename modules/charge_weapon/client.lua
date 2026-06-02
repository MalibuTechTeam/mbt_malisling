-- ─────────────────────────────────────────────────────────────────────────────
-- Charge Weapon (rack the slide)
--
-- RP intimidation gesture: rack the slide / charge the held firearm with a marked
-- animation + a mechanical "clack". No HUD, no ammo logic — purely the gesture.
-- Broadcast to nearby players (they see the anim on the source ped and hear the
-- sound) so the intimidation actually lands on whoever you're facing.
-- ─────────────────────────────────────────────────────────────────────────────

-- Load if the feature block exists at all; the Enabled flag is checked at use
-- time so the admin menu can toggle it live (cfg is the live MBT.ChargeWeapon
-- table, so field edits from applyConfig are seen automatically).
if not MBT.ChargeWeapon then return end

local cfg     = MBT.ChargeWeapon
local anim    = cfg.Animation
local lastUse = 0

--- Held firearm whose group is allowed to charge?
local function heldChargeable()
    local has, hash = GetCurrentPedWeapon(cache.ped, true)
    if not has or hash == `WEAPON_UNARMED` then return false end
    return cfg.Groups[GetWeapontypeGroup(hash)] == true
end

local function playSound(ped)
    local s = cfg.Sound
    if not s or not s.Enabled then return end
    if s.Mode == 'nui' then
        SendNUIMessage({ action = 'playHolsterSound', data = { file = s.Nui.File, volume = s.Nui.Volume or 0.6 } })
    else
        PlaySoundFromEntity(-1, s.Native.Name, ped, s.Native.Set, false, 0)
    end
end

local function playAnim(ped)
    if not anim or not DoesAnimDictExist(anim.Dict) then return end
    lib.requestAnimDict(anim.Dict)
    TaskPlayAnim(ped, anim.Dict, anim.Anim, 8.0, -8.0, anim.Dur or 650, anim.Flag or 48, 0.0, false, false, false)
    if anim.Speed then SetEntityAnimSpeed(ped, anim.Dict, anim.Anim, anim.Speed) end
end

local function charge()
    if not cfg.Enabled then return end
    if not heldChargeable() then
        MBT.NotifyLabel('charge_no_weapon')
        return
    end
    local now = GetGameTimer()
    if now - lastUse < (cfg.Cooldown or 1500) then return end
    lastUse = now

    playAnim(cache.ped)
    playSound(cache.ped)
    TriggerServerEvent('mbt_malisling:syncCharge')
end

RegisterCommand(cfg.Command, charge, false)
if cfg.Key and cfg.Key ~= '' then
    RegisterKeyMapping(cfg.Command, '[MBT] Charge weapon (rack)', 'keyboard', cfg.Key)
end

-- Nearby players: play the anim + sound on the source ped.
RegisterNetEvent('mbt_malisling:remoteCharge', function(srcPlayer)
    local ped = GetPlayerPed(GetPlayerFromServerId(srcPlayer))
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    playAnim(ped)
    playSound(ped)
end)
