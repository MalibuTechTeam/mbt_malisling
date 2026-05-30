-- ─────────────────────────────────────────────────────────────────────────────
-- No-Draw Zones
--
-- Areas (hospital, PD, courthouse...) where weapons can't be drawn. Inside a zone
-- the player's firing is disabled and any drawn firearm is put away again (via
-- ox_inventory:disarm — the same path the throw uses), with a cooldowned notice.
-- Melee can be left usable (cfg.AllowMelee).
--
-- Detection is client-side via ox_lib zones; enforcement is a tight loop that runs
-- ONLY while inside a zone. Purely RP — a determined cheater could bypass the
-- client check (server-side enforcement is future hardening).
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.NoDrawZones or not MBT.NoDrawZones.Enabled then return end

local cfg = MBT.NoDrawZones

local inside     = 0     -- number of zones currently containing the player (overlap-safe)
local lastNotify = 0

local function onEnter(label)
    inside = inside + 1
    if inside == 1 and cfg.HudIndicator then
        SendNUIMessage({
            action = 'showNoDraw',
            data   = { title = label, subtitle = Translate('no_draw_zone_hud') },
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
---@param weaponHash number
local function isMelee(weaponHash)
    return GetWeapontypeGroup(weaponHash) == `GROUP_MELEE`
end

-- Enforcement loop — only spins while the player is inside a no-draw zone.
CreateThread(function()
    while true do
        if inside > 0 then
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
