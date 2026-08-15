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
    -- melee/melee3 used to hold each other's weapon (bat is melee3, hatchet is melee per
    -- data/weapons.lua), so both slots were tuned against a model from the other one.
    melee = 'WEAPON_HATCHET', melee2 = 'WEAPON_KNIFE', melee3 = 'WEAPON_BAT',
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

-- ── Length-class offset being edited ─────────────────────────────────────────
-- The class shift is what makes ONE tuned position fit a slot that holds weapons of very
-- different lengths, so it has to be tunable where you can see it — and the preview has to
-- apply it, or the editor would once again show a pose the game does not draw.
-- Lives here rather than in the position: it belongs to the weapon's size, not to the slot,
-- and it is shared by every lane of that slot.
local editClass                     -- 'compact' | 'long' | nil (standard has no offset)
local editClassOff                  -- live { Pos = {x,y,z}, Rot = {x,y,z} } being dragged

--- The saved offset for a slot and class, as a copy the sliders can move freely.
--- nil when the slot has no offsets declared in default.lua: the save path writes onto that
--- table and would drop the payload on the floor, so the panel must not offer the control.
local function classOffsetOf(slot, class)
    if not class or class == 'standard' then return nil end
    local byClass = (MBT.WeaponClassOffsets or {})[slot]
    if not byClass then return nil end
    local o = byClass[class]
    local p, r = (o and o.Pos) or {}, (o and o.Rot) or {}
    return {
        Pos = { x = (tonumber(p.x) or 0.0) + 0.0, y = (tonumber(p.y) or 0.0) + 0.0, z = (tonumber(p.z) or 0.0) + 0.0 },
        Rot = { x = (tonumber(r.x) or 0.0) + 0.0, y = (tonumber(r.y) or 0.0) + 0.0, z = (tonumber(r.z) or 0.0) + 0.0 },
    }
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
local editJob    = 'default'  -- scope being edited; the reference lanes resolve against it
local editWeapon = nil        -- model loaded in the preview; the reference lanes mirror it
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
    -- Same sum the runtime does in spawnProp: without it the editor would show the loaded
    -- weapon at the bare position and the game would draw it shifted.
    if editClassOff then
        local dp, dr = editClassOff.Pos, editClassOff.Rot
        pos = { x = pos.x + dp.x, y = pos.y + dp.y, z = pos.z + dp.z }
        rot = { x = rot.x + dr.x, y = rot.y + dr.y, z = rot.z + dr.z }
    end
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

-- ── Reference lanes ──────────────────────────────────────────────────────────
-- The other lanes of the same slot, shown while editing one of them. You judge where the
-- second rifle goes AGAINST the first — with the first hidden you are placing blind, and
-- the number on the slider tells you nothing about whether the two intersect.
-- Faded and never touched by the sliders, so it reads as scenery rather than as the thing
-- being moved.
-- Each entry keeps the pose it was placed with, so dragging the class shift can move these
-- too without rebuilding the props: the shift applies to every lane of the slot, so if the
-- reference stood still you would read a growing gap that the game never opens.
local refProps = {}   -- { obj = handle, info = table, sex = 'male'|'female' }

local function destroyReferenceLanes()
    for i = 1, #refProps do
        if DoesEntityExist(refProps[i].obj) then DeleteEntity(refProps[i].obj) end
    end
    refProps = {}
end

--- Re-attach the reference lanes with the shift currently on the sliders.
local function reattachReferenceLanes()
    local dp = editClassOff and editClassOff.Pos or { x = 0.0, y = 0.0, z = 0.0 }
    local dr = editClassOff and editClassOff.Rot or { x = 0.0, y = 0.0, z = 0.0 }
    local ped = cache.ped
    for i = 1, #refProps do
        local ref = refProps[i]
        if DoesEntityExist(ref.obj) then
            local p, r = ref.info.Pos[ref.sex], ref.info.Rot[ref.sex]
            AttachEntityToEntity(ref.obj, ped, GetPedBoneIndex(ped, math.floor(tonumber(ref.info.Bone) or 0)),
                p.x + dp.x, p.y + dp.y, p.z + dp.z, r.x + dr.x, r.y + dr.y, r.z + dr.z,
                true, true, false, ref.info.isPed == true, math.floor(tonumber(ref.info.RotOrder) or 2),
                ref.info.FixedRot ~= false)
        end
    end
end

