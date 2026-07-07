-- Anchor helper — projects a world point to screen each frame and feeds the coords
-- to the NUI, so a cinematic overlay can float next to the weapon/player (botz-style).
-- Shared by the weapon-moment overlays (holster, inspect, …). One tracker at a time:
-- these moments are mutually exclusive (you either holster OR inspect), so a single
-- generation counter kills any running thread when a new one starts or stops.

MBT.Anchor = MBT.Anchor or {}

local activeGen = 0

--- Start feeding `<id>:anchor` messages ({x,y} in 0-1 screen space, or {off=true}
--- when the point is behind the camera). `posFn()` returns the world vec3 to project
--- each frame (or nil to skip a frame). Starting again invalidates the previous tracker.
---@param id string        message prefix, e.g. 'holster' | 'inspect'
---@param posFn fun():vector3?
function MBT.Anchor.Start(id, posFn)
    activeGen = activeGen + 1
    local myGen = activeGen
    CreateThread(function()
        while activeGen == myGen do
            local pos = posFn()
            if pos then
                local on, sx, sy = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z)
                SendNUIMessage({ action = id .. ':anchor', data = on and { x = sx, y = sy } or { off = true } })
            end
            Wait(0)
        end
    end)
end

--- Stop the running tracker (bumping the generation ends its thread next frame).
function MBT.Anchor.Stop()
    activeGen = activeGen + 1
end

--- The player's right hand, lifted by `z`. qb hides the weapon during the holster
--- prompt, so the hand bone is the reliable anchor there.
---@param z number?
---@return vector3
function MBT.Anchor.HandPos(z)
    local ped = cache.ped
    local p = GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, 28422))  -- SKEL_R_Hand
    return vec3(p.x, p.y, p.z + (z or 0.2))
end

--- The held weapon object if drawn+visible (more accurate for inspect), else the hand.
---@param z number?
---@return vector3
function MBT.Anchor.WeaponPos(z)
    local wep = GetCurrentPedWeaponEntityIndex(cache.ped)
    if wep and wep ~= 0 and DoesEntityExist(wep) then
        local c = GetEntityCoords(wep)
        return vec3(c.x, c.y, c.z + (z or 0.12))
    end
    return MBT.Anchor.HandPos(z)
end
