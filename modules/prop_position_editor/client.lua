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

-- Non-weapon preview types: plain object props (CreateObject, not CreateWeaponObject). The
-- tactical sling uses per-variant virtual types 'sling:<id>' (bare 'sling' = default variant).
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
    -- Force Pos/Rot to FLOATS. The NUI's React rotation sliders send INTEGERS, which survive
    -- JSON -> DB -> decode as Lua integers; an integer rotation arg makes AttachEntityToEntity
    -- IGNORE the rotation (prop stuck at the default pose). Floats at the source fix it.
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

-- Pull the DB-persisted overrides at init (called from core Init() BEFORE its first
-- sendAnimations) so saved positions survive a resource restart — the broadcast above
-- only reaches clients already connected when the save happened.
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

-- Normalise editor data in place. The KEY fix (from the rotation NaN investigation):
-- AttachEntityToEntity with isPed=FALSE ignores pitch and only accepts NEGATIVE roll,
-- which is exactly why high positive roll + negative pitch produced -nan. Forcing
-- isPed=TRUE makes the native apply full pitch/roll/yaw correctly. We also persist
-- isPed=true so the runtime re-attach replays the prop the same way the preview shows it.
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

-- While editing, hide the player's REAL slung weapon(s) so the editor preview prop doesn't
-- overlap/duplicate them (e.g. editing 'back' while a real rifle is already slung). We hide
-- (not delete) to avoid a respawn round-trip; restored on stop.
local hiddenSlung = {}
local function hideRealSlung()
    hiddenSlung = {}
    local mine = playersToTrack and playersToTrack[cache.serverId]
    if type(mine) ~= 'table' then return end
    for wtype, prop in pairs(mine) do
        if type(prop) == 'number' and DoesEntityExist(prop) then
            -- SetEntityVisible doesn't reliably hide attached weapon objects, so DELETE them
            -- (the core does the same for vehicle hiding). The `true` sentinel keeps the slot
            -- reserved so syncSling won't respawn it while editing.
            DeleteEntity(prop)
            mine[wtype] = true
            hiddenSlung[#hiddenSlung + 1] = wtype
        end
    end
end
local function restoreRealSlung()
    if #hiddenSlung == 0 then return end
    local mine = playersToTrack and playersToTrack[cache.serverId]
    if type(mine) == 'table' then
        for i = 1, #hiddenSlung do mine[hiddenSlung[i]] = false end   -- release the slots
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
    -- isPed = TRUE (the fix). With isPed=false the native ignores pitch and only takes
    -- negative roll → high positive roll + negative pitch returned a NaN matrix. isPed=true
    -- applies full pitch/roll/yaw. rotOrder stays the integer 2. We persist isPed=true so
    -- the runtime re-attach replays exactly what the preview shows.
    AttachEntityToEntity(previewObj, ped, bone,
        pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, rotOrder, data.FixedRot ~= false)

    -- Guard: if the native still produced a NaN matrix, revert to the last valid pose
    -- instead of leaving the entity poisoned.
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
    if not PREVIEW[wtype] and not isObjectType(wtype) then cb({ ok = false }); return end
    editing = true
    editWtype = wtype
    if isObjectType(wtype) then
        -- Hide only the real strap (keep weapons visible as an alignment reference).
        if MBT.SetSlingEditing then MBT.SetSlingEditing(true) end
    else
        -- Hide the player's real slung weapon(s) so the preview prop doesn't overlap them.
        hideRealSlung()
        -- Show the tactical sling strap (if enabled + this weapon type is eligible) as a
        -- placement reference while positioning the weapon.
        if MBT.SetSlingWeaponPreview then MBT.SetSlingWeaponPreview(wtype) end
    end

    local ped = cache.ped
    -- IMPORTANT: do NOT FreezeEntityPosition the ped and do NOT SetEntityCollision
    -- off on the prop. Soft-pinning is a PHYSICS constraint; freezing the ped /
    -- killing the prop's collision disables the physics it needs to reorient the
    -- prop → only the raw Euler applies → gimbal lock. /mbt_propedit does neither,
    -- which is exactly why rotation works there. NUI focus already blocks movement.
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    destroyPreview()
    -- Create the prop AT the ped (like /mbt_propedit). Creating it at world origin
    -- (0,0,0) made soft-pinning try to drag it across the map on attach → fling/vanish.
    local pc = GetEntityCoords(ped)
    if isObjectType(wtype) then
        -- Plain object prop (e.g. sling strap): CreateObject, not CreateWeaponObject.
        local model = joaat(previewObjectModel(wtype) or '')
        if not IsModelValid(model) then editing = false; cb({ ok = false }); return end
        lib.requestModel(model, 2000)
        previewObj = CreateObject(model, pc.x, pc.y, pc.z, false, false, false)
        SetModelAsNoLongerNeeded(model)
    else
        local hash = joaat(PREVIEW[wtype])
        lib.requestWeaponAsset(hash, 1000, 31, 1)
        previewObj = CreateWeaponObject(hash, 50, pc.x, pc.y, pc.z, true, 1.0, 0)
    end

    local data = currentData(wtype, d.job)
    normalizeEditorData(data)
    editData   = data
    editGender = d.gender or (IsPedMale(ped) and 'male' or 'female')
    applyPreview(editData, editGender)

    -- Default camera: BEHIND the ped so the slung weapon (back/side/hip) is in frame.
    -- Derived from the ped's real forward vector — a fixed world yaw (180) only framed
    -- the back when the ped happened to face north; any other heading missed it.
    local fwd = GetEntityForwardVector(ped)
    orbit.yaw = math.deg(math.atan(-fwd.x, -fwd.y)) % 360.0
    orbit.pitch, orbit.dist = -5.0, 2.4
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCam()
    RenderScriptCams(true, false, 0, true, true)

    -- Render loop: re-attach ONLY when a value actually changed (dirty), then STOP —
    -- exactly like /mbt_propedit (which re-attaches only while a key is held).
    -- Re-attaching a SOFT-PINNED prop every single frame forever never lets the physics
    -- constraint settle: it diverges to NaN (forward vector = nan → the prop vanishes /
    -- snaps to a stock pose). Letting it settle between changes is the whole fix.
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
        editData   = normalizeEditorData(d.data)   -- render loop re-attaches once next frame
        editGender = d.gender or editGender
        dirty      = true
    end
    cb({})
end)

RegisterNUICallback('propEdit:cam', function(d, cb)
    if editing and type(d) == 'table' then
        -- Absolute values from the NUI sliders (clamped).
        if d.yaw   ~= nil then orbit.yaw   = tonumber(d.yaw) % 360 end
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
    -- Clear any saved override (persist the reset) ...
    TriggerServerEvent('mbt_malisling:propPos:reset', { scope = d.scope, wtype = d.wtype })
    -- ... and snap the live preview + sliders back to the factory default.
    local def = PROP_DEFAULTS[d.wtype]
    if not def then cb({}); return end
    local data = json.decode(json.encode(def))   -- fresh copy
    normalizeEditorData(data)
    editData   = data                            -- feed the render loop the reset values
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
