-- Draw Style gesture picker — the game-side half of web/src/admin/GestureOverlay.tsx.
-- Auditioning is local and writes nothing; only an explicit save reaches the server.

local playing = false
local cam                       -- scripted orbit camera, alive only while the picker is open
local orbit = { yaw = 150.0 }   -- degrees around the ped, RELATIVE to the way it is facing

--- Frame the ped from `orbit.yaw` degrees around it. Yaw is relative to the ped's HEADING, so
--- 0 is always its front whichever way the player happens to be standing.
local CAM_PITCH, CAM_DIST = -8.0, 2.2
local function updateCam()
    if not cam then return end
    local ped = cache.ped
    local c = GetEntityCoords(ped)
    local yawR = math.rad(GetEntityHeading(ped) + orbit.yaw)
    local pitchR = math.rad(CAM_PITCH)
    SetCamCoord(cam,
        c.x + CAM_DIST * math.cos(pitchR) * math.sin(yawR),
        c.y + CAM_DIST * math.cos(pitchR) * math.cos(yawR),
        c.z + 0.35 + CAM_DIST * math.sin(pitchR))
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.15, true)
end

--- Length of a clip, and whether it can be played at all. Own deadline rather than
--- lib.requestAnimDict: a dict absent on this build would hang there silently.
---@param dict string
---@param clip string
---@param release boolean?  free the dict again if this call loaded it. /mbt_animaudit only —
---  the play path must not, see MBT.DrawStyles in default.lua.
---@return number? seconds, string? err
local function measure(dict, clip, release)
    if type(dict) ~= 'string' or dict == '' or type(clip) ~= 'string' or clip == '' then
        return nil, 'empty dict or clip'
    end
    -- Before the request, so `release` frees only what this call caused to load.
    local wasLoaded = HasAnimDictLoaded(dict)
    local t0 = GetGameTimer()
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) and GetGameTimer() - t0 < 2000 do Wait(0) end
    if not HasAnimDictLoaded(dict) then
        return nil, ('dict "%s" never loaded — it probably does not exist on this build'):format(dict)
    end
    -- The only way to ask whether a CLIP exists: a missing one measures 0. Without it a
    -- misspelt name in a dict that DOES exist plays nothing and reports success.
    local dur = GetAnimDuration(dict, clip)
    if release and not wasLoaded then RemoveAnimDict(dict) end
    if not dur or dur <= 0.0 then
        return nil, ('clip "%s" is not in %s'):format(clip, dict)
    end
    return dur
end

--- Play one gesture on the local ped, once. Returns the clip's natural length: a duration
--- shorter than that is what "the animation looks cut" actually is.
---@param dict string
---@param clip string
---@param ms number?
---@return boolean ok, string? err, number? clipMs
local function playGesture(dict, clip, ms)
    if playing then return false, 'already playing' end
    local dur, err = measure(dict, clip)
    if not dur then return false, err end

    playing = true
    -- Flag 48 and the blend values match the qb draw path, so this shows what a player gets.
    TaskPlayAnim(cache.ped, dict, clip, 2.5, -4.0, ms or 1200, 48, 0.0, false, false, false)
    CreateThread(function()
        Wait((ms or 1200) + 100)
        playing = false
    end)
    return true, nil, math.floor(dur * 1000 + 0.5)
end

RegisterNUICallback('drawStyle:play', function(d, cb)
    local ok, err, clipMs = playGesture(d and d.dict, d and d.clip, tonumber(d and d.ms))
    if not ok and err then Utils.mbtWarn('gesture ~ ' .. err) end
    cb({ ok = ok, err = err, clipMs = clipMs })
end)

