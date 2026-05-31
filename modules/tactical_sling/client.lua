-- ─────────────────────────────────────────────────────────────────────────────
-- Tactical Sling Prop (visible strap)
--
-- Shows a visible sling/strap on the torso while a long gun is slung. Implemented
-- as a PROP attached to a bone (CreateObject + AttachEntityToEntity), NOT as a
-- clothing component — clothing would require a per-server drawable index and
-- conflict with the server's own addons, which makes it non-distributable. A prop
-- is fully portable: it depends only on the model shipped in this resource's
-- stream/ folder, exactly like the weapon-on-back props.
--
-- Local player only (other clients attach their own). Follows the slung-prop
-- state: any eligible long gun slung → strap shown. DISABLED by default until a
-- strap model is shipped and configured (MBT.TacticalSling.Model / Enabled).
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.TacticalSling then return end

local cfg = MBT.TacticalSling

local strapObj = nil   -- the spawned strap prop entity (local player)

local function isFreemode(ped)
    local m = GetEntityModel(ped)
    return m == `mp_m_freemode_01` or m == `mp_f_freemode_01`
end

--- Any eligible long gun currently slung on the local player?
local function hasEligibleSlung()
    for propType in pairs(cfg.Types) do
        if cfg.Types[propType] and GetLocalSlungProp(propType) then
            return true
        end
    end
    return false
end

local function removeStrap()
    if strapObj and DoesEntityExist(strapObj) then DeleteEntity(strapObj) end
    strapObj = nil
end

local function spawnStrap(ped)
    if strapObj and DoesEntityExist(strapObj) then return end
    local model = joaat(cfg.Model)
    if not IsModelValid(model) then
        Utils.mbtWarn('tactical_sling ~ invalid model: ' .. tostring(cfg.Model))
        return
    end
    lib.requestModel(model, 2000)
    if not HasModelLoaded(model) then return end

    local p = cfg.Position
    local obj = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 or not DoesEntityExist(obj) then return end

    local boneIndex = GetPedBoneIndex(ped, p.Bone)
    AttachEntityToEntity(obj, ped, boneIndex,
        p.Pos.x, p.Pos.y, p.Pos.z, p.Rot.x, p.Rot.y, p.Rot.z,
        true, true, false, false, 2, true)
    strapObj = obj
end

if cfg.Enabled then
    CreateThread(function()
        while true do
            Wait(750)
            local ped = cache.ped
            if ped and ped ~= 0 and isFreemode(ped) then
                local want = hasEligibleSlung()
                if want and not (strapObj and DoesEntityExist(strapObj)) then
                    spawnStrap(ped)
                elseif not want and strapObj then
                    removeStrap()
                end
            end
        end
    end)
end

-- Re-spawn cleanly after ped/skin change.
lib.onCache('ped', removeStrap)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then removeStrap() end
end)

-- ── Strap position finder (Debug) ────────────────────────────────────────────
-- /mbt_slingpos  → spawns the strap model on the bone and lets you nudge its
-- position/rotation with arrow keys, then dumps a config-ready snippet. Same UX
-- as /mbt_propedit. Works even when the feature is disabled, so you can tune the
-- model before enabling it.
if MBT.Debug then
    local FIELDS  = { 'posX', 'posY', 'posZ', 'rotX', 'rotY', 'rotZ' }
    local editing = false

    local function drawT(x, y, scale, text, r, g, b)
        SetTextFont(4); SetTextScale(scale, scale); SetTextColour(r, g, b, 255)
        SetTextOutline(); SetTextEntry("STRING"); AddTextComponentSubstringPlayerName(text); DrawText(x, y)
    end

    RegisterCommand('mbt_slingpos', function()
        if editing then editing = false return end
        local model = joaat(cfg.Model)
        if not IsModelValid(model) then
            print('^8[mbt_slingpos] invalid model: '..tostring(cfg.Model)..' (set MBT.TacticalSling.Model)^7'); return
        end
        lib.requestModel(model, 2000)
        local ped  = cache.ped
        local prop = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
        SetModelAsNoLongerNeeded(model)
        if not prop or prop == 0 then print('^8[mbt_slingpos] failed to create object^7') return end

        editing = true
        local bone = GetPedBoneIndex(ped, cfg.Position.Bone)
        local v = { posX = cfg.Position.Pos.x, posY = cfg.Position.Pos.y, posZ = cfg.Position.Pos.z,
                    rotX = cfg.Position.Rot.x, rotY = cfg.Position.Rot.y, rotZ = cfg.Position.Rot.z }
        local sel = 1
        local function reattach()
            AttachEntityToEntity(prop, ped, bone, v.posX, v.posY, v.posZ, v.rotX, v.rotY, v.rotZ, true, true, false, false, 2, true)
        end
        reattach()
        print('^2[mbt_slingpos] editor open — arrows adjust, Enter dumps, Backspace exits^7')

        CreateThread(function()
            while editing do
                DisableControlAction(0, 172, true); DisableControlAction(0, 173, true)
                DisableControlAction(0, 174, true); DisableControlAction(0, 175, true)
                DisableControlAction(0, 191, true); DisableControlAction(0, 177, true)
                if IsDisabledControlJustPressed(0, 172) then sel = sel - 1; if sel < 1 then sel = #FIELDS end
                elseif IsDisabledControlJustPressed(0, 173) then sel = sel + 1; if sel > #FIELDS then sel = 1 end end
                local field = FIELDS[sel]
                local step = field:sub(1,3) == 'rot' and 1.0 or 0.004
                if IsDisabledControlPressed(0, 174) then v[field] = v[field] - step; reattach()
                elseif IsDisabledControlPressed(0, 175) then v[field] = v[field] + step; reattach() end
                if IsDisabledControlJustPressed(0, 191) then
                    print('^2[mbt_slingpos] Position = {^7')
                    print(('    Bone = %d, Pos = { x = %.3f, y = %.3f, z = %.3f }, Rot = { x = %.1f, y = %.1f, z = %.1f },')
                        :format(cfg.Position.Bone, v.posX, v.posY, v.posZ, v.rotX, v.rotY, v.rotZ))
                    print('^2}^7')
                end
                if IsDisabledControlJustPressed(0, 177) then editing = false end
                drawT(0.35, 0.32, 0.5, 'MBT Sling Position', 255, 220, 0)
                for i = 1, #FIELDS do
                    local f = FIELDS[i]
                    drawT(0.35, 0.345 + i*0.026, 0.42, ('%s %s : %.3f'):format(i==sel and '>' or '  ', f, v[f]),
                        i==sel and 255 or 230, 220, i==sel and 0 or 230)
                end
                Wait(0)
            end
            if DoesEntityExist(prop) then DeleteEntity(prop) end
            print('^2[mbt_slingpos] closed^7')
        end)
    end, false)
end
