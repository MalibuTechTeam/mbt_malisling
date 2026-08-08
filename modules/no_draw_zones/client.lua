-- ─────────────────────────────────────────────────────────────────────────────
-- No-Draw Zones — areas (hospital, PD...) where firing is disabled and any drawn
-- firearm is put away via ox_inventory:disarm (same path as throw). Melee can be
-- left usable (cfg.AllowMelee). Client-side detection/enforcement, purely RP —
-- a cheater could bypass it (server-side enforcement is future hardening).
-- ─────────────────────────────────────────────────────────────────────────────

-- Enabled checked in the loop so the admin menu can toggle live (zones stay registered).
if not MBT.NoDrawZones then return end

local cfg = MBT.NoDrawZones

local inside     = 0     -- number of zones currently containing the player (overlap-safe)
local lastNotify = 0

local function onEnter(label)
    inside = inside + 1
    if inside == 1 and cfg.HudIndicator then
        SendNUIMessage({
            action = 'showNoDraw',
            data   = { title = label, subtitle = Translate('no_draw_zone_hud'), style = MBT.UIStyle or 'standard' },
        })
    end
end

local function onExit()
    inside = math.max(0, inside - 1)
    if inside == 0 and cfg.HudIndicator then
        SendNUIMessage({ action = 'hideNoDraw', data = {} })
    end
end

-- Register every configured zone with ox_lib.
for _, z in ipairs(cfg.Zones or {}) do
    local common = {
        onEnter = function() onEnter(z.label) end,
        onExit  = onExit,
    }
    if z.type == 'poly' then
        lib.zones.poly({
            points = z.points, thickness = z.thickness or 4.0,
            onEnter = common.onEnter, onExit = common.onExit,
        })
    elseif z.type == 'box' then
        lib.zones.box({
            coords = z.coords, size = z.size or vec3(4, 4, 4), rotation = z.rotation or 0.0,
            onEnter = common.onEnter, onExit = common.onExit,
        })
    else
        lib.zones.sphere({
            coords = z.coords, radius = z.radius or 30.0,
            onEnter = common.onEnter, onExit = common.onExit,
        })
    end
end

--- True for melee weapons (allowed through when cfg.AllowMelee).
local function isMelee(weaponHash)
    return GetWeapontypeGroup(weaponHash) == `GROUP_MELEE`
end

-- Enforcement loop — only spins while the player is inside a no-draw zone.
CreateThread(function()
    while true do
        if inside > 0 and cfg.Enabled then
            DisablePlayerFiring(cache.playerId, true)

            local has, weaponHash = GetCurrentPedWeapon(cache.ped, true)
            local blocked = has and weaponHash ~= `WEAPON_UNARMED`
                and not (cfg.AllowMelee and isMelee(weaponHash))

            if blocked then
                -- Put the weapon away (re-slings it through the normal flow).
                TriggerEvent('ox_inventory:disarm', true)
                local now = GetGameTimer()
                if now - lastNotify > (cfg.NotifyCooldown or 3000) then
                    lastNotify = now
                    MBT.NotifyLabel('no_draw_zone')
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and inside > 0 and cfg.HudIndicator then
        SendNUIMessage({ action = 'hideNoDraw', data = {} })
    end
end)