--- Spawn a faded prop for every OTHER lane of this slot, at the position the game would
--- actually draw it (job and gender resolved exactly as currentData does).
---@param wtype string  the lane being edited
---@param job string
---@param gender string
---@param weapon string?  what to show in the other lanes; defaults to the slot's standard.
---   Follows the Preview picker, so loading a sniper shows sniper-against-sniper — the worst
---   case for two weapons in one slot, and the one worth tuning against. Showing the standard
---   here while the edited lane held a long one made the pair look like it cleared when the
---   real pair does not.
local function spawnReferenceLanes(wtype, job, gender, weapon)
    destroyReferenceLanes()

    local base = baseType(wtype)
    weapon = weapon or PREVIEW[base]
    if not weapon then return end

    -- Every lane the SERVER would actually fill, the edited one excluded. The extra lanes
    -- are seeded into PropInfo whether or not the feature is on, so going by "has a
    -- position" drew a faded second rifle on a server that will never show one — a
    -- reference to something that does not exist is worse than no reference.
    local mw = MBT.MultiWeaponVisibility or {}
    local maxLane = mw.Enabled and math.max(1, math.floor(tonumber(mw.MaxPerType) or 2)) or 1
    local keys = { base }
    for lane = 2, maxLane do
        local key = base .. '#' .. lane
        if MBT.PropInfo[key] then keys[#keys + 1] = key end
    end

    local ped = cache.ped
    local sex = (gender == 'female') and 'female' or 'male'
    local hash = joaat(weapon)
    if not pcall(lib.requestWeaponAsset, hash, 5000, 31, 1) then return end

    local pc = GetEntityCoords(ped)
    for i = 1, #keys do
        local key = keys[i]
        if key ~= wtype then
            local info = currentData(key, job)
            if info and info.Pos and info.Pos[sex] then
                local obj = CreateWeaponObject(hash, 50, pc.x, pc.y, pc.z, true, 1.0, 0)
                if obj and DoesEntityExist(obj) then
                    SetEntityCompletelyDisableCollision(obj, false, true)
                    SetEntityAlpha(obj, 150, false)   -- reference, not the thing you are moving
                    refProps[#refProps + 1] = { obj = obj, info = info, sex = sex }
                end
            end
        end
    end
    RemoveWeaponAsset(hash)
    reattachReferenceLanes()   -- one place decides where these sit, shift included
end

RegisterNUICallback('propEdit:start', function(d, cb)
    local wtype = d and d.wtype
    if not PREVIEW[baseType(wtype)] and not isObjectType(wtype) then cb({ ok = false }); return end
    editing = true
    editWtype = wtype
    editJob   = (d and type(d.job) == 'string' and d.job) or 'default'
    if isObjectType(wtype) then
        -- Hide only the real strap (keep weapons visible as an alignment reference).
        if MBT.SetSlingEditing then MBT.SetSlingEditing(true) end
    else
        hideRealSlung()
        -- Show the sling strap (if eligible) as a placement reference.
        if MBT.SetSlingWeaponPreview then MBT.SetSlingWeaponPreview(baseType(wtype)) end
        -- And the slot's OTHER lanes, faded. A second rifle is placed against the first,
        -- not against a number on a slider: without this you are working blind and only
        -- find out they intersect once you leave the editor.
        -- Class first: the reference lanes are placed with the shift applied, so it has to
        -- be resolved before they go down.
        editWeapon   = PREVIEW[baseType(wtype)]
        editClass    = (MBT.WeaponLengthClass or {})[editWeapon] or 'standard'
        editClassOff = classOffsetOf(baseType(wtype), editClass)
        spawnReferenceLanes(wtype, editJob, d and d.gender or 'male', editWeapon)
    end

    local ped = cache.ped
    -- IMPORTANT: do NOT freeze the ped. NUI focus already blocks movement, and freezing
    -- was what used to break the attach. The prop's collision IS disabled below, matching
    -- what the runtime does to a real slung weapon — anything else and the preview shows a
    -- position the game will not reproduce.
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
        -- Exactly what spawnProp does to a real slung weapon after attaching it. Without it
        -- the preview stays a physics body under a soft-pinning constraint and settles a
        -- couple of centimetres off, so the position you tune is not the position the game
        -- draws. Nobody caught it while a slot held one weapon and there was nothing beside
        -- it to compare against; with two lanes the gap is obvious.
        SetEntityCompletelyDisableCollision(previewObj, false, true)
    end

    local data = currentData(wtype, d.job)
    normalizeEditorData(data)
    editData   = data
    editGender = d.gender or (IsPedMale(ped) and 'male' or 'female')
    -- A plain object prop (the sling strap) has no length class to shift.
    if isObjectType(wtype) then editWeapon, editClass, editClassOff = nil, nil, nil end
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

    cb({
        ok = true, data = data,
        view = { yaw = orbit.yaw, pitch = orbit.pitch, dist = orbit.dist },
        weapon = editWeapon, class = editClass, offset = editClassOff,
    })
end)

RegisterNUICallback('propEdit:update', function(d, cb)
    if editing and type(d) == 'table' and type(d.data) == 'table' then
        local wasGender = editGender
        editData   = normalizeEditorData(d.data)   -- render loop re-attaches next frame
        editGender = d.gender or editGender
        dirty      = true
        -- The faded reference lanes were placed for the gender you were on. Leave them and
        -- you would be judging a female lane 2 against where the male lane 1 sits.
        if editGender ~= wasGender and not isObjectType(editWtype) then
            spawnReferenceLanes(editWtype, editJob, editGender, editWeapon)
        end
    end
    cb({})
end)

--- Drag the class offset instead of the position. Same sliders on the NUI side — what
--- changes is which of the two the drag lands on, which is why the panel says so.
RegisterNUICallback('propEdit:classOffset', function(d, cb)
    if not editing or not editClass or editClass == 'standard' or type(d) ~= 'table' then
        cb({ ok = false }); return
    end
    local p, r = d.Pos, d.Rot
    if type(p) ~= 'table' or type(r) ~= 'table' then cb({ ok = false }); return end
    -- Clamped to the same range the server validates: a shift past ~30cm is not a length
    -- correction any more, and the sliders should not be able to write what a save rejects.
    local function clamp(v, lo, hi) return math.max(lo, math.min(hi, (tonumber(v) or 0.0) + 0.0)) end
    editClassOff = {
        Pos = { x = clamp(p.x, -0.3, 0.3), y = clamp(p.y, -0.3, 0.3), z = clamp(p.z, -0.3, 0.3) },
        Rot = { x = clamp(r.x, -180, 180), y = clamp(r.y, -180, 180), z = clamp(r.z, -180, 180) },
    }
    dirty = true
    -- The shift moves every lane of the slot, so the reference moves with you. Without this
    -- you would watch a gap open that the game never opens: both weapons shift together.
    reattachReferenceLanes()
    cb({ ok = true })
end)

--- Persist the class offset. It goes through the CONFIG row, not the positions table: it is
--- global, not per-job and not per-gender — a weapon's length is the same whoever carries it.
RegisterNUICallback('propEdit:saveClassOffset', function(_, cb)
    if not editing or not editClass or editClass == 'standard' or not editClassOff then
        cb({ ok = false }); return
    end
    TriggerServerEvent('mbt_malisling:classOffset:save', {
        slot = baseType(editWtype), class = editClass, offset = editClassOff,
    })
    cb({ ok = true })
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
    -- Dropped, not saved: an unsaved drag must not survive into the next slot you open,
    -- where it would silently shift a weapon nobody moved.
    editClass, editClassOff, editWeapon = nil, nil, nil
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    destroyPreview()
    destroyReferenceLanes()
    restoreRealSlung()
    if MBT.SetSlingEditing then MBT.SetSlingEditing(false) end   -- strap respawns at the saved offset
    if MBT.SetSlingWeaponPreview then MBT.SetSlingWeaponPreview(nil) end
    FreezeEntityPosition(cache.ped, false)
end

--- Swap the weapon shown on the lane, without touching the position.
--- A slot holds up to 40 models of very different lengths and they share one tuned
--- position: tuning against whichever one the editor happened to pick is a bet that the
--- other 39 are the same size. This is how you check instead of hoping — try the extremes,
--- and if no single position holds them, that is what the length classes are for.
--- Deliberately NOT persisted: it is a way of looking, not a setting.
RegisterNUICallback('propEdit:previewWeapon', function(d, cb)
    local name = d and d.weapon
    if not editing or type(name) ~= 'string' or isObjectType(editWtype) then cb({ ok = false }) return end
    if not (MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]) then
        cb({ ok = false }) return
    end

    local hash = joaat(name)
    if not pcall(lib.requestWeaponAsset, hash, 5000, 31, 1) then cb({ ok = false }) return end

    local ped = cache.ped
    local pc = GetEntityCoords(ped)
    destroyPreview()
    previewObj = CreateWeaponObject(hash, 50, pc.x, pc.y, pc.z, true, 1.0, 0)
    RemoveWeaponAsset(hash)
    if not previewObj or not DoesEntityExist(previewObj) then cb({ ok = false }) return end
    SetEntityCompletelyDisableCollision(previewObj, false, true)

    -- The class follows the weapon, so the offset the sliders reach follows it too — that
    -- is the whole point: load the sniper, and the control in front of you is the one that
    -- moves snipers.
    editClass    = (MBT.WeaponLengthClass or {})[name] or 'standard'
    editClassOff = classOffsetOf(baseType(editWtype), editClass)

    -- The other lanes follow, so what you are looking at is a PAIR of this weapon. Two long
    -- rifles is the case that intersects; judging it against a carbine tells you nothing.
    editWeapon = name
    spawnReferenceLanes(editWtype, editJob, editGender, editWeapon)

    -- Re-apply the pose being edited, so only the weapon changed.
    applyPreview(editData, editGender)
    cb({ ok = true, class = editClass, offset = editClassOff })
end)

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
