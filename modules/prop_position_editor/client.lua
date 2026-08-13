-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon-Prop Position Editor — client
--   1) ALL clients: apply a broadcast position change live (update MBT.PropInfo/
--      CustomPropPosition, rebuild via sendAnimations, re-attach the local slung prop).
--   2) ADMIN only: in-NUI live editor — preview prop on the ped, orbit camera, live
--      re-attach as the admin nudges. Save/Reset go through ACE-checked server events.
-- ─────────────────────────────────────────────────────────────────────────────

-- Representative weapon shown per type while editing (so you can edit without owning one).
local PREVIEW = {
    side = 'WEAPON_PISTOL', back = 'WEAPON_CARBINERIFLE', back2 = 'WEAPON_RPG',
    melee = 'WEAPON_BAT', melee2 = 'WEAPON_KNIFE', melee3 = 'WEAPON_HATCHET',
    extinguisher = 'WEAPON_FIREEXTINGUISHER',
}

--- The body slot behind a wtype: 'back#2' → 'back'. The extra multi-weapon lanes are prop
--- types of their own so they can be positioned, overridden per job and persisted like any
--- other — but they hold the SAME weapons as the slot they belong to, so anything that asks
--- "which weapon goes here" has to ask about the slot.
---@param wtype string
---@return string
local function baseType(wtype)
    return (type(wtype) == 'string' and wtype:match('^(%w+)#%d+$')) or wtype
end

-- Non-weapon preview types: plain object props (CreateObject). The tactical sling uses
-- per-variant virtual types 'sling:<id>' (bare 'sling' = default variant).
local function slingVariantId(wtype)
    if wtype == 'sling' then return (MBT.TacticalSling and MBT.TacticalSling.DefaultVariant) or 'normal' end
    if type(wtype) == 'string' and wtype:sub(1, 6) == 'sling:' then return wtype:sub(7) end
    return nil
end
local function isObjectType(wtype) return slingVariantId(wtype) ~= nil end
local function previewObjectModel(wtype)
    local vid = slingVariantId(wtype)
    if not vid then return nil end
    local s = MBT.TacticalSling
    for _, v in ipairs((s and s.Variants) or {}) do
        if v.id == vid then return v.model end
    end
    if s and s.Variants and s.Variants[1] then return s.Variants[1].model end
    return s and ((s.Models and s.Models[vid]) or s.Model)
end

-- Factory defaults captured at load — BEFORE any DB override is applied to
-- MBT.PropInfo — so Reset restores the original config.lua position/bone even
-- after an override has been saved.
local PROP_DEFAULTS = json.decode(json.encode(MBT.PropInfo or {}))

-- JSON round-trips turn Bone/RotOrder into floats (2.0); AttachEntityToEntity
-- needs them as integers or the rotation order is read wrong. Normalise on apply.
local function coerceInts(d)
    if type(d) ~= 'table' then return d end
    if d.Bone     ~= nil then d.Bone     = math.floor(tonumber(d.Bone) or 0) end
    if d.RotOrder ~= nil then d.RotOrder = math.floor(tonumber(d.RotOrder) or 2) end
    -- Force Pos/Rot to FLOATS. NUI sliders send INTEGERS that survive JSON->DB->decode as
    -- Lua ints; an integer rotation arg makes AttachEntityToEntity IGNORE the rotation.
    for _, k in ipairs({ 'Pos', 'Rot' }) do
        local g = d[k]
        if type(g) == 'table' then
            for _, sex in ipairs({ 'male', 'female' }) do
                local v = g[sex]
                if type(v) == 'table' then
                    v.x = (tonumber(v.x) or 0.0) + 0.0
                    v.y = (tonumber(v.y) or 0.0) + 0.0
                    v.z = (tonumber(v.z) or 0.0) + 0.0
                end
            end
        end
    end
    return d
end

-- ── Shared re-attach (used by broadcast apply) ───────────────────────────────
local function reattachLocal(wtype)
    local prop = GetLocalSlungProp(wtype)
    if not prop then return end
    local info = GetResolvedPropInfo(wtype)
    if not info or not info.Pos then return end
    local ped = cache.ped
    local sex = IsPedMale(ped) and 'male' or 'female'
    local bone = GetPedBoneIndex(ped, math.floor(tonumber(info.Bone) or 0))
    AttachEntityToEntity(prop, ped, bone,
        info.Pos[sex].x, info.Pos[sex].y, info.Pos[sex].z,
        info.Rot[sex].x, info.Rot[sex].y, info.Rot[sex].z,
        true, true, false, info.isPed, math.floor(tonumber(info.RotOrder) or 2), info.FixedRot)
