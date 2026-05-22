-- ─────────────────────────────────────────────────────────────────────────────
-- Target interaction abstraction.
-- Uses ox_target when the resource is running, otherwise falls back to a
-- drawtext + E-key proximity prompt. ox_target stays an optional (soft)
-- dependency — never required.
-- ─────────────────────────────────────────────────────────────────────────────

Target = {}

local hasOxTarget = GetResourceState('ox_target') == 'started'
local fallbackEntities = {}  -- [entity] = opts

--- Add an interaction option to a specific entity.
---@param entity number
---@param opts { name: string, icon?: string, label: string, distance?: number, onSelect: fun(entity: number) }
function Target.AddEntity(entity, opts)
    if not entity or not DoesEntityExist(entity) then return end
    if hasOxTarget then
        exports['ox_target']:addLocalEntity(entity, {
            {
                name     = opts.name,
                icon     = opts.icon or 'fa-solid fa-hand',
                label    = opts.label,
                distance = opts.distance or 2.0,
                onSelect = function() opts.onSelect(entity) end,
            }
        })
    else
        fallbackEntities[entity] = opts
    end
end

--- Remove all interaction options previously added to an entity.
---@param entity number
function Target.RemoveEntity(entity)
    if not entity then return end
    if hasOxTarget then
        exports['ox_target']:removeLocalEntity(entity)
    else
        fallbackEntities[entity] = nil
    end
end

-- Fallback proximity loop — only runs when ox_target is absent.
if not hasOxTarget then
    CreateThread(function()
        local shown = false
        while true do
            local sleep = 500
            local pcoords = GetEntityCoords(cache.ped)
            local active

            for entity, opts in pairs(fallbackEntities) do
                if DoesEntityExist(entity) then
                    if #(pcoords - GetEntityCoords(entity)) < (opts.distance or 2.0) then
                        active = { entity = entity, opts = opts }
                        break
                    end
                else
                    fallbackEntities[entity] = nil
                end
            end

            if active then
                sleep = 0
                if not shown then
                    lib.showTextUI('[E] ' .. active.opts.label)
                    shown = true
                end
                if IsControlJustReleased(0, 38) then
                    active.opts.onSelect(active.entity)
                end
            elseif shown then
                lib.hideTextUI()
                shown = false
            end

            Wait(sleep)
        end
    end)
end
