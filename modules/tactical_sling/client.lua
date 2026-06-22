-- ─────────────────────────────────────────────────────────────────────────────
-- Tactical Sling Prop (visible strap)
--
-- Shows a visible sling/strap on the torso while a long gun is slung. Implemented
-- as a PROP attached to a bone (CreateObject + AttachEntityToEntity), NOT clothing
-- (clothing needs a per-server drawable index and conflicts with server addons).
-- The strap models (mbt_belt_prop_a / _b, declared in mbt_m4_prop.ytyp) ship in
-- this resource's stream/, so the feature is fully portable.
--
-- Local player only (other clients attach their own). On/off is live-toggleable
-- from the admin dashboard (MBT.TacticalSling.Enabled, applied by the config
-- module). The attach offset is editable from the NUI Positions editor (type
-- 'sling') and read from MBT.PropInfo.sling, per gender.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.TacticalSling then return end

local cfg = MBT.TacticalSling

local strapObj     = nil    -- the spawned strap prop entity (local player)
local slingEditing = false  -- true while the NUI Positions editor is tuning 'sling'
local weaponPreviewType = nil  -- weapon type previewed in the editor → show the strap as a reference

local function isFreemode(ped)
    local m = GetEntityModel(ped)
    return m == `mp_m_freemode_01` or m == `mp_f_freemode_01`
end

--- The local player's job (best-effort, for the per-job variant override).
local function localJob()
    return (PlayerData and PlayerData.job and PlayerData.job.name) or nil
end

--- Active variant id for the local player: per-job override else the configured default.
local function activeVariant()
    local job = localJob()
    if job and cfg.JobVariants and cfg.JobVariants[job] then return cfg.JobVariants[job] end
    return cfg.DefaultVariant or (cfg.Variants and cfg.Variants[1] and cfg.Variants[1].id)
end

--- Strap model name for a variant id (fallback to first variant / legacy fields).
local function modelForVariant(variantId)
    for _, v in ipairs(cfg.Variants or {}) do
        if v.id == variantId then return v.model end
    end
    if cfg.Variants and cfg.Variants[1] then return cfg.Variants[1].model end
    return (cfg.Models and cfg.Models[variantId]) or cfg.Model
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
    local variant   = activeVariant()
    local modelName = modelForVariant(variant)
    local model = joaat(modelName or '')
    if not IsModelValid(model) then
        Utils.mbtWarn('tactical_sling ~ invalid model: ' .. tostring(modelName))
        return
    end
    lib.requestModel(model, 2000)
    if not HasModelLoaded(model) then return end

    local obj = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 or not DoesEntityExist(obj) then return end

    -- Per-variant attach offset (NUI-editable + DB-persisted), fallback to the shared default.
    -- Force FLOATS: an integer rotation arg makes AttachEntityToEntity ignore the rotation
    -- (the NUI sliders send integers).
    local info = MBT.PropInfo and (MBT.PropInfo['sling:' .. tostring(variant)] or MBT.PropInfo.sling)
    local sex  = IsPedMale(ped) and 'male' or 'female'
    local pos  = info and info.Pos and info.Pos[sex]
    local rot  = info and info.Rot and info.Rot[sex]
    if not pos or not rot then removeStrap(); return end
    local bone = GetPedBoneIndex(ped, math.floor(tonumber(info.Bone) or 24816))
    AttachEntityToEntity(obj, ped, bone,
        pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, rot.x + 0.0, rot.y + 0.0, rot.z + 0.0,
        true, true, false, info.isPed == true, math.floor(tonumber(info.RotOrder) or 2), info.FixedRot ~= false)
    strapObj = obj
end

-- Single always-on loop so the dashboard on/off toggle (cfg.Enabled) and the editor
-- 'sling' hide both take effect LIVE, without a restart.
CreateThread(function()
    while true do
        Wait(750)
        local ped = cache.ped
        if cfg.Enabled and not slingEditing and ped and ped ~= 0 and isFreemode(ped) then
            -- Also show the strap while the weapon-position editor previews an eligible type,
            -- so the admin can align the weapon to the strap.
            local want = hasEligibleSlung() or (weaponPreviewType ~= nil and cfg.Types[weaponPreviewType] == true)
            if want and not (strapObj and DoesEntityExist(strapObj)) then
                spawnStrap(ped)
            elseif not want and strapObj then
                removeStrap()
            end
        elseif (not cfg.Enabled or slingEditing) and strapObj then
            removeStrap()   -- toggled off / editing → drop the strap immediately
        end
    end
end)

-- Re-spawn cleanly after ped/skin change.
lib.onCache('ped', removeStrap)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then removeStrap() end
end)

-- ── Editor hooks (NUI Positions editor, type 'sling') ────────────────────────
-- While editing, hide the real strap so it doesn't overlap the editor's preview prop;
-- on a saved/broadcast position change, drop it so the loop respawns at the new offset.
function MBT.SetSlingEditing(v)
    slingEditing = v and true or false
    if slingEditing then removeStrap() end
end
function MBT.RefreshSling()
    removeStrap()   -- the loop respawns it next tick with the current MBT.PropInfo.sling
end

-- Set while a WEAPON position editor is open (pass the weapon type, or nil to clear): the
-- loop then shows the strap if that type is eligible, as a placement reference.
function MBT.SetSlingWeaponPreview(wtype)
    weaponPreviewType = wtype
end