end

-- Apply ONE override's data to MBT.PropInfo / MBT.CustomPropPosition. No re-attach here —
-- callers rebuild propInfoTable + re-attach afterwards.
local function applyPropPosData(p)
    if type(p) ~= 'table' or type(p.wtype) ~= 'string' then return false end
    if p.scope == 'default' then
        if type(p.data) == 'table' then MBT.PropInfo[p.wtype] = coerceInts(p.data) end
    else
        if type(p.data) == 'table' then
            MBT.CustomPropPosition[p.scope] = MBT.CustomPropPosition[p.scope] or {}
            MBT.CustomPropPosition[p.scope][p.wtype] = coerceInts(p.data)
        elseif MBT.CustomPropPosition[p.scope] then
            MBT.CustomPropPosition[p.scope][p.wtype] = nil
        end
    end
    return true
end

RegisterNetEvent('mbt_malisling:propPos:apply', function(p)
    if not applyPropPosData(p) then return end
    -- Rebuild propInfoTable for the local player, then re-attach the live prop.
    if sendAnimations then
        sendAnimations(PlayerData and PlayerData.job and PlayerData.job.name or {})
    end
    if isObjectType(p.wtype) then
        if MBT.RefreshSling then MBT.RefreshSling() end   -- strap respawns at the new offset
    else
        reattachLocal(p.wtype)
    end
end)

-- Pull DB overrides at init (from core Init() BEFORE its first sendAnimations) so saved
-- positions survive a restart — the broadcast above only reaches already-connected clients.
function MBT.SyncSavedPropPositions()
    local rows = lib.callback.await('mbt_malisling:getPropPositions', false)
    if type(rows) ~= 'table' then return end
    for i = 1, #rows do applyPropPosData(rows[i]) end
end

-- ── Edit mode (admin) ────────────────────────────────────────────────────────
local editing   = false
local previewObj = nil
local editWtype  = nil
local cam        = nil
local orbit      = { yaw = 180.0, pitch = -5.0, dist = 2.4 }
local editData   = nil       -- latest data from the NUI; the render loop applies it
local editGender = 'male'
local dirty      = false      -- re-attach ONLY when something changed, then let soft-pinning settle
local lastGoodPreview = nil   -- last pose whose attach produced a valid (non-NaN) matrix
local applyingFallback = false

local function finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function vecFinite(v)
    return v and finite(v.x) and finite(v.y) and finite(v.z)
end

local function sanitizeAngle(v)
    v = tonumber(v) or 0.0
    return ((v + 180.0) % 360.0) - 180.0   -- wrap to -180..180
end

-- Normalise editor data in place. KEY fix: AttachEntityToEntity with isPed=FALSE ignores
-- pitch and only accepts NEGATIVE roll (high +roll + -pitch → -nan). Force isPed=TRUE for
-- full pitch/roll/yaw, and persist it so the runtime re-attach replays what the preview shows.
local function normalizeEditorData(data)
    if type(data) ~= 'table' then return data end
    data.Bone     = math.floor(tonumber(data.Bone) or 0)
    data.RotOrder = math.floor(tonumber(data.RotOrder) or 2)
    data.FixedRot = data.FixedRot ~= false
    data.isPed    = true
    for _, sex in ipairs({ 'male', 'female' }) do
        if data.Pos and data.Pos[sex] then
            data.Pos[sex].x = tonumber(data.Pos[sex].x) or 0.0
            data.Pos[sex].y = tonumber(data.Pos[sex].y) or 0.0
            data.Pos[sex].z = tonumber(data.Pos[sex].z) or 0.0
        end
        if data.Rot and data.Rot[sex] then
            data.Rot[sex].x = sanitizeAngle(data.Rot[sex].x)
            data.Rot[sex].y = sanitizeAngle(data.Rot[sex].y)
            data.Rot[sex].z = sanitizeAngle(data.Rot[sex].z)
        end
    end
    return data
end

local function destroyPreview()
    if previewObj and DoesEntityExist(previewObj) then DeleteEntity(previewObj) end
    previewObj = nil
    lastGoodPreview = nil
end

