local GetEntityCoords = GetEntityCoords
local Wait = Wait
local GetResourceState = GetResourceState
local GetCurrentResourceName = GetCurrentResourceName
local NetworkIsPlayerActive = NetworkIsPlayerActive
local DeleteObject = DeleteObject
local GetPedBoneIndex = GetPedBoneIndex
local AttachEntityToEntity = AttachEntityToEntity
local type = type
local next = next
local DoesEntityExist = DoesEntityExist
local DeleteEntity = DeleteEntity
local TriggerServerEvent = TriggerServerEvent
local joaat = joaat
local RequestWeaponHighDetailModel = RequestWeaponHighDetailModel
local TriggerEvent = TriggerEvent
local GiveWeaponComponentToWeaponObject = GiveWeaponComponentToWeaponObject
local GetWeaponComponentTypeModel = GetWeaponComponentTypeModel
local DoesWeaponTakeWeaponComponent = DoesWeaponTakeWeaponComponent
local GetPlayerFromServerId = GetPlayerFromServerId
local CreateWeaponObject = CreateWeaponObject
local SetEntityCompletelyDisableCollision = SetEntityCompletelyDisableCollision
local SetFlashLightKeepOnWhileMoving = SetFlashLightKeepOnWhileMoving

-- Inventory is provided by modules/inventory/*/client.lua (ox or qb bridge)
-- The slung-prop registry (playersToTrack) and every operation on it live in
-- modules/slung/client.lua, global `Slung`. Nothing here indexes it by hand.
local isReady = false
local hasRegistered = false
local propInfoTable = Utils.tableDeepCopy(MBT.PropInfo)

-- Last polled value of IsFlashLightOn(ped). We can't trust a synchronous read in the
-- ox_inventory:currentWeapon(nil) unequip handler because GTA's holster transition clears
-- the held-weapon flashlight before the event fires — the sync read returns 0 even when
-- the player visibly had it on. A 150ms-cadence tracker captures the state shortly before
-- the transition begins, which is what we want to persist to the slung prop's metadata.
local lastFlashlightState = false

equippedWeapon = {}

--- Reset client state on character logout (multicharacter support)
function ResetForMultichar()
    isReady = false
    equippedWeapon = {}
    if playersToTrack[cache.serverId] then Slung.resetPlayer(cache.serverId) end
end

--- Delete all attached weapons and sync with server.
--- ONE event for the lot, not one per type: syncDeletion is throttled at 100ms per source
--- (core/server.lua), so a loop of seven lands the first and drops the rest — and every
--- other player keeps rendering props that are already gone here. Same reason jobChanged
--- broadcasts a single "all" instead of a burst of per-type deletes.
function deleteAllWeapons()
    if not playersToTrack[cache.serverId] then return end
    if Slung.deleteAll(cache.serverId) > 0 then
        TriggerServerEvent("mbt_malisling:syncDeletionAll")
    end
end

--- True when the weapon stays visible inside this vehicle (roofless: bikes, quads, buggies, convertibles); enclosed vehicles return false so the prop can't clip through the roof.
---@param veh number
---@return boolean
local function isOpenVehicle(veh)
    local cfg = MBT.VehicleHiding
    if not cfg or not cfg.Enabled then return false end  -- legacy: hide everywhere
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    if cfg.KeepVisibleClasses and cfg.KeepVisibleClasses[GetVehicleClass(veh)] then
        return true
    end
    if cfg.UseRoofCheck and not DoesVehicleHaveRoof(veh) then
        return true
    end
    return false
end

-- Tracks whether we hid/deleted the props for the current vehicle, so we only
-- re-sync on exit when we actually hid something (no redundant re-spawn — and no
-- duplicate props — after riding an open vehicle where we left them visible).
local hiddenForVehicle = false

--- On vehicle enter, remove weapon objects (props clip/break otherwise); on exit, re-sync if we hid anything.
---@param value number|boolean  vehicle entity when entering, false when exiting
local function onVehicleCheck(value)
    if value then
        -- Open (roofless) vehicle: leave the slung weapon visible, do nothing.
        if isOpenVehicle(value) then
            hiddenForVehicle = false
            return
        end
        deleteAllWeapons()
        -- Called twice on purpose (Gianmarco, field debug): the second pass catches a prop
        -- that finished spawning between the two, which would otherwise ride inside the car.
        -- The SetEntityVisible loop that used to sit between them is gone: it ran after the
        -- slots had already been cleared, so it only ever passed booleans to the natives.
        deleteAllWeapons()
        hiddenForVehicle = true
    else
        if hiddenForVehicle then
            hiddenForVehicle = false
            TriggerServerEvent("mbt_malisling:checkInventory")
        end
    end
end

--- On ped change, remove weapon objects then re-check inventory: stale attachments on the old ped clip/break otherwise.
local function onPedChange()
    deleteAllWeapons()
    deleteAllWeapons()   -- second pass: see onVehicleCheck
    Citizen.Wait(250)
    TriggerServerEvent("mbt_malisling:checkInventory")
end

---@param data table
local function syncSling(data)
    TriggerServerEvent("mbt_malisling:syncSling", data)
end

--- Every weapon that should be hanging on the LOCAL player right now: [type][serial] = item.
---
--- ONE builder. Five call sites used to assemble this map their own way — the unequip
--- branch, itemCount, updateInventory, the server's checkWeaponProps and the ESX path —
--- each keeping a single weapon per type under slightly different rules, which is how they
--- drifted apart. It is also a SNAPSHOT, not a delta: the server replaces the player's
--- registry with whatever this returns, so a weapon that left the inventory disappears
--- because it stops being reported, with no deletion event to lose.
---
--- desired = what the inventory holds − what is in hand.
--- Concealment is deliberately NOT subtracted: it is a render-time decision every observer
--- makes about every player (isPropSuppressed), and folding it in here would hide the
--- weapon from the server as well — including from the observers who should still see it.
---@param items table?  item list to read (server-sent); nil = search the local inventory
---@return table<string, table<string, table>>
local function buildDesired(items)
    local out = {}
    if not MBT.WeaponsInfo or not MBT.WeaponsInfo.Weapons then return out end

    if not items then
        local names = {}
        for name in pairs(MBT.WeaponsInfo.Weapons) do names[#names + 1] = name end
        local found = Inventory:Search('slots', names)
        items = {}
        if type(found) == 'table' then
            -- Search returns a flat list for one name and [name] = {items} for several.
            for _, v in pairs(found) do
                if type(v) == 'table' then
                    if v.name then
                        items[#items + 1] = v
                    else
                        for _, item in pairs(v) do
                            if type(item) == 'table' and item.name then items[#items + 1] = item end
                        end
                    end
                end
            end
        end
    end

    local _, heldHash = GetCurrentPedWeapon(cache.ped, 1)
    local armed = heldHash and heldHash ~= `WEAPON_UNARMED`
    local heldSlot = equippedWeapon and equippedWeapon.slot

    for _, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string' and Utils.isWeapon(item.name) then
            local info = MBT.WeaponsInfo.Weapons[item.name]
            local propType = info and info.type

            -- The weapon in hand is not slung. Excluded by SLOT when we know which one it
            -- is — with two copies of the same gun the name can't tell them apart, and
            -- excluding by name would take both off the body.
            local drawn = false
            if armed then
                if heldSlot then drawn = (item.slot == heldSlot)
                else drawn = (joaat(item.name) == heldHash) end
            end

            if propType and MBT.PropInfo[propType] and (item.count or 1) > 0 and not drawn then
                item.type = propType
                out[propType] = out[propType] or {}
                out[propType][Slung.serialKey(item)] = item
            end
        end
    end

    return out
end

---Apply attachments on weapon object.
---@param data table
---@return boolean appliedFlashlight  true only if a flashlight component was actually given to the object
local function applyAttachments(data)
    local appliedFlashlight = false
    if data and not Utils.isTableEmpty(data) then
        Utils.mbtDebugger(data.metadata)
        local components = data.metadata.components
        if components then
            for i = 1, #components do
                local componentName = components[i]

                if not MBT.EnableFlashlight and Utils.isComponentAFlashlight(componentName) then goto continue; end

                Utils.mbtDebugger("applyAttachments ~ Applying component: ", componentName)
                local compsTable = MBT.WeaponsInfo.Components[componentName]["client"]["component"]

                for v=1, #compsTable do
                    local component = compsTable[v]
                    if DoesWeaponTakeWeaponComponent(data.weaponHash, component) then
                        Utils.mbtDebugger("applyAttachments ~ Component check passed!")
                        local compModel = GetWeaponComponentTypeModel(component)
                        Utils.mbtDebugger("applyAttachments ~ Component model: ", compModel)
                        lib.requestModel(compModel)
                        GiveWeaponComponentToWeaponObject(data.weaponObj, component)
                        SetModelAsNoLongerNeeded(compModel)
                        -- Track whether this object really accepted a flashlight: the slung
                        -- prop's light source must only be enabled for weapons that actually
                        -- have one, otherwise stale flashlightState glows the wrong prop.
                        if Utils.isComponentAFlashlight(componentName) then appliedFlashlight = true end
                    end
                end

                ::continue::

            end
        end
    end
    return appliedFlashlight
end

---Scope "shadow zone": server marks the player in-scope before the client ped truly exists.
---Wait until the player resolves (return true) or leaves our scope (return false).
---@param data table
---@return boolean
local function waitingForTargetPlayerPed(data)

    while true do
        Utils.mbtDebugger("waitingForTargetPlayerPed ~ Waiting for player ", data.playerSource)
        if (GetPlayerFromServerId(data.playerSource) and GetPlayerFromServerId(data.playerSource) ~= -1) then
            Utils.mbtDebugger("Player with id "..data.playerSource.." exist!")
            return true
        end

        if not playersToTrack[data.playerSource] or not Slung.isWaiting(data.playerSource) then
            Utils.mbtDebugger("waitingForTargetPlayerPed ~ Player with id "..data.playerSource.." doesn't exist!")
            return false
        end

        Wait(200)
    end
end

local function overwriteValues(newTable)

    for key, value in pairs(newTable) do
        if propInfoTable[key] ~= nil then
            propInfoTable[key]["Pos"] = Utils.tableDeepCopy(value["Pos"])
            propInfoTable[key]["Rot"] = Utils.tableDeepCopy(value["Rot"])
        end
    end
end

local function getAttachInfo(data)
    if MBT.CustomPropPosition[data.Job] and MBT.CustomPropPosition[data.Job][data.Type] then
        return MBT.CustomPropPosition[data.Job][data.Type]
    end
    return MBT.PropInfo[data.Type]
end

-- Jobs of every player in scope, as the server resolved them. Kept apart from
-- playersToTrack because that map holds prop handles and gets wiped on scope churn,
-- while the job answer stays true for as long as the player is around.
local playerJobsInScope = {}   -- [serverId] = { police = true, ... }

-- Last job/sex the server resolved for each player, kept so the repair tick can re-spawn a
-- prop without a fresh payload to read them from. Same lifetime as playerJobsInScope.
local playerCtxInScope = {}    -- [serverId] = { playerJob = string?, pedSex = string }

--- Should this player's prop for this type exist at all?
--- ONE predicate, not a chain of conditions at the call site: the 2.1 rewrite subtracts
--- suppressed props from a desired set, and it wants a single term to subtract. Add new
--- reasons here rather than next to the spawn.
---@param source number   server id of the player carrying the weapon
---@param propType string body slot: side/back/back2/melee/melee2/melee3
---@param serial string?  the weapon itself, where a reason is per-weapon rather than per-slot
---@return boolean suppressed, string? reason  reason is for /mbt_slingdebug; callers ignore it
local function isPropSuppressed(source, propType, serial)
    -- Concealed carry (opaque hook, no-op without the module). Per WEAPON: hiding every
    -- pistol because one of them is tucked away would make concealment the one action that
    -- can't name what it acts on.
    if serial and MBT.IsSerialConcealed and MBT.IsSerialConcealed(source, serial) then
        return true, 'concealed'
    end

    local hidden = MBT.HiddenByJob
    if not hidden then return false end

    -- '*' hides the type for everyone, job or no job. Asked for three times on the v1
    -- thread by people who wanted pistols to draw normally and never hang on the hip —
    -- without it they would have to list every job on the server to say "never".
    -- Checked before the job lookup so it also covers players the framework gives no job.
    local always = hidden['*']
    if always and always[propType] then return true, "hidden for '*'" end

    -- Hidden for this player's job: their uniform already draws the weapon.
    local jobs = playerJobsInScope[source]
    if not jobs then return false end
    for job in pairs(jobs) do
        local byType = hidden[job]
        if byType and byType[propType] then return true, 'hidden for job ' .. job end
    end
    return false
end

-- ── Debug: why is (or isn't) my weapon on my body? (Debug builds only) ───────────
-- Not a way to fake a job change — for that, use your framework's own command, or you
-- are testing the fake. This answers the question that comes after: what did the
-- predicate actually decide, and on what grounds. Worth having in support, where the
-- report is "the pistol still shows" and the cause is a job name spelled differently in
-- config than the framework returns.
if MBT.Debug then
    RegisterCommand('mbt_slingdebug', function()
        local me   = cache.serverId
        local jobs = {}
        for j in pairs(playerJobsInScope[me] or {}) do jobs[#jobs + 1] = j end
        table.sort(jobs)
        local jobList = #jobs > 0 and table.concat(jobs, ', ') or 'none'

        Utils.mbtDebugger(('sling debug ~ jobs as the server resolved them: %s'):format(jobList))

        -- Body slots only, taken from what the weapon table actually maps to. Iterating
        -- MBT.PropInfo directly would also list the 'sling:<variant>' entries, which are
        -- tactical-sling strap offsets (default.lua) and can never hold a weapon.
        local slots = {}
        for _, w in pairs((MBT.WeaponsInfo or {}).Weapons or {}) do
            if w.type and MBT.PropInfo[w.type] then slots[w.type] = true end
        end

        for propType in pairs(slots) do
            -- No serial here: this line answers the per-SLOT reasons (hidden for a job).
            -- Per-weapon concealment shows up on the entry lines below, as a missing prop.
            local suppressed, why = isPropSuppressed(me, propType)
            Utils.mbtDebugger(('  %-12s suppressed=%-6s%s'):format(
                propType, tostring(suppressed), why and ('(' .. why .. ')') or ''))
            -- Every entry, whatever its state: a slot that looks empty but holds a stale
            -- reservation is exactly the case worth seeing here.
            Slung.forEachType(me, propType, function(handle, _, serial, e)
                Utils.mbtDebugger(('      %-9s lane=%-4s prop=%-8s %s%s'):format(
                    e.state, tostring(e.lane), tostring(handle), serial,
                    e.why and ('  (' .. e.why .. ')') or ''))
            end, { states = 'all', stale = true })
        end

        -- Everyone ELSE we are tracking. "I see him but he doesn't see me" is answered
        -- here: either the other player is missing from this list, or he is in it with no
        -- entries, and those two have completely different causes.
        local others = {}
        for serverId in pairs(playersToTrack) do
            if serverId ~= me then others[#others + 1] = serverId end
        end
        table.sort(others)
        Utils.mbtDebugger(('sling debug ~ other players tracked here: %s'):format(
            #others > 0 and table.concat(others, ', ') or 'NONE'))
        for i = 1, #others do
            local id, n = others[i], 0
            Slung.forEach(id, function(handle, propType, serial, e)
                n = n + 1
                Utils.mbtDebugger(('  [%s] %-12s %-9s lane=%-4s prop=%-8s %s'):format(
                    id, propType, e.state, tostring(e.lane), tostring(handle), serial))
            end, { states = 'all', stale = true })
            if n == 0 then Utils.mbtDebugger(('  [%s] no entries'):format(id)) end
        end

        -- The server's own view. A client can only prove what it RECEIVED; when two players
        -- disagree, the truth is in the registry and the scope lists.
        local snap = lib.callback.await('mbt_malisling:debugSnapshot', false)
        if type(snap) == 'table' then
            Utils.mbtDebugger('sling debug ~ SERVER registry:')
            for playerId, types in pairs(snap.registry or {}) do
                local any = false
                for propType, serials in pairs(types) do
                    any = true
                    Utils.mbtDebugger(('  [%s] %-12s %s'):format(playerId, propType, table.concat(serials, ', ')))
                end
                if not any then Utils.mbtDebugger(('  [%s] registered, no weapons'):format(playerId)) end
            end
            Utils.mbtDebugger(('sling debug ~ SERVER my sync reaches: %s'):format(
                #(snap.myScope or {}) > 0 and table.concat(snap.myScope, ', ') or 'NOBODY'))
            Utils.mbtDebugger(('sling debug ~ SERVER I receive from:  %s'):format(
                #(snap.inScopeOf or {}) > 0 and table.concat(snap.inScopeOf, ', ') or 'NOBODY'))
        end

        lib.notify({ type = 'inform', title = 'Sling debug',
            description = ('jobs: %s — full breakdown in F8'):format(jobList) })
    end, false)
end

--- Jobs the SERVER resolved for a player in scope, as a set (nil if we know none).
--- Global because a module that draws something on another player's body needs the jobs of
--- the person wearing it, not ours — the tactical sling picks its strap variant that way.
---@param serverId number
---@return table<string, boolean>?
function GetPlayerJobsInScope(serverId)
    return playerJobsInScope[serverId]
end

--- Resolved back/sling attach info for a prop type, job overrides applied; global so sibling modules (e.g. low_ready) can re-attach a slung prop without duplicating the job lookup.
---@param propType string
---@return table?
function GetResolvedPropInfo(propType)
    return propInfoTable[propType]
end

--- The slung-prop entity tracked for the local player at this type, or nil.
--- Compat surface: a caller that HOLDS a serial must use Slung.get/Slung.resolve instead —
--- the serial is the identity, and "the first one" is not a thing to target.
---@param propType string
---@return number?
function GetLocalSlungProp(propType)
    return (Slung.first(propType))
end

--- Tell the server our job changed, so every observer re-decides what to draw on us:
--- the job selects both whether a prop exists (MBT.HiddenByJob) and where it sits
--- (MBT.CustomPropPosition).
--- Called by the framework bridges, and only by them. Deliberately NOT folded into
--- sendAnimations, even though all four bridges call that too: sendAnimations also runs
--- at Init and on every live position broadcast from the editor, and a delete-and-resync
--- on those paths would mean a storm of them while someone drags a slider.
function NotifyJobChanged()
    TriggerServerEvent('mbt_malisling:jobChanged')
end

function sendAnimations(jobName)
    -- ox_core uses PlayerData.groups instead of a single job name
    if PlayerData and PlayerData.groups then
        local playerGroups = {}
        for k in pairs(PlayerData.groups) do
            playerGroups[#playerGroups+1] = k
        end
        if #playerGroups == 0 then
            Utils.mbtDebugger("No groups found, setting default!")
            propInfoTable = Utils.tableDeepCopy(MBT.PropInfo)
        else
            for i = 1, #playerGroups do
                local gName = playerGroups[i]
                if MBT.CustomPropPosition[gName] then
                    Utils.mbtDebugger("Custom prop position for group "..gName.." found!")
                    overwriteValues(MBT.CustomPropPosition[gName])
                else
                    Utils.mbtDebugger("No group position customization found, setting default!")
                    propInfoTable = Utils.tableDeepCopy(MBT.PropInfo)
                end
            end
        end
    elseif jobName and MBT.CustomPropPosition[jobName] then
        Utils.mbtDebugger("Custom prop position for job "..jobName.." found!")
        overwriteValues(MBT.CustomPropPosition[jobName])
    else
        propInfoTable = Utils.tableDeepCopy(MBT.PropInfo)
    end

    TriggerEvent("mbt_malisling:sendAnim", {
        WeaponData = MBT.WeaponsInfo,
        HolsterData = propInfoTable
    })
end

--- Re-report the local player's full desired set to the server.
--- Global so sibling modules can ask for a re-sync without assembling a payload of their
--- own: the payload is a SNAPSHOT that replaces the registry, so a partial one built by
--- hand would wipe everything it forgot to mention.
function ResyncSling()
    syncSling({ playerWeapons = buildDesired() })
end

-- Coalesced re-read, asked of the SERVER.
-- Two problems, one answer. Reading ox's client cache right after an inventory change can
-- still see the item that just left — that is why a dropped weapon stayed on the body and
-- in the concealment list. And ox_inventory:updateInventory fires in bursts, so a re-read
-- per event meant a 130-name Inventory:Search per event, each in its own coroutine: a cost
-- that did not exist before the snapshot rewrite, and the kind that stalls a client under
-- load. checkInventory reads the inventory SERVER-side, where it is authoritative, and the
-- flag collapses a burst into one round trip.
local resyncPending = false

---@param delay number?  ms to let the inventory settle first
local function scheduleResync(delay)
    if resyncPending then return end
    resyncPending = true
    CreateThread(function()
        Wait(delay or 150)
        resyncPending = false
        TriggerServerEvent("mbt_malisling:checkInventory")
    end)
end

function Init()
    isReady = false
    equippedWeapon = {}

    -- A restart wipes equippedWeapon, but a weapon already in the player's hands stays
    -- there — and ox only fires currentWeapon on a CHANGE, so nothing re-announces it.
    -- The holster branch would then hit the "no weapon was equipped" guard and skip the
    -- re-sling entirely: the gun goes away and never reappears on the back. Seed from the
    -- live inventory state instead. qb has no such export (its bridge polls and re-fires
    -- currentWeapon by itself), so the pcall simply no-ops there.
    local ok, held = pcall(function() return exports.ox_inventory:getCurrentWeapon() end)
    if ok and type(held) == 'table' and held.name then
        local md = held.metadata or {}
        equippedWeapon.name       = held.name
        equippedWeapon.slot       = held.slot
        equippedWeapon.components = md.components
        equippedWeapon.serial     = md.serial
    end

    MBT.WeaponsInfo = lib.callback.await('mbt_malisling:getWeapoConf', false)
    Utils.mbtDebugger("Init ~ has been fired!!!")

    -- Load DB-persisted prop-position overrides into MBT.PropInfo/CustomPropPosition BEFORE
    -- the first sendAnimations rebuild, so saved editor positions survive a resource restart.
    if MBT.SyncSavedPropPositions then MBT.SyncSavedPropPositions() end

    local tempPlayers = GetActivePlayers()
    local activePlayers = {}

    for i=1, #tempPlayers do
        local activePlayerID = GetPlayerServerId(tempPlayers[i])
        if activePlayerID ~= cache.serverId then
            activePlayers[#activePlayers+1] =  activePlayerID
        end
    end

    TriggerServerEvent("mbt_malisling:getPlayersInPlayerScope", activePlayers)

    sendAnimations(PlayerData.job and PlayerData.job.name or {})

    Citizen.Wait(200)

    Utils.mbtDebugger("Init ~  playersTrack clientside with my source that is "..cache.serverId)

    Slung.resetPlayer(cache.serverId)

    Utils.mbtDebugger("Init ~ playersToTrack filled with my id!!!")
    Wait(200)

    if hasRegistered then
        Wait(200)
        TriggerServerEvent("mbt_malisling:checkInventory")
        Utils.mbtDebugger("Init ~ Skipping handler registration (already registered)")
        isReady = true
        return
    end
    hasRegistered = true

    AddEventHandler('ox_inventory:currentWeapon', function(data)
        Utils.mbtDebugger("ox_inventory:currentWeapon ~ Fired!")

        if data then

            local weaponType = MBT.WeaponsInfo["Weapons"][data.name]?.type

            local weaponName = data.name

            Utils.mbtDebugger(data)

            Utils.mbtDebugger("ox_inventory:currentWeapon ~ You have equipped a "..data.name)

            if not playersToTrack[cache.serverId] then return end

            if Slung.first(weaponType) then
                Utils.mbtDebugger("ox_inventory:currentWeapon ~ Equip check passed!")
                TriggerEvent('mbt_malisling:onUnholster', weaponType)
                TriggerServerEvent("mbt_malisling:syncDeletion", weaponType)
                equippedWeapon["name"] = weaponName;
                equippedWeapon["slot"] = data.slot;
                equippedWeapon["components"] = data.metadata.components;
                equippedWeapon["serial"] = data.metadata.serial;
            end

            -- Scope the ped-global flashlight to the weapon now in hand: enable it only
            -- when THIS weapon actually has a flashlight component AND its saved state was
            -- on; otherwise explicitly clear it. SetFlashLightEnabled is ped-global, so
            -- without the else the previous weapon's torch carries over to the next weapon
            -- (and leaks into the saved state at unequip → wrong prop glows).
            local eqComponents = data.metadata and data.metadata.components
            local eqHasFlashlight = (eqComponents and Utils.containsValue(eqComponents, "at_flashlight")) and true or false
            if MBT.EnableFlashlight and eqHasFlashlight and data.metadata and data.metadata.flashlightState == true then
                SetFlashLightEnabled(cache.ped, true)
            else
                SetFlashLightEnabled(cache.ped, false)
            end
            -- NOTE: previously here lived a polling thread that ran `while IsPedArmed(ped, 7) do`,
            -- but `IsPedArmed` returns 0/1 (integer) and in Lua 0 is truthy, so the loop never
            -- exited — every equip leaked another thread, and the 250ms polling lag caused stale
            -- `true` values to be written into the saved metadata. We now read IsFlashLightOn
            -- synchronously inside the unequip branch instead.
        else
            if Utils.isTableEmpty(equippedWeapon) then return end

            local weaponName = equippedWeapon["name"]
            if not weaponName then return end
            local hasFlashlight = (equippedWeapon["components"] and Utils.containsValue(equippedWeapon["components"], "at_flashlight"))
                or Utils.weaponHasFlashlight(cache.ped, weaponName, MBT.WeaponsInfo.Components["at_flashlight"]["client"]["component"])
            local currentFlashlightState
            if hasFlashlight then
                -- Use the polled value, not a sync IsFlashLightOn read: by this point GTA
                -- has already cleared the held-weapon flashlight as part of the holster
                -- transition, so a sync read returns 0 even when the player had it on.
                currentFlashlightState = lastFlashlightState
                LocalPlayer.state:set('WeaponFlashlightState', {
                    [equippedWeapon.slot] = {Serial = equippedWeapon.serial, FlashlightState = currentFlashlightState}
                }, true)
            end

            Utils.mbtDebugger("ox_inventory:currentWeapon ~ You have unequipped a "..weaponName)

            local immediateType = MBT.WeaponsInfo["Weapons"][weaponName]?.type
            if immediateType then TriggerEvent('mbt_malisling:onHolster', immediateType) end

            Wait(250)

            -- Thrown or dropped: the weapon is on its way out of the inventory and the
            -- drop path drives its own sync. Re-slinging it here would put it back on the
            -- body for the moment it takes the removal to land.
            if equippedWeapon["dropped"] then equippedWeapon = {} return end

            local desired = buildDesired()

            -- ox_inventory's client-side metadata cache may not have received the server's
            -- state-bag-driven flashlightState update yet. Override the weapon we just
            -- holstered — found by SLOT, so a second copy of the same gun doesn't inherit
            -- a torch state that isn't its own.
            if currentFlashlightState ~= nil and equippedWeapon["slot"] then
                for _, bySerial in pairs(desired) do
                    for _, item in pairs(bySerial) do
                        if item.slot == equippedWeapon["slot"] then
                            item.metadata = item.metadata or {}
                            item.metadata.flashlightState = currentFlashlightState
                        end
                    end
                end
            end

            equippedWeapon = {}
            syncSling({ playerWeapons = desired })
        end
    end)

    AddEventHandler('ox_inventory:itemCount', function(itemName, left)
        Utils.mbtDebugger("ox_inventory:itemCount ~ Item "..itemName.." removed, remaining "..left)

        -- Any weapon leaving, not just the LAST one of its name. Counting was right when a
        -- slot held one weapon; per serial it is the wrong question — dropping one of two
        -- pistols leaves the count at 1 and used to do nothing at all.
        --
        -- And no per-type syncDeletion any more: it cleared the whole slot server-side, so
        -- with two pistols dropping one took the other's prop down with it until the next
        -- snapshot put it back. The re-read removes exactly the weapon that left.
        if Utils.isWeapon(itemName) then
            scheduleResync(500)
        end
    end)

    AddEventHandler("ox_inventory:updateInventory", function (data)
        Utils.mbtDebugger(data)
        if not playersToTrack[cache.serverId] then return end

        -- Only when a weapon MIGHT be involved: this fires for every inventory change, and
        -- a re-read per sandwich is a round trip per sandwich.
        --
        -- An emptied slot arrives as `false` — no name to test. Checking only for a weapon
        -- name filtered out exactly the case that matters most, REMOVAL, which is why a
        -- dropped weapon stayed on the body and in the concealment picker. A cleared slot
        -- is always worth a look; the coalescing makes an over-trigger cost one round trip.
        local worthReading = false
        for _, v in pairs(data) do
            if v == false or v == nil then
                worthReading = true
                break
            end
            if type(v) == "table" and type(v.name) == "string" and Utils.isWeapon(v.name) then
                worthReading = true
                break
            end
        end
        if not worthReading then return end

        Utils.mbtDebugger("ox_inventory:updateInventory ~ scheduling a re-read")
        -- No "is the slot busy" check any more. The set is what it is; the reconciliation
        -- on the receiving side works out what to spawn and what to remove. That guard was
        -- how a weapon added while another was already slung got silently ignored.
        scheduleResync()
    end)

    Wait(200)
    TriggerServerEvent("mbt_malisling:checkInventory")

    Utils.mbtDebugger("ox_inventory:updateInventory ~ Init END!!!")

    lib.onCache('vehicle', function(value) onVehicleCheck(value); end)
    lib.onCache('ped', onPedChange)

    isReady = true
end

--- Called by ESX bridge when esx:removeInventoryItem fires
function onEsxWeaponRemoved(itemName, left)
    Utils.mbtDebugger("esx:removeInventoryItem ~ Item "..itemName.." removed, remaining "..left)

    -- Same reasoning as the ox itemCount path: any weapon leaving, no per-type deletion.
    -- ESX items carry no slot and no metadata.serial, so every weapon of a type collapses
    -- onto the same fallback key and only one survives per type — exactly what ESX did
    -- before, and the floor multi-weapon can reach there until the ESX bridge grows
    -- per-slot identity.
    if Utils.isWeapon(itemName) then
        Wait(500)
        syncSling({ playerWeapons = buildDesired(ESX.GetPlayerData().inventory) })
    end
end

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		if NetworkIsPlayerActive(PlayerId()) then
            Init()
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    Slung.teardown()   -- deletes only OUR weapon objects; see the note on entity-handle recycling
end)

RegisterNetEvent("mbt_malisling:syncPlayerRemoval")
AddEventHandler("mbt_malisling:syncPlayerRemoval", function(data)
    if not data then return end
    if not data.playerSource then return end
    playerJobsInScope[data.playerSource] = nil
    playerCtxInScope[data.playerSource] = nil
    if not playersToTrack[data.playerSource] then return end
    Slung.clearPlayer(data.playerSource)
end)

RegisterNetEvent("mbt_malisling:syncDeletion")
AddEventHandler("mbt_malisling:syncDeletion", function(data)
    if not data or not data.weaponType then return end
    if type(data.weaponType) ~= "string" then return end

    local weaponType = data.weaponType
    local targetPlayerServerId = data.playerSource

    Utils.mbtDebugger("syncDeletion ~ Checking deletion client for id ", targetPlayerServerId)

    if not playersToTrack[targetPlayerServerId] then return end

    if weaponType == "all" then
        Slung.deleteAll(targetPlayerServerId)
    else
        Slung.deleteType(targetPlayerServerId, weaponType)
    end
end)

RegisterNetEvent("mbt_malisling:checkWeaponProps")
AddEventHandler("mbt_malisling:checkWeaponProps", function(t)
    if type(t) ~= "table" then return end
    Utils.mbtDebugger("checkWeaponProps ~ reporting the desired set from the server's item list")
    -- Reported even when EMPTY, unlike before: an empty set is a legitimate answer ("this
    -- player carries nothing"), and swallowing it left the last non-empty snapshot standing
    -- on the server after the player's guns were taken away.
    syncSling({ playerWeapons = buildDesired(t) })
end)

RegisterNetEvent('mbt_malisling:syncScope')
AddEventHandler('mbt_malisling:syncScope', function (data)
    local tType = data.tType and data.tType or "add"

    Utils.mbtDebugger("syncScope ~ Scope synced for source "..data.playerSource.." Type "..tType)


    if not playersToTrack[data.playerSource] then  playersToTrack[data.playerSource] = {} end
    if data.playerJobs then playerJobsInScope[data.playerSource] = data.playerJobs end
    if tType == "del" then

        Utils.mbtDebugger("syncScope ~ ", data.playerSource, " has exited from your scope!")

        -- Deletes every prop, then empties the buckets and stops any pending wait. The old
        -- path only deleted handles it could find in the spawn registry, so one that had
        -- drifted out of it stayed hanging in the world.
        Slung.resetPlayer(data.playerSource)

        return
    end

    Slung.setWaiting(data.playerSource, true)
    TriggerEvent('mbt_malisling:syncSling', data)
end)

RegisterNetEvent('mbt_malisling:stopWaitingForPlayer')
AddEventHandler('mbt_malisling:stopWaitingForPlayer', function (p)
    if not playersToTrack[p] then return end
    Slung.setWaiting(p, nil)
    Utils.mbtDebugger("stopWaitingForPlayer ~ Stopped waiting for player ", p)
end)

--- Build ONE slung prop and attach it to the ped. Returns the entity, or nil when it could
--- not be made (asset streaming, create timeout) so the caller can free its reservation.
--- Lifted out of the syncSling loop because phase 4 installs exactly this as Slung.spawner:
--- promotion needs to build a prop for one serial without a sync payload around it.
---@param ctx table { playerSource, playerPed, playerCoords, playerJob, pedSex, targetPlayerId }
---@param weaponType string
---@param weaponData table
---@return number?
--- attachInfo with this lane's offset folded in, or the original for lane 1.
--- Lane 1 is never moved: it is exactly where the weapon has always sat, which is what makes
--- the toggle OFF identical to before and keeps the first weapon put when a second arrives.
--- Returns a COPY — attachInfo is the shared config table, and writing to it would move
--- every weapon of that type, for everyone.
---@return table
local function withLaneOffset(info, propType, lane)
    if not lane or lane < 2 then return info end

    local cfg = MBT.MultiWeaponVisibility
    local byLane = cfg and cfg.LaneOffsets and cfg.LaneOffsets[propType]
    local off = byLane and byLane[lane]
    if not off then return info end

    local out = {
        Bone = info.Bone, isPed = info.isPed,
        RotOrder = info.RotOrder, FixedRot = info.FixedRot,
        Pos = {}, Rot = {},
    }
    local dp, dr = off.Pos or {}, off.Rot or {}
    for _, sex in ipairs({ 'male', 'female' }) do
        local p, r = info.Pos[sex], info.Rot[sex]
        out.Pos[sex] = { x = p.x + (dp.x or 0.0), y = p.y + (dp.y or 0.0), z = p.z + (dp.z or 0.0) }
        out.Rot[sex] = { x = r.x + (dr.x or 0.0), y = r.y + (dr.y or 0.0), z = r.z + (dr.z or 0.0) }
    end
    return out
end

---@param serial string?  registry key, so a per-weapon override (low ready) picks the right one
---@param lane number?    visual slot from the server; >1 shifts the prop by the lane offset
local function spawnProp(ctx, weaponType, weaponData, serial, lane)
    -- Spawn-window timing (debug only). Since b5d8c5b the prop is invisible for this whole
    -- stretch, so "the weapon takes a while to appear" is a report about a duration nobody
    -- can see. Split per phase: the three candidates are weapon streaming, per-component
    -- model streaming, and the fixed flashlight Wait — and they have very different fixes.
    local tStart = GetGameTimer()
    local tAsset, tExist, tComps

    local attachInfo = getAttachInfo({ Job = ctx.playerJob, Type = weaponType })
    -- Low Ready guard (opaque hook, no-op without the module): if the LOCAL player has this
    -- type in chest carry, spawn it on the chest directly so a re-sling after a draw doesn't
    -- snap back→chest. Gated to the local player (the stance is local state).
    local chestCarry = false
    if ctx.targetPlayerId == PlayerId() and MBT.GetLowReadyOverride then
        local override = MBT.GetLowReadyOverride(weaponType, serial)
        if override then attachInfo, chestCarry = override, true end
    end
    -- Skipped for chest carry: that is a deliberate spot for ONE weapon, and adding a lane
    -- offset on top would drag it off the chest.
    if not chestCarry then
        attachInfo = withLaneOffset(attachInfo, weaponType, lane)
    end

    local playerPed = ctx.playerPed
    local pedSex = ctx.pedSex
    local boneIndex = GetPedBoneIndex(playerPed, attachInfo["Bone"])
    weaponData.weaponHash = joaat(weaponData.name)

    -- Streaming can exceed 1s under load (restart/asset spikes). pcall so a slow stream
    -- doesn't throw a red error and wedge the reserved slot.
    if not pcall(lib.requestWeaponAsset, weaponData.weaponHash, 5000, 31, 1) then
        Utils.mbtDebugger("syncSling ~ weapon asset failed to stream for ", weaponData.name)
        return nil
    end
    tAsset = GetGameTimer()

    weaponData.weaponObj = CreateWeaponObject(weaponData.weaponHash, 50, ctx.playerCoords.x, ctx.playerCoords.y, ctx.playerCoords.z, true, 1.0, 0)
    RequestWeaponHighDetailModel(weaponData.weaponObj)
    RemoveWeaponAsset(weaponData.weaponHash)   -- object keeps its model; the asset was never freed (streaming-memory leak)

    local deadline = GetGameTimer() + 500
    while not DoesEntityExist(weaponData.weaponObj) and GetGameTimer() < deadline do
        Wait(10)
    end
    tExist = GetGameTimer()

    if not DoesEntityExist(weaponData.weaponObj) then
        Utils.mbtDebugger("syncSling ~ Weapon object failed to create for ", weaponData.name)
        return nil
    end

    Utils.mbtDebugger("syncSling ~ Weapon object created! ", weaponData.name, playerPed, boneIndex, attachInfo["Pos"][pedSex]["x"], attachInfo["Pos"][pedSex]["y"], attachInfo["Pos"][pedSex]["z"])
    -- Hide it for the whole spawn window. CreateWeaponObject drops a physics-enabled weapon
    -- at the player's feet, and it stays loose there — falling, tumbling — through the
    -- component pass and the flashlight Wait below (up to ~550ms) until the attach snaps it
    -- to the bone. That tumble is what you see on a restart. The visibility tick can't
    -- reveal it early: the entry is still 'pending', and that loop only walks live ones.
    SetEntityVisible(weaponData.weaponObj, false, 0)
    local hasObjFlashlight = applyAttachments(weaponData)
    tComps = GetGameTimer()
    -- Light the slung prop only when it ACTUALLY received a flashlight component AND the
    -- saved state says it was on. The component check prevents a weapon with stale/leaked
    -- flashlightState (but no torch) from glowing. NOTE: once a flashlight-component prop is
    -- lit, GTA couples it to the ped's global flashlight emitter, so it also lights when the
    -- player toggles the HELD weapon's torch — an engine limitation we accept (documented).
    local desiredFlashlight = MBT.EnableFlashlight and hasObjFlashlight
        and weaponData.metadata and weaponData.metadata.flashlightState == true or false
    SetCreateWeaponObjectLightSource(weaponData.weaponObj, desiredFlashlight)
    -- CRITICAL: keep this Wait. The engine needs a tick to commit the light-source flag
    -- before AttachEntityToEntity, or the attach pass resets it and the slung prop never
    -- renders its flashlight.
    Wait(50)
    -- Force Pos/Rot to FLOATS: an integer rotation argument makes AttachEntityToEntity IGNORE
    -- the rotation (the NUI's React sliders send integers that reach here as Lua ints,
    -- leaving the prop stuck at its default pose). +0.0 guarantees a float.
    local P, R = attachInfo["Pos"][pedSex], attachInfo["Rot"][pedSex]
    AttachEntityToEntity(weaponData.weaponObj, playerPed, boneIndex,
        P.x + 0.0, P.y + 0.0, P.z + 0.0, R.x + 0.0, R.y + 0.0, R.z + 0.0,
        true, true, false, attachInfo["isPed"], attachInfo["RotOrder"], attachInfo["FixedRot"])
    SetEntityCompletelyDisableCollision(weaponData.weaponObj, false, true)
    -- In place at last — reveal it, matching whatever the owner is doing on both channels:
    -- hidden (noclip) and faded out (relog/multichar fade the ped to 0 while we re-spawn its
    -- weapons, and the sync tick would flash them meanwhile).
    SetEntityVisible(weaponData.weaponObj, IsEntityVisible(playerPed), 0)
    Utils.syncPropAlpha(weaponData.weaponObj, GetEntityAlpha(playerPed))
    SetFlashLightKeepOnWhileMoving(true)
    Utils.mbtDebugger("syncSling ~ Apply attachments to weapon obj!")

    local tEnd = GetGameTimer()
    Utils.mbtDebugger(("syncSling ~ TIMING %s [%s]  total %dms  =  stream %d + create %d + components %d + attach %d")
        :format(weaponData.name, weaponType, tEnd - tStart,
            tAsset - tStart, tExist - tAsset, tComps - tExist, tEnd - tComps))

    return weaponData.weaponObj
end

-- Promotion (phase 4). Slung.resolve calls this when an action names a serial that is
-- tracked but not currently drawn — a hot barrel, a chest carry, an attachment refresh on
-- the copy that isn't the one on show. It builds that weapon's prop; Slung.resolve reveals
-- it and only THEN deletes the outgoing one, so the swap is invisible. The other direction
-- would leave the body bare for the ~550ms a spawn takes, which reads as a bug.
Slung.spawner = function(serverId, propType, entry, lane)
    if not entry or not entry.data then return nil end

    local targetPlayerId = (serverId == cache.serverId) and PlayerId() or GetPlayerFromServerId(serverId)
    if not targetPlayerId or targetPlayerId == -1 then return nil end
    local ped = GetPlayerPed(targetPlayerId)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end

    local ctx = playerCtxInScope[serverId] or {}
    return spawnProp({
        playerSource   = serverId,
        playerPed      = ped,
        playerCoords   = GetEntityCoords(ped),
        playerJob      = ctx.playerJob,
        pedSex         = ctx.pedSex or (IsPedMale(ped) and 'male' or 'female'),
        targetPlayerId = targetPlayerId,
    }, propType, entry.data, entry.serial, lane)
end

-- ── Lane offset tuning (debug builds) ────────────────────────────────────────────
-- Where the second weapon of a slot sits cannot be derived: it depends on the models, the
-- bone and what already hangs there. cfg is the live table and the re-attach is immediate,
-- so this is a look-and-nudge loop instead of edit-config-and-restart.
if MBT.Debug then
    --- Re-attach every prop of ours that sits in lane 2 or beyond, at the current offset.
    local function reattachLanes()
        local ped = cache.ped
        local sex = IsPedMale(ped) and 'male' or 'female'
        local job = (PlayerData and PlayerData.job and PlayerData.job.name) or nil

        Slung.forEach(cache.serverId, function(prop, propType, _, e)
            if not e.lane or e.lane < 2 then return end
            local info = withLaneOffset(getAttachInfo({ Job = job, Type = propType }), propType, e.lane)
            local P, R = info.Pos[sex], info.Rot[sex]
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, info.Bone),
                P.x + 0.0, P.y + 0.0, P.z + 0.0, R.x + 0.0, R.y + 0.0, R.z + 0.0,
                true, true, false, info.isPed, info.RotOrder, info.FixedRot)
        end)
    end

    RegisterCommand('mbt_lanetune', function(_, args)
        local cfg = MBT.MultiWeaponVisibility
        if not cfg then return end

        local propType = tostring(args[1] or 'back')
        local axis     = tostring(args[2] or 'show'):lower()
        local step     = tonumber(args[3])
        local lane     = math.floor(tonumber(args[4]) or 2)

        if not MBT.PropInfo[propType] then
            Utils.mbtDebugger('mbt_lanetune ~ unknown slot: ' .. propType)
            return
        end

        cfg.LaneOffsets = cfg.LaneOffsets or {}
        cfg.LaneOffsets[propType] = cfg.LaneOffsets[propType] or {}
        local o = cfg.LaneOffsets[propType][lane]
        if not o then
            o = { Pos = { x = 0.0, y = 0.0, z = 0.0 }, Rot = { x = 0.0, y = 0.0, z = 0.0 } }
            cfg.LaneOffsets[propType][lane] = o
        end

        if axis == 'reset' then
            o.Pos = { x = 0.0, y = 0.0, z = 0.0 }
            o.Rot = { x = 0.0, y = 0.0, z = 0.0 }
        elseif step and (axis == 'x' or axis == 'y' or axis == 'z') then
            o.Pos[axis] = (o.Pos[axis] or 0.0) + step
        elseif step and (axis == 'rx' or axis == 'ry' or axis == 'rz') then
            local k = axis:sub(2)
            o.Rot[k] = (o.Rot[k] or 0.0) + step
        elseif axis ~= 'show' then
            Utils.mbtDebugger('mbt_lanetune ~ usage: /mbt_lanetune <slot> x|y|z|rx|ry|rz <delta> [lane] · show · reset')
        end

        reattachLanes()

        local line = ("['%s'] = { [%d] = { Pos = { x = %.3f, y = %.3f, z = %.3f }, Rot = { x = %.1f, y = %.1f, z = %.1f } } },")
            :format(propType, lane, o.Pos.x, o.Pos.y, o.Pos.z, o.Rot.x, o.Rot.y, o.Rot.z)
        Utils.mbtDebugger('mbt_lanetune ~ ' .. line)
        lib.notify({ type = 'inform', title = 'Lane ' .. lane,
            description = ('%s  %.3f / %.3f / %.3f'):format(propType, o.Pos.x, o.Pos.y, o.Pos.z) })
    end, false)
end

RegisterNetEvent('mbt_malisling:syncSling')
AddEventHandler('mbt_malisling:syncSling', function (data)
    while not isReady do Wait(100) end
    Utils.mbtDebugger("syncSling ~ Receiving data from server")
    if not data then return end
    if not data.playerSource then return end

    Utils.mbtDebugger("syncSling ~ Receiving and filling table for source ", data.playerSource)

    local condSatisfied = waitingForTargetPlayerPed(data)
    if not condSatisfied then return end

    local targetPlayerId = GetPlayerFromServerId(data.playerSource)

    if not targetPlayerId or targetPlayerId == -1 then return end
    Utils.mbtDebugger("syncSling ~ PlayerID is valid ", targetPlayerId)
    local _deadline = GetGameTimer() + 10000
    while not DoesEntityExist(GetPlayerPed(targetPlayerId)) do
        if GetGameTimer() > _deadline or GetPlayerFromServerId(data.playerSource) == -1 then
            Utils.mbtDebugger("syncSling ~ Player ped timed out or disconnected, aborting")
            return
        end
        Utils.mbtDebugger("syncSling ~ Player ped is not valid yet")
        Wait(100)
    end

    local playerPed =  GetPlayerPed(targetPlayerId)
    if not playerPed then return end
    if not data.playerWeapons then return end
    local playerCoords = GetEntityCoords(playerPed)
    local playerJob = data.playerJob
    local pedSex = data.pedSex
    -- Record before the spawn loop: isPropSuppressed reads it below.
    if data.playerJobs then playerJobsInScope[data.playerSource] = data.playerJobs end
    playerCtxInScope[data.playerSource] = { playerJob = playerJob, pedSex = pedSex }

    Utils.mbtDebugger(data)

    Utils.mbtDebugger("Ped is ", pedSex, " with job ", playerJob)

    local ctx = {
        playerSource   = data.playerSource,
        playerPed      = playerPed,
        playerCoords   = playerCoords,
        playerJob      = playerJob,
        pedSex         = pedSex,
        targetPlayerId = targetPlayerId,
    }

    -- ── Desired-set reconciliation ────────────────────────────────────────────────
    -- The payload is a SNAPSHOT of everything this player should be wearing:
    -- [propType][serialKey] = { data = weaponData, lane, vkey }. We diff it against what is
    -- actually spawned instead of spawning on the event. That makes it idempotent — call it
    -- twice, call it mid-equip, call it after a restart, it converges — and it is the only
    -- reason a mismatch can be REPAIRED at all: you can compare two sets only when their
    -- elements have names, which is what the serial gives us.
    local src = data.playerSource
    local desired = data.playerWeapons

    -- Start tracking this player if we weren't already. We used to RETURN here, which meant
    -- a client only ever learned about someone through a syncScope 'add' — and if that one
    -- event was missed (it is queued one per 200ms, and a client that restarts after the
    -- scope diff has settled never gets another), that player stayed invisible for the rest
    -- of the session no matter how many snapshots arrived afterwards. Asymmetric by nature:
    -- whichever client missed its event is the one that can't see the other.
    -- The payload IS the server saying this player is in our scope; there is nothing else
    -- to wait for.
    if not playersToTrack[src] then playersToTrack[src] = {} end

    -- 1. Whole types that vanished from the snapshot.
    for propType in pairs(playersToTrack[src]) do
        if type(desired[propType]) ~= "table" then
            Slung.deleteType(src, propType)
        end
    end

    for weaponType, bySerial in pairs(desired) do
        if not playersToTrack[src] then return end

        if type(bySerial) == "table" and propInfoTable[weaponType] ~= nil then
            -- 2. Serials that are no longer wanted in this type (dropped, stowed, handed
            --    over, or now in hand). Only that serial goes; the others stay put.
            Slung.forEachType(src, weaponType, function(_, _, serial)
                if not bySerial[serial] then Slung.deleteSerial(src, weaponType, serial) end
            end, { states = 'all', stale = true })

            -- 3. Spawn what is missing. Suppression (concealed carry, hidden for this
            --    player's job) decides whether anything is drawn — one predicate, see
            --    isPropSuppressed. Evaluated per WEAPON, because concealment is: one
            --    tucked-away pistol must not take the other one off the hip too.
            for serial, slot in pairs(bySerial) do
                local weaponData = slot and slot.data
                if weaponData then
                    local suppressed = isPropSuppressed(src, weaponType, serial)
                    if suppressed or not slot.lane then
                        -- Tracked, not drawn: either hidden, or another serial holds the
                        -- lane. Unconditional — if we still have a prop for it, that prop
                        -- has to GO. Guarding this on "only if there is no prop yet" is
                        -- backwards, and it is how two rifles ended up sharing one lane.
                        -- The entry stays: deletes and promotion both need to know the
                        -- weapon is there.
                        Slung.shadow(src, weaponType, serial, weaponData, slot.lane, slot.vkey)
                    elseif Slung.reserve(src, weaponType, serial, 'spawn') then
                        -- reserve claims the slot SYNCHRONOUSLY before the async spawn.
                        -- Two near-simultaneous syncSling for the same weapon (at restart
                        -- the snapshot-poll updateInventory AND the server checkInventory
                        -- both fire) would otherwise both pass the free check during the
                        -- ~500ms create window, spawn two props and orphan one.
                        Utils.mbtDebugger("syncSling ~ spawning ", weaponData.name, serial)
                        local handle = spawnProp(ctx, weaponType, weaponData, serial, slot.lane)
                        if handle then
                            -- slot.lane comes from the SERVER and is applied as given: every
                            -- observer has to place the weapon in the same spot, so no client
                            -- ever computes a lane of its own.
                            Slung.commit(src, weaponType, serial, handle, weaponData, slot.lane, slot.vkey)
                        else
                            -- Kept as a shadow, weaponData and all, so it stays retryable —
                            -- a failed stream is how "everyone else sees the weapon, this
                            -- client never does" happens. The repair tick picks it up.
                            Slung.release(src, weaponType, serial, weaponData)
                        end
                    end
                end
            end
        end
    end

    Slung.setWaiting(src, nil)
end)


exports('ResetWeaponsOnBack', function()
    deleteAllWeapons()
    TriggerServerEvent("mbt_malisling:checkInventory")
end)

-- ── Flashlight state tracker ──────────────────────────────────────────────────
-- Polls IsFlashLightOn at 150ms cadence. Used by the unequip handler to recover
-- the state from the moment BEFORE GTA's holster transition cleared it. Single
-- thread, one native call per tick — negligible cost. Always-on, no gating.
CreateThread(function()
    while true do
        lastFlashlightState = IsFlashLightOn(cache.ped) == 1
        Wait(150)
    end
end)

-- ── Slung prop visibility + alpha sync ────────────────────────────────────────
-- Keeps each tracked weapon prop in sync with its owner ped on BOTH channels a
-- third-party script can use to hide someone:
--   * visibility flag — admin noclip is the common case (SetEntityVisible)
--   * alpha           — multichar switch / relog fade the ped to 0 for ~2s while
--                       the right outfit is applied (SetEntityAlpha)
-- They're independent: a ped at alpha 0 still reports IsEntityVisible() == true,
-- so syncing visibility alone left the props hanging in mid-air during a relog.
-- Covers the local player and every tracked remote player. Slung.forEach walks only live
-- props, so reservations and shadows are skipped for free.
CreateThread(function()
    while true do
        Wait(500)
        local mc = GetEntityCoords(cache.ped)
        for serverId in pairs(playersToTrack) do
            local ped
            if serverId == cache.serverId then
                ped = cache.ped
            else
                local plyr = GetPlayerFromServerId(serverId)
                ped = (plyr and plyr ~= -1) and GetPlayerPed(plyr) or nil
            end
            -- Distance-cull: a far ped's slung props aren't visible to us anyway, so skip the
            -- visibility sync (work scales with NEARBY peds, not every tracked one). Local always runs.
            if ped and ped ~= 0 and DoesEntityExist(ped)
               and (serverId == cache.serverId or #(mc - GetEntityCoords(ped)) < 80.0) then
                local pedVisible = IsEntityVisible(ped)
                local pedAlpha   = GetEntityAlpha(ped)
                Slung.forEach(serverId, function(prop)
                    if IsEntityVisible(prop) ~= pedVisible then
                        SetEntityVisible(prop, pedVisible, 0)
                    end
                    Utils.syncPropAlpha(prop, pedAlpha)
                end)

                -- ── Repair ────────────────────────────────────────────────────────
                -- A handle can die under us (network ownership migration, engine handle
                -- recycling) and a spawn can fail outright (asset streaming under load).
                -- Before, either one was permanent: the server went on believing the weapon
                -- was hanging there, every other client rendered it, and nothing ever
                -- re-synced. Comparing what the server said against what is really spawned
                -- turns that from forever into half a second.
                Slung.prune(serverId)

                -- One per tick. spawnProp waits on streaming, and this loop also carries
                -- the visibility sync for every player in scope — a burst of retries here
                -- would stall all of it.
                local ctx = playerCtxInScope[serverId]
                if ctx then
                    Slung.forEach(serverId, function(_, propType, serial, e)
                        -- Only entries the server gave a lane to: a shadow with no lane is
                        -- deliberately not drawn, not a failure.
                        -- Bounded. A weapon whose model never streams would otherwise be
                        -- retried twice a second for the rest of the session; the counter
                        -- resets when a new snapshot re-reserves the slot, so a transient
                        -- failure still recovers.
                        if e.lane and e.data and (e.retries or 0) < 3
                            and not isPropSuppressed(serverId, propType, serial) then
                            e.retries = (e.retries or 0) + 1
                            Utils.mbtDebugger('repair ~ re-spawning ', e.data.name, ' for ', serverId)
                            if Slung.reserve(serverId, propType, serial, 'repair') then
                                local handle = spawnProp({
                                    playerSource   = serverId,
                                    playerPed      = ped,
                                    playerCoords   = GetEntityCoords(ped),
                                    playerJob      = ctx.playerJob,
                                    pedSex         = ctx.pedSex,
                                    targetPlayerId = GetPlayerFromServerId(serverId),
                                }, propType, e.data, serial, e.lane)
                                if handle then
                                    Slung.commit(serverId, propType, serial, handle, e.data, e.lane, e.vkey)
                                else
                                    Slung.release(serverId, propType, serial, e.data)
                                end
                            end
                            return true   -- stop: one repair per tick
                        end
                    end, { states = { 'shadow' } })
                end
            end
        end
    end
end)

