-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon-Prop Position Editor — client
--
-- Two responsibilities:
--   1) ALL clients: apply a broadcast position change live (update MBT.PropInfo /
--      CustomPropPosition, rebuild propInfoTable via sendAnimations, re-attach the
--      local slung prop of that type).
--   2) ADMIN only: an in-NUI live editor — a preview prop on the ped, an orbit
--      camera driven by NUI buttons, and live re-attach as the admin nudges the
--      offset. Save/Reset go through the ACE-checked server events.
-- ─────────────────────────────────────────────────────────────────────────────

-- Representative weapon shown per type while editing (so you can edit without owning one).
local PREVIEW = {
    side = 'WEAPON_PISTOL', back = 'WEAPON_CARBINERIFLE', back2 = 'WEAPON_RPG',
    melee = 'WEAPON_BAT', melee2 = 'WEAPON_KNIFE', melee3 = 'WEAPON_HATCHET',
    extinguisher = 'WEAPON_FIREEXTINGUISHER',
}

-- ── Shared re-attach (used by broadcast apply) ───────────────────────────────
local function reattachLocal(wtype)
    local prop = GetLocalSlungProp(wtype)
    if not prop then return end
    local info = GetResolvedPropInfo(wtype)
    if not info or not info.Pos then return end
    local ped = cache.ped
    local sex = IsPedMale(ped) and 'male' or 'female'
    local bone = GetPedBoneIndex(ped, info.Bone)
    AttachEntityToEntity(prop, ped, bone,
        info.Pos[sex].x, info.Pos[sex].y, info.Pos[sex].z,
        info.Rot[sex].x, info.Rot[sex].y, info.Rot[sex].z,
        true, true, false, info.isPed, info.RotOrder, info.FixedRot)
end

RegisterNetEvent('mbt_malisling:propPos:apply', function(p)
    if type(p) ~= 'table' or type(p.wtype) ~= 'string' then return end
    if p.scope == 'default' then
        if type(p.data) == 'table' then MBT.PropInfo[p.wtype] = p.data end
    else
        if type(p.data) == 'table' then
            MBT.CustomPropPosition[p.scope] = MBT.CustomPropPosition[p.scope] or {}
            MBT.CustomPropPosition[p.scope][p.wtype] = p.data
        elseif MBT.CustomPropPosition[p.scope] then
            MBT.CustomPropPosition[p.scope][p.wtype] = nil
        end
    end
    -- Rebuild propInfoTable for the local player, then re-attach the live prop.
    if sendAnimations then
        sendAnimations(PlayerData and PlayerData.job and PlayerData.job.name or {})
    end
    reattachLocal(p.wtype)
end)

-- ── Edit mode (admin) ────────────────────────────────────────────────────────
local editing   = false
local previewObj = nil
local editWtype  = nil
local cam        = nil
local orbit      = { yaw = 180.0, pitch = -5.0, dist = 2.4 }

local function destroyPreview()
    if previewObj and DoesEntityExist(previewObj) then DeleteEntity(previewObj) end
    previewObj = nil
end

local function updateCam()
    if not cam then return end
    local c = GetEntityCoords(cache.ped)
    local yawR, pitchR = math.rad(orbit.yaw), math.rad(orbit.pitch)
    local x = c.x + orbit.dist * math.cos(pitchR) * math.sin(yawR)
    local y = c.y + orbit.dist * math.cos(pitchR) * math.cos(yawR)
    local z = c.z + 0.25 + orbit.dist * math.sin(pitchR)
    SetCamCoord(cam, x, y, z)
    PointCamAtEntity(cam, cache.ped, 0.0, 0.0, 0.25, true)
end

--- Attach the PREVIEW prop with the supplied data for the edited gender.
local function applyPreview(data, gender)
    if not previewObj or not DoesEntityExist(previewObj) then return end
    local ped = cache.ped
    local sex = (gender == 'female') and 'female' or 'male'
    local pos, rot = data.Pos[sex], data.Rot[sex]
    local bone = GetPedBoneIndex(ped, data.Bone)
    AttachEntityToEntity(previewObj, ped, bone,
        pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, data.isPed and true or false, data.RotOrder or 2, data.FixedRot ~= false)
end

--- Current effective data for (wtype, job) → seed the editor sliders.
local function currentData(wtype, job)
    local src
    if job and job ~= 'default' and MBT.CustomPropPosition[job] and MBT.CustomPropPosition[job][wtype] then
        src = MBT.CustomPropPosition[job][wtype]
    else
        src = MBT.PropInfo[wtype]
    end
    return json.decode(json.encode(src))   -- deep copy
end

RegisterNUICallback('propEdit:start', function(d, cb)
    local wtype = d and d.wtype
    if not PREVIEW[wtype] then cb({ ok = false }); return end
    editing = true
    editWtype = wtype

    local ped = cache.ped
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    local hash = joaat(PREVIEW[wtype])
    lib.requestWeaponAsset(hash, 1000, 31, 1)
    destroyPreview()
    previewObj = CreateWeaponObject(hash, 50, 0.0, 0.0, 0.0, true, 1.0, 0)
    if previewObj then SetEntityCollision(previewObj, false, false) end

    local data = currentData(wtype, d.job)
    applyPreview(data, d.gender or (IsPedMale(ped) and 'male' or 'female'))

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCam()
    RenderScriptCams(true, false, 0, true, true)

    cb({ ok = true, data = data })
end)

RegisterNUICallback('propEdit:update', function(d, cb)
    if editing and type(d) == 'table' and type(d.data) == 'table' then
        applyPreview(d.data, d.gender)
    end
    cb({})
end)

RegisterNUICallback('propEdit:cam', function(d, cb)
    if editing and type(d) == 'table' then
        orbit.yaw   = (orbit.yaw + (tonumber(d.dyaw) or 0)) % 360
        orbit.pitch = math.max(-80.0, math.min(80.0, orbit.pitch + (tonumber(d.dpitch) or 0)))
        orbit.dist  = math.max(1.0, math.min(5.0, orbit.dist + (tonumber(d.dzoom) or 0)))
        updateCam()
    end
    cb({})
end)

RegisterNUICallback('propEdit:save', function(d, cb)
    if type(d) == 'table' then
        TriggerServerEvent('mbt_malisling:propPos:save', { scope = d.scope, wtype = d.wtype, data = d.data })
    end
    cb({})
end)

RegisterNUICallback('propEdit:reset', function(d, cb)
    if type(d) == 'table' then
        TriggerServerEvent('mbt_malisling:propPos:reset', { scope = d.scope, wtype = d.wtype })
    end
    cb({})
end)

local function stopEditing()
    editing = false
    editWtype = nil
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    destroyPreview()
    FreezeEntityPosition(cache.ped, false)
end

RegisterNUICallback('propEdit:stop', function(_, cb)
    stopEditing()
    cb({})
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and editing then stopEditing() end
end)