-- While editing, hide the player's REAL slung weapon(s) so the preview prop doesn't
-- overlap them. Restored on stop.
local hiddenSlung = {}
local function hideRealSlung()
    hiddenSlung = {}
    -- SetEntityVisible doesn't reliably hide attached weapon objects, so DELETE. reserve
    -- keeps the slot claimed so syncSling won't respawn it while editing.
    Slung.forEach(cache.serverId, function(_, wtype, serial)
        Slung.deleteSerial(cache.serverId, wtype, serial, { reserve = true })
        hiddenSlung[#hiddenSlung + 1] = { wtype, serial }
    end)
end
local function restoreRealSlung()
    if #hiddenSlung == 0 then return end
    for i = 1, #hiddenSlung do   -- release the slots
        Slung.deleteSerial(cache.serverId, hiddenSlung[i][1], hiddenSlung[i][2])
    end
    hiddenSlung = {}
    TriggerServerEvent('mbt_malisling:checkInventory')   -- respawn the real props fresh on exit
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
    data = normalizeEditorData(data)
    local ped = cache.ped
    local sex = (gender == 'female') and 'female' or 'male'
    local pos, rot = data.Pos[sex], data.Rot[sex]
    if not pos or not rot then return end   -- guard against malformed data
    local bone = GetPedBoneIndex(ped, data.Bone)
    local rotOrder = data.RotOrder
    -- isPed=TRUE (the fix): isPed=false ignores pitch + only takes negative roll → NaN matrix.
    -- isPed=true applies full pitch/roll/yaw; persisted so the runtime re-attach matches.
    AttachEntityToEntity(previewObj, ped, bone,
        pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, rotOrder, data.FixedRot ~= false)

    -- Guard: if the native still produced a NaN matrix, revert to the last valid pose.
    local f = GetEntityForwardVector(previewObj)
    if not vecFinite(f) then
        Utils.mbtWarn(('rejected NaN attach | bone=%s ro=%s rot=%s,%s,%s'):format(
            tostring(bone), tostring(rotOrder), tostring(rot.x), tostring(rot.y), tostring(rot.z)))
        if lastGoodPreview and not applyingFallback then
            applyingFallback = true
            applyPreview(json.decode(json.encode(lastGoodPreview)), editGender)
            applyingFallback = false
        end
        return
    end
    lastGoodPreview = json.decode(json.encode(data))
end

--- Current effective data for (wtype, job) → seed the editor sliders.
--- Mirrors the runtime's resolution order (getAttachInfo in core/client.lua), including the
--- lane fallback: a job that moved the base but has no position for this lane is shown its
--- own base plus the factory offset, not the global lane. Seeding it any other way would
--- open the editor with the weapon somewhere the game never draws it.
local function currentData(wtype, job)
    local custom = (job and job ~= 'default') and MBT.CustomPropPosition[job] or nil
    local src

    if custom and custom[wtype] then
        src = custom[wtype]
    else
        local base, lane = wtype:match('^(%w+)#(%d+)$')
        local off = base and (MBT.MultiWeaponVisibility or {}).LaneOffsets
        off = off and off[base] and off[base][tonumber(lane)]

        if custom and base and custom[base] and off then
            src = json.decode(json.encode(custom[base]))
            for _, sex in ipairs({ 'male', 'female' }) do
                local p, r = src.Pos[sex], src.Rot[sex]
                local dp, dr = off.Pos or {}, off.Rot or {}
                p.x, p.y, p.z = p.x + (dp.x or 0.0), p.y + (dp.y or 0.0), p.z + (dp.z or 0.0)
                r.x, r.y, r.z = r.x + (dr.x or 0.0), r.y + (dr.y or 0.0), r.z + (dr.z or 0.0)
            end
            return src   -- already a copy
        end
        src = MBT.PropInfo[wtype]
    end

    return json.decode(json.encode(src))   -- deep copy
end

RegisterNUICallback('propEdit:start', function(d, cb)
    local wtype = d and d.wtype
    if not PREVIEW[baseType(wtype)] and not isObjectType(wtype) then cb({ ok = false }); return end
    editing = true
    editWtype = wtype
    if isObjectType(wtype) then
        -- Hide only the real strap (keep weapons visible as an alignment reference).
        if MBT.SetSlingEditing then MBT.SetSlingEditing(true) end
    else
        hideRealSlung()
        -- Show the sling strap (if eligible) as a placement reference.
        if MBT.SetSlingWeaponPreview then MBT.SetSlingWeaponPreview(baseType(wtype)) end
    end

    local ped = cache.ped
    -- IMPORTANT: do NOT freeze the ped or disable the prop's collision. Soft-pinning is a
    -- PHYSICS constraint; killing it leaves only the raw Euler → gimbal lock. /mbt_propedit
    -- does neither, which is why rotation works there. NUI focus already blocks movement.
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    destroyPreview()
    -- Create the prop AT the ped (not world origin, which made soft-pinning drag it across
    -- the map on attach → fling/vanish).
    local pc = GetEntityCoords(ped)
    if isObjectType(wtype) then
        -- Plain object prop (e.g. sling strap): CreateObject, not CreateWeaponObject.
        local model = joaat(previewObjectModel(wtype) or '')
        if not IsModelValid(model) then editing = false; cb({ ok = false }); return end
        lib.requestModel(model, 2000)
        previewObj = CreateObject(model, pc.x, pc.y, pc.z, false, false, false)
        SetModelAsNoLongerNeeded(model)
    else
        local hash = joaat(PREVIEW[baseType(wtype)])
        lib.requestWeaponAsset(hash, 1000, 31, 1)
        previewObj = CreateWeaponObject(hash, 50, pc.x, pc.y, pc.z, true, 1.0, 0)
    end

    local data = currentData(wtype, d.job)
    normalizeEditorData(data)
    editData   = data
    editGender = d.gender or (IsPedMale(ped) and 'male' or 'female')
    applyPreview(editData, editGender)

    -- Default camera: BEHIND the ped so the slung weapon is in frame. From the forward
    -- vector — a fixed world yaw (180) only framed the back when the ped faced north.
    local fwd = GetEntityForwardVector(ped)
    orbit.yaw = math.deg(math.atan(-fwd.x, -fwd.y)) % 360.0
    orbit.pitch, orbit.dist = -5.0, 2.4
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCam()
    RenderScriptCams(true, false, 0, true, true)

    -- Render loop: re-attach ONLY when a value changed (dirty), then STOP — like
    -- /mbt_propedit. Re-attaching a SOFT-PINNED prop every frame never lets the physics
    -- constraint settle → diverges to NaN (prop vanishes / snaps to stock). Settling is the fix.
    CreateThread(function()
        while editing do
            Wait(0)
            if dirty and editData then
                dirty = false
                applyPreview(editData, editGender)
            end
        end
    end)

    cb({ ok = true, data = data, view = { yaw = orbit.yaw, pitch = orbit.pitch, dist = orbit.dist } })
end)

RegisterNUICallback('propEdit:update', function(d, cb)
    if editing and type(d) == 'table' and type(d.data) == 'table' then
        editData   = normalizeEditorData(d.data)   -- render loop re-attaches next frame
        editGender = d.gender or editGender
        dirty      = true
    end
    cb({})
end)

RegisterNUICallback('propEdit:cam', function(d, cb)
    if editing and type(d) == 'table' then
        -- Absolute values from the NUI sliders (clamped).
        if d.yaw   ~= nil then orbit.yaw   = (tonumber(d.yaw) or orbit.yaw) % 360 end
        if d.pitch ~= nil then orbit.pitch = math.max(-80.0, math.min(80.0, tonumber(d.pitch) or orbit.pitch)) end
        if d.dist  ~= nil then orbit.dist  = math.max(1.0, math.min(5.0, tonumber(d.dist) or orbit.dist)) end
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
    if type(d) ~= 'table' or not d.wtype then cb({}); return end
    -- Persist the reset, then snap the live preview + sliders back to the factory default.
    TriggerServerEvent('mbt_malisling:propPos:reset', { scope = d.scope, wtype = d.wtype })
    local def = PROP_DEFAULTS[d.wtype]
    if not def then cb({}); return end
    local data = json.decode(json.encode(def))   -- fresh copy
    normalizeEditorData(data)
    editData   = data
    editGender = d.gender or editGender
    applyPreview(data, editGender)
    cb(data)
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
    restoreRealSlung()
    if MBT.SetSlingEditing then MBT.SetSlingEditing(false) end   -- strap respawns at the saved offset
    if MBT.SetSlingWeaponPreview then MBT.SetSlingWeaponPreview(nil) end
    FreezeEntityPosition(cache.ped, false)
end

RegisterNUICallback('propEdit:stop', function(_, cb)
    stopEditing()
    cb({})
end)

-- NUI → server bridge: the Positions section fetches the framework job list.
RegisterNUICallback('getJobs', function(_, cb)
    cb(lib.callback.await('mbt_malisling:getJobs', false) or {})
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and editing then stopEditing() end
end)
