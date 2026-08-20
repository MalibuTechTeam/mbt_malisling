-- ── Tactical Sling Prop (visible strap) ──
-- A PROP on a bone, not clothing (which needs a per-server drawable index and conflicts with
-- addons). Offset is NUI-editable as type 'sling', per gender.
--
-- Drawn for EVERY tracked player: a strap across the chest exists to be seen. Each client
-- spawns its own non-networked prop off the slung registry — no network entity, no new event.

if not MBT.TacticalSling then return end

local cfg = MBT.TacticalSling

local straps       = {}     -- [serverId] = strap prop entity (local, non-networked)
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

--- Active variant id for the WEARER, not for us — we draw other people's straps now, and the variant is a property of their job.
---@param serverId number
local function activeVariant(serverId)
    -- Jobs come from the server (the same set the core uses to decide what to hide); ours we
    -- can read locally and sooner.
    local jobs
    if serverId == cache.serverId then
        local j = localJob()
        if j then jobs = { [j] = true } end
    end
    if not jobs and GetPlayerJobsInScope then jobs = GetPlayerJobsInScope(serverId) end

    if jobs and cfg.JobVariants then
        local names = {}
        for job in pairs(jobs) do names[#names + 1] = job end
        -- Sorted before matching so every observer resolves the same variant for a player who
        -- holds several groups at once (ox_core).
        table.sort(names)
        for i = 1, #names do
            local v = cfg.JobVariants[names[i]]
            if v then return v end
        end
    end
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

--- Any eligible long gun currently slung on this player?
---@param serverId number
local function hasEligibleSlung(serverId)
    for propType, on in pairs(cfg.Types) do
        if on and Slung.first(propType, serverId) then
            return true
        end
    end
    return false
end

--- The ped for a tracked server id, or nil when they aren't streamed in.
local function pedFor(serverId)
    if serverId == cache.serverId then return cache.ped end
    local pid = GetPlayerFromServerId(serverId)
    if not pid or pid == -1 then return nil end   -- unstreamed: GetPlayerPed(-1) would give OUR ped
    local ped = GetPlayerPed(pid)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

local function removeStrap(serverId)
    local obj = straps[serverId]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    straps[serverId] = nil
end

local function removeAllStraps()
    for serverId in pairs(straps) do removeStrap(serverId) end
end

---@param serverId number  whose body the strap goes on
---@param ped number
local function spawnStrap(serverId, ped)
    if straps[serverId] and DoesEntityExist(straps[serverId]) then return end
    local variant   = activeVariant(serverId)
    local modelName = modelForVariant(variant)
    local model = joaat(modelName or '')
    if not IsModelValid(model) then
        Utils.mbtWarn('tactical_sling ~ invalid model: ' .. tostring(modelName))
        return
    end
    lib.requestModel(model, 2000)
    if not HasModelLoaded(model) then return end

    -- isNetwork = false: every client draws its own copy for everyone in scope, so a
    -- networked entity would just be N copies of the same strap fighting over ownership.
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
    if not pos or not rot then
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        return
    end
    local bone = GetPedBoneIndex(ped, math.floor(tonumber(info.Bone) or 24816))
    AttachEntityToEntity(obj, ped, bone,
        pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, rot.x + 0.0, rot.y + 0.0, rot.z + 0.0,
        true, true, false, info.isPed == true, math.floor(tonumber(info.RotOrder) or 2), info.FixedRot ~= false)
    -- Born matching the ped: on relog/multichar the ped is faded out while we spawn the strap.
    Utils.syncPropAlpha(obj, GetEntityAlpha(ped))
    straps[serverId] = obj
end

-- Single always-on loop so the dashboard on/off toggle (cfg.Enabled) and the editor
-- 'sling' hide both take effect LIVE, without a restart. It reconciles rather than
-- reacting: work out who should be wearing a strap right now, then add and remove the
-- difference. Players leaving scope, dropping a rifle or changing skin all resolve here,
-- with no event to subscribe to.
CreateThread(function()
    while true do
        Wait(750)

        if not cfg.Enabled then
            if next(straps) then removeAllStraps() end
            goto continue
        end

        local want = {}
        for serverId in pairs(playersToTrack) do
            if hasEligibleSlung(serverId) then want[serverId] = true end
        end
        -- Also show OUR strap while the weapon-position editor previews an eligible type,
        -- so the admin can align the weapon to the strap.
        if weaponPreviewType and cfg.Types[weaponPreviewType] == true then
            want[cache.serverId] = true
        end
        -- ...but never while the strap itself is being tuned: it would overlap the preview.
        if slingEditing then want[cache.serverId] = nil end

        for serverId in pairs(want) do
            local ped = pedFor(serverId)
            if ped and isFreemode(ped) then
                if straps[serverId] and DoesEntityExist(straps[serverId]) then
                    -- The ped's alpha doesn't reach attached props; follow it so the strap
                    -- fades with its wearer (multichar switch / relog) instead of floating alone.
                    Utils.syncPropAlpha(straps[serverId], GetEntityAlpha(ped))
                else
                    spawnStrap(serverId, ped)
                end
            else
                removeStrap(serverId)   -- unstreamed, gone, or not a freemode body
            end
        end

        for serverId in pairs(straps) do
            if not want[serverId] then removeStrap(serverId) end
        end

        ::continue::
    end
end)

-- Re-spawn cleanly after OUR ped/skin change (the loop puts it back next tick).
lib.onCache('ped', function() removeStrap(cache.serverId) end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then removeAllStraps() end
end)

-- ── Editor hooks (NUI Positions editor, type 'sling') ────────────────────────
-- While editing, hide the real strap so it doesn't overlap the editor's preview prop;
-- on a saved/broadcast position change, drop it so the loop respawns at the new offset.
function MBT.SetSlingEditing(v)
    slingEditing = v and true or false
    if slingEditing then removeStrap(cache.serverId) end
end
function MBT.RefreshSling()
    -- EVERY strap: the offset is server-wide config, so a change moves other people's
    -- straps too. The loop respawns them next tick from the current MBT.PropInfo.sling.
    removeAllStraps()
end

-- Set while a WEAPON position editor is open (pass the weapon type, or nil to clear): the
-- loop then shows the strap if that type is eligible, as a placement reference.
function MBT.SetSlingWeaponPreview(wtype)
    weaponPreviewType = wtype
end