--- Measure the whole catalogue against THIS game build, without playing anything.
---
--- This is the tedious half of testing a gesture list, and it is the half a machine can do:
--- which dicts exist here, which clip names are real, and how long each one runs — that last
--- number being the duration the slot needs if the gesture is not to be cut off. What no
--- command can answer is whether the gesture reads well, so it does not pretend to.
if MBT.Debug then
    RegisterCommand('mbt_animaudit', function()
        local list = MBT.DrawStyleCandidates or {}
        print(('[SLING] animaudit ~ %d candidates against build %s'):format(#list, GetGameBuildNumber()))
        local bad = 0
        -- Floored before %d sees it: GetAnimDuration returns fractional seconds and Lua 5.4
        -- refuses to format a float with no exact integer value.
        local ms = function(seconds) return ('%dms'):format(math.floor(seconds * 1000 + 0.5)) end
        for i = 1, #list do
            local c = list[i]
            local inDur,  inErr  = measure(c.dict, c.animIn, true)
            local outDur, outErr = measure(c.dictOut or c.dict, c.animOut, true)
            if not inDur or not outDur then bad = bad + 1 end
            print(('[SLING]  %-22s draw %-28s stow %s'):format(
                c.id,
                inDur  and ms(inDur)  or ('FAIL - ' .. (inErr  or '?')),
                outDur and ms(outDur) or ('FAIL - ' .. (outErr or '?'))))
        end
        -- Reports what was found, not what it means: an entry can fail here and still be right
        -- on a server with the DLC that ships it.
        print(('[SLING] animaudit ~ %d of %d entries have both directions playable here')
            :format(#list - bad, #list))

        -- The slots as CONFIGURED, which the candidate list cannot answer. Resolved through the
        -- same function the draw uses, so this is what a player gets.
        print('[SLING] animaudit ~ configured slots (clip length vs the time it is given):')
        local slots = {}
        for slot in pairs(MBT.PropInfo or {}) do slots[#slots + 1] = slot end
        table.sort(slots)
        for i = 1, #slots do
            local slot = slots[i]
            local ha = Utils.holsterAnim(slot)
            if ha then
                local report = function(dict, clip, given)
                    -- No special case for the clip named '0': combat@combat_reactions@* names
                    -- clips after the ANGLE of the threat, so '0' is a real gesture.
                    if not clip or clip == '' then return 'no clip' end
                    local dur, err = measure(dict, clip, true)
                    if not dur then return 'FAIL - ' .. (err or '?') end
                    local clipMs = math.floor(dur * 1000 + 0.5)
                    return ('%dms clip / %dms given%s'):format(
                        clipMs, given or 0,
                        (given and clipMs > given + 50) and (' <-- CUT at %d%%'):format(
                            math.floor(given / clipMs * 100 + 0.5)) or '')
                end
                print(('[SLING]  %-14s draw %-34s stow %s'):format(slot,
                    report(ha.dict, ha.animIn, ha.sleep),
                    report(ha.dictOut or ha.dict, ha.animOut, ha.sleepOut)))
            end
        end
    end, false)
end

--- Enter gesture mode, and report what each slot is ACTUALLY using right now.
---
--- The resolved gesture is computed here rather than in the panel because two of its three
--- layers never reach the NUI: PropInfo and MBT.DrawStyles are code, and only the owner's
--- overrides are in the config snapshot. A panel left to guess would show "shipped default"
--- next to a slot the style overrides, which is the one thing an editor must not get wrong.
RegisterNUICallback('drawStyle:enter', function(d, cb)
    -- Empty hands: these are all reach-for-a-weapon gestures, and played with one already
    -- held they read as a fumble.
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)

    if not cam then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        updateCam()
        RenderScriptCams(true, false, 0, true, true)
    end

    local style = type(d) == 'table' and d.style or nil
    local slots, current = {}, {}
    for slot in pairs(MBT.PropInfo or {}) do
        local ha = Utils.holsterAnim(slot, style)
        if ha then
            slots[#slots + 1] = slot
            current[slot] = {
                dict = ha.dict, dictOut = ha.dictOut, animIn = ha.animIn, animOut = ha.animOut,
                -- So the audition runs at the length the slot really blocks for.
                sleep = ha.sleep, sleepOut = ha.sleepOut,
            }
        end
    end
    table.sort(slots)
    cb({ ok = true, slots = slots, current = current, yaw = orbit.yaw })
end)

--- Measure both directions without playing, so "Use" can save the clip and its duration as one
--- decision. Stores nothing: the panel sends these back with the save.
RegisterNUICallback('drawStyle:measure', function(d, cb)
    if type(d) ~= 'table' then return cb({}) end
    local inDur  = measure(d.dict, d.animIn)
    local outDur = measure(d.dictOut or d.dict, d.animOut)
    cb({
        sleep    = inDur  and math.floor(inDur  * 1000 + 0.5) or nil,
        sleepOut = outDur and math.floor(outDur * 1000 + 0.5) or nil,
    })
end)

RegisterNUICallback('drawStyle:cam', function(d, cb)
    orbit.yaw = tonumber(d and d.yaw) or orbit.yaw
    updateCam()
    cb({ ok = true })
end)

--- Leave gesture mode. Called on EVERY unmount path in the overlay, not just the button.
RegisterNUICallback('drawStyle:exit', function(_, cb)
    ClearPedTasks(cache.ped)
    playing = false
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    cb({ ok = true })
end)

-- A restart with the picker open would leave the player on a scripted camera with nothing
-- left running to take it down.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
end)

--- Save one gesture onto one slot of one style. The reply carries the stored map back, which
--- the panel patches into its draft — the dashboard round-trips the WHOLE config, so without
--- that the next ordinary Save would undo this.
---
--- The payload is rebuilt field by field, and that cost has been paid once: `timing` was added
--- at both ends and not here, so the duration was dropped in transit and nothing reported it.
--- Anything added to the save must be added HERE too.
RegisterNUICallback('drawStyle:save', function(d, cb)
    if type(d) ~= 'table' or type(d.style) ~= 'string' or type(d.slot) ~= 'string' then
        return cb({ ok = false, err = 'bad payload' })
    end
    local reply = lib.callback.await('mbt_malisling:drawStyle:save', false, {
        style   = d.style,
        slot    = d.slot,
        -- `false` clears, a table sets, absent leaves alone — all three must survive the trip,
        -- which is why these are passed through as they are and not defaulted to anything.
        gesture = d.gesture,
        timing  = d.timing,
    })
    cb(reply or { ok = false, err = 'no reply' })
end)
