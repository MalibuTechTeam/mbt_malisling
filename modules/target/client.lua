-- ─────────────────────────────────────────────────────────────────────────────
-- Target interaction abstraction (coords / sphere-zone based).
-- Uses ox_target sphere zones, NOT entity targeting: addLocalEntity/raycast does
-- not register CreateWeaponObject props; a coords sphere is entity-type agnostic.
-- Falls back to drawtext + E-key proximity when ox_target (soft dep) is absent.
-- ─────────────────────────────────────────────────────────────────────────────

Target = {}

local oxZones       = {}  -- [id] = ox_target zone handle
local fallbackZones = {}  -- [id] = { coords = vec3, opts = table }

--- Checked per-call, not cached: start order isn't guaranteed, so a load-time snapshot can be permanently wrong.
local function oxTargetReady()
    return GetResourceState('ox_target') == 'started'
end

--- Add a coords-based interaction zone.
---@param id string|number  unique id, used to remove the zone later
---@param coords vector3
---@param radius number
---@param opts { name: string, icon?: string, label: string, distance?: number, onSelect: fun() }
function Target.AddZone(id, coords, radius, opts)
    if oxTargetReady() then
        oxZones[id] = exports['ox_target']:addSphereZone({
            coords  = coords,
            radius  = radius,
            options = {
                {
                    name     = opts.name,
                    icon     = opts.icon or 'fa-solid fa-hand',
                    label    = opts.label,
                    distance = opts.distance or 2.5,
                    onSelect = opts.onSelect,
                }
            }
        })
        Utils.mbtDebugger("Target.AddZone ~ ox_target sphere zone, id:", id)
    else
        fallbackZones[id] = { coords = coords, opts = opts }
        Utils.mbtDebugger("Target.AddZone ~ fallback drawtext, id:", id)
    end
end

---@param id string|number
function Target.RemoveZone(id)
    if oxZones[id] then
        exports['ox_target']:removeZone(oxZones[id])
        oxZones[id] = nil
    end
    fallbackZones[id] = nil
end

-- Fallback proximity loop — only acts while ox_target is absent and zones exist.
CreateThread(function()
    local shown = false
    while true do
        local sleep = 500

        if next(fallbackZones) then
            local pcoords = GetEntityCoords(cache.ped)
            local active

            for _, z in pairs(fallbackZones) do
                if #(pcoords - z.coords) < (z.opts.distance or 2.5) then
                    active = z
                    break
                end
            end

            if active then
                sleep = 0
                if not shown then
                    lib.showTextUI('[E] ' .. active.opts.label)
                    shown = true
                end
                if IsControlJustReleased(0, 38) then
                    active.opts.onSelect()
                end
            elseif shown then
                lib.hideTextUI()
                shown = false
            end
        elseif shown then
            lib.hideTextUI()
            shown = false
        end

        Wait(sleep)
    end
end)
