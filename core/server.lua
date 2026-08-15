-- Refuse to run under a renamed folder (anti clone-and-rebrand). core/server.lua registers
-- the script's server callbacks, so bailing here leaves the whole resource inert on a rename.
if not Utils.MbtResourceNameCheck('mbt_malisling') then return end

-- Version check lives in modules/version/server.lua: it also feeds the dashboard badge,
-- which lib.versionCheck can't do (console-only, result not exposed).

local isReady = false
-- playersToTrack and every operation on it live in modules/slung/server.lua (global `Slung`).

-- Inventory and loadInventoryWeaponsData() come from modules/inventory/*/server.lua, which
-- bail out when their inventory is not 'started' at the moment we load — a restart that
-- leaves ox_inventory briefly in 'starting' takes both out. Without this guard the next
-- line calls a nil global, and that error names nothing an owner can act on.
-- Stop, don't return: modules loaded before this file call MBT.NetThrottle, defined below.
if not Inventory or not loadInventoryWeaponsData then
    Utils.Error(
        "No supported inventory detected at startup. Install ox_inventory >= 2.30.0 or qb-inventory, " ..
        "and make sure it is fully started BEFORE mbt_malisling — in server.cfg, ensure it first. " ..
        "If it was already running, this usually means it was mid-restart: restart mbt_malisling on its own."
    )
    return StopResource(GetCurrentResourceName())
end

lib.callback.register('mbt_malisling:getWeapoConf', function(source)
    Utils.mbtDebugger("getWeapoConf ~  Source ", source, " requested callback!")
    while not isReady do Wait(250) end
    return MBT.WeaponsInfo
end)

local function loadWeaponsInfo()
    Utils.mbtDebugger("Loading WeaponsInfo!")

    local weaponsInfo = loadInventoryWeaponsData()

    for k, v in pairs(Utils.data('weapons')) do
        if not weaponsInfo["Weapons"][k] then
            weaponsInfo["Weapons"][k] = { type = v.type }
        else
            weaponsInfo["Weapons"][k]["type"] = v.type
        end
    end

    MBT.WeaponsInfo = weaponsInfo
    local b = MBT.EnableSling and true or false
    SetConvarReplicated("malisling:enable_sling", tostring(b))
    TriggerClientEvent("mbt_malisling:sendWeaponsData", -1, MBT.WeaponsInfo)
    isReady = true
end

---@param s number
local function dropPlayer(s)
    TriggerClientEvent("mbt_malisling:syncDeletion", -1,
        { playerSource = s, weaponType = "all", calledBy = "dropPlayer" })
    TriggerClientEvent("mbt_malisling:syncPlayerRemoval", -1, { playerSource = s })
    Slung.clearPlayer(s)
    removePlayerFromScopes(s)
end

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadWeaponsInfo()
end)

-- Per-source net-event throttle — the house anti-spam pattern. Exposed as MBT.NetThrottle
-- so feature modules share one per-src table (cleared on playerDropped below).
local _lastNet = {}   -- [src] = { [key] = lastMs }
local function netThrottle(src, key, ms)
    local t = _lastNet[src]
    if not t then t = {}; _lastNet[src] = t end
    local now = GetGameTimer()
    if t[key] and (now - t[key]) < ms then return false end
    t[key] = now
    return true
end
MBT.NetThrottle = netThrottle

AddEventHandler("playerDropped", function()
    if not source then return end
    _lastNet[source] = nil
    dropPlayer(source)
end)

RegisterNetEvent("mbt_malisling:getPlayersInPlayerScope")
AddEventHandler("mbt_malisling:getPlayersInPlayerScope", function(data)
    if type(data) ~= "table" then return end
    if not netThrottle(source, 'scope', 100) then return end
    if not scopes[tostring(source)] then scopes[tostring(source)] = {} end
    local limit = math.min(#data, 2048)
    for i = 1, limit do
        local id = tonumber(data[i])
        if id and id > 0 then
            addPlayerToPlayerScope(source, id)
        end
    end
end)

RegisterNetEvent("mbt_malisling:checkInventory")
AddEventHandler("mbt_malisling:checkInventory", function()
    if not netThrottle(source, 'checkInv', 250) then return end
    Slung.ensurePlayer(source)   -- a restart doesn't re-fire playerLoaded; see Slung.ensurePlayer
    Utils.mbtDebugger("checkInventory ~ Checking inventory for source ", source)
    local items = Inventory:GetInventoryItems(source)
    if type(items) ~= "table" then items = {} end
    TriggerClientEvent("mbt_malisling:checkWeaponProps", source, items)
end)

--- Ask every tracked player to re-report what they carry.
--- Lanes are worked out when a snapshot lands, and so is whether a job hides a slot, so a
--- change to either would sit unused until something else happened to somebody's inventory.
--- Their reports come back through the same path that decides both, so one call re-decides
--- the whole server. Staggered: on a full server this is 64 round trips, and there is no hurry.
---
--- No syncDeletion first, unlike jobChanged above: the reconciliation drops what should no
--- longer exist on its own, and clearing everything makes every prop on the street blink for
--- a setting that may not have touched them.
function MBT.RefreshAllSling()
    CreateThread(function()
        -- Let the applyConfig broadcast that triggered this land first. Without the pause the
        -- re-report can arrive before the new config does, and observers re-decide using the
        -- values we were trying to replace — the change then appears to do nothing.
        Wait(150)
        for _, id in ipairs(GetPlayers()) do
            local s = tonumber(id)
            if s and playersToTrack[s] then
                local items = Inventory:GetInventoryItems(s)
                if type(items) == "table" then
                    TriggerClientEvent("mbt_malisling:checkWeaponProps", s, items)
                end
            end
            Wait(50)
        end
    end)
end

-- Job changed: every observer has to re-decide what to draw on this player. Their job
-- feeds MBT.HiddenByJob (whether a prop exists at all) and MBT.CustomPropPosition (where
-- it sits), and neither was re-evaluated on a job change before — the props simply kept
-- whatever they were given when they spawned.
RegisterNetEvent("mbt_malisling:jobChanged")
AddEventHandler("mbt_malisling:jobChanged", function()
    local _source = source
    if not netThrottle(_source, 'jobChange', 1000) then return end

    -- ONE broadcast that clears every type, not a loop of per-type syncDeletion: that
    -- event is throttled at 100ms per source, so most of seven deletes would be dropped
    -- and the player would be left with a half-updated set of props.
    TriggerClientEvent("mbt_malisling:syncDeletion", -1,
        { playerSource = _source, weaponType = "all", calledBy = "jobChanged" })

    -- Then let the normal path rebuild. The client re-reports what it carries, the sync
    -- goes back out with the job re-resolved HERE (a job name from a client is not
    -- evidence), and the suppression predicate drops whatever the new job hides.
    local items = Inventory:GetInventoryItems(_source)
    if type(items) ~= "table" then items = {} end
    TriggerClientEvent("mbt_malisling:checkWeaponProps", _source, items)
end)

-- Derived from MBT.PropInfo so any custom type added to the config (e.g.
-- 'extinguisher') is accepted automatically — no separate whitelist to keep
-- in sync.
local _validWeaponTypes = {}
for k in pairs(MBT.PropInfo) do _validWeaponTypes[k] = true end

RegisterNetEvent("mbt_malisling:syncSling")
AddEventHandler("mbt_malisling:syncSling", function(data)
    local _source = source
    if type(data) ~= "table" or type(data.playerWeapons) ~= "table" then return end
    if not netThrottle(_source, 'syncSling', 100) then return end
    -- Shape gate. The payload REPLACES this player's registry, so a malformed one doesn't
    -- write partial state — it wipes everything it failed to mention. Reject the lot
    -- instead: [type][serial] = item, and every leaf must look like a weapon item. Catches
    -- both a client on the old flat shape and a hand-built partial payload.
    for propType, bySerial in pairs(data.playerWeapons) do
        if type(propType) ~= "string" or type(bySerial) ~= "table" then
            Utils.mbtWarn(("syncSling ~ malformed payload from %s (type key), ignored"):format(_source))
            return
        end
        for _, item in pairs(bySerial) do
            if type(item) ~= "table" or type(item.name) ~= "string" then
                Utils.mbtWarn(("syncSling ~ malformed payload from %s (item under '%s'), ignored"):format(_source, propType))
                return
            end
        end
    end

    Slung.ensurePlayer(_source)
    -- The client reports its COMPLETE desired set every time — every weapon that should be
    -- hanging on it, keyed by type and serial — so this replaces the player's registry
    -- rather than merging into it. Type filtering happens inside replaceAll.
    Slung.replaceAll(_source, data.playerWeapons)
    -- Chain of Custody: record holders AFTER the sling sync (a server-side ledger
    -- keyed by serial — NOT a metadata write, which would re-trigger updateInventory
    -- and re-spawn the slung prop while the weapon is in hand).
    if MBT.ChainOfCustody and MBT.ChainOfCustody.RecordHolders then
        MBT.ChainOfCustody.RecordHolders(_source)   -- resolves serials server-side; ignores client payload
    end

    Wait(100)

    TriggerScopeEvent({
        event = "mbt_malisling:syncSling",
        scopeOwner = _source,
        selfTrigger = true,
        payload = {
            type = "add",
            playerSource = _source,
            playerJob = getPlayerJob(_source),
            -- Full set alongside the single name: MBT.HiddenByJob has to answer "is this
            -- player a cop", and on ox_core someone can hold several groups at once, so
            -- the single name is one arbitrary pick out of them. playerJob stays for the
            -- position overrides, which are keyed by one job by design.
            playerJobs = getPlayerJobs(_source),
            pedSex = getPlayerSex(_source),
            calledBy = "mbt_malisling:syncSling ~ 162",
            playerWeapons = Slung.snapshot(_source)
        }
    })
end)

RegisterNetEvent("mbt_malisling:syncDeletion")
AddEventHandler("mbt_malisling:syncDeletion", function(weaponType)
    local _source = source
    if not _validWeaponTypes[weaponType] then return end   -- validate the key, like syncSling
    if not netThrottle(_source, 'syncDel', 100) then return end
    if playersToTrack[_source] == nil then return end
    Slung.clearType(_source, weaponType)

    TriggerScopeEvent({
        event = "mbt_malisling:syncDeletion",
        scopeOwner = _source,
        selfTrigger = true,
        payload = {
            playerSource = _source,
            calledBy = "mbt_malisling:syncDeletion",
            weaponType = weaponType
        }
    })
end)

-- Every type at once. Its own event on purpose: syncDeletion is throttled at 100ms per
-- source, so a client looping one delete per type lands the first and loses the rest, and
-- the observers keep rendering props the owner has already destroyed (entering a vehicle
-- with a pistol AND a rifle slung is enough to hit it). Same shape as the jobChanged reset.
RegisterNetEvent("mbt_malisling:syncDeletionAll")
AddEventHandler("mbt_malisling:syncDeletionAll", function()
    local _source = source
    if not netThrottle(_source, 'syncDelAll', 100) then return end
    if playersToTrack[_source] == nil then return end
    Slung.clearAll(_source)

    TriggerScopeEvent({
        event = "mbt_malisling:syncDeletion",
        scopeOwner = _source,
        selfTrigger = true,
        payload = {
            playerSource = _source,
            calledBy = "mbt_malisling:syncDeletionAll",
            weaponType = "all"
        }
    })
end)

-- Debug-only view of the server's side of the sync. Client-side debugging can only ever
-- prove what a client RECEIVED; when two players disagree about who is carrying what, the
-- answer is in the registry and in the scope lists, and there is no other way to see them.
-- Registered only in debug builds — it exposes serials.
if MBT.Debug then
    lib.callback.register('mbt_malisling:debugSnapshot', function(src)
        local registry = {}
        for playerId, byType in pairs(playersToTrack) do
            local types = {}
            for propType, bySerial in pairs(byType) do
                local serials = {}
                for serial, entry in pairs(bySerial) do
                    serials[#serials + 1] = ('%s(%s, lane %s)'):format(
                        serial, entry.data and entry.data.name or '?', tostring(entry.lane))
                end
                table.sort(serials)
                if #serials > 0 then types[propType] = serials end
            end
            registry[tostring(playerId)] = types
        end

        -- Who this player fans out TO, and who fans out to them. An asymmetry here is
        -- exactly the "I see him, he doesn't see me" report.
        local seesMe = {}
        for owner, list in pairs(scopes) do
            for i = 1, #list do
                if list[i] == src then seesMe[#seesMe + 1] = owner break end
            end
        end

        return { registry = registry, myScope = scopes[tostring(src)] or {}, inScopeOf = seesMe }
    end)
end

-- Scopes --

local functQueue, oldScop = {}, {}
scopes = {}

---@param player number | string
---@param playerToAdd number | string
function addPlayerToPlayerScope(player, playerToAdd)
    local player = tostring(player)
    local playerSource = tonumber(player)
    local playerToAdd = tonumber(playerToAdd)
    local playerToAddSource = tostring(playerToAdd)

    if not scopes[player] then scopes[player] = {} end
    local playerScope = scopes[player]
    if Utils.containsValue(playerScope, playerToAdd) then return end
    playerScope[#playerScope+1] = playerToAdd

    if scopes[playerToAddSource] then
        local isIn = Utils.containsValue(scopes[playerToAddSource], playerSource)
        if not isIn then
            scopes[playerToAddSource][#scopes[playerToAddSource]+1] = playerSource
        end
    end

    Utils.mbtDebugger("addPlayerToPlayerScope ~ Added players!")
end

---@param player string
---@param playerToRemove string
local function removePlayerFromPlayerScope(player, playerToRemove)
    local playerSource = tonumber(player)
    local playerToRemoveSource = tonumber(playerToRemove)

    if scopes[player] then
        TriggerClientEvent("mbt_malisling:stopWaitingForPlayer", playerSource, playerToRemoveSource)
    end

    if scopes[player] then
        local isContaining, index = Utils.containsValue(scopes[player], playerToRemoveSource)
        if isContaining then
            table.remove(scopes[player], index)
        end
    end

    if scopes[playerToRemove] then
        local isContaining, index = Utils.containsValue(scopes[playerToRemove], playerSource)
        if isContaining then
            table.remove(scopes[playerToRemove], index)
        end
    end
end

function removePlayerFromScopes(s)
    for k,v in pairs(scopes) do
        for i=1, #v do
            if v[i] == s then
                table.remove(v, i)
            end
        end
        if k == tostring(s) then scopes[k] = nil end
    end
end

---@param data table
---@return promise
local function triggerCl(data)
    local event = data.event
    if not event or type(event) ~= "string" then Utils.mbtWarn("No event has passed in triggerCl function") return end
    local target = data.target
    if not data.target then Utils.mbtWarn("No target has passed in triggerCl function") return end
    local payload = data.payload
    if not data.payload then Utils.mbtWarn("No payload has passed in triggerCl function") return end

    local p = promise.new()
    TriggerClientEvent(data.event, data.target, data.payload)
    p:resolve("Done")
    return p
end

---Trigger event to all players inside scope
---@param data table
---@return promise
function TriggerScopeEvent(data)
    local event = data.event
    if not event or type(event) ~= "string" then return end
    if not data.scopeOwner then return end
    local scopeOwner = tostring(data.scopeOwner)
    local selfTrigger = data.selfTrigger
    local payload = data.payload
    local cb = data.cb
    local targets = scopes[scopeOwner]

    if not targets then return end

    local p = promise.new()

    Utils.mbtDebugger("TriggerScopeEvent ~ targets of ", scopeOwner)
    for i=1, #targets do
        local target = tonumber(targets[i])
        if target and target > 0 then
            TriggerClientEvent(event, target, payload)
        end
    end

    if selfTrigger then
        local owner = tonumber(scopeOwner)
        if owner and owner > 0 then
            TriggerClientEvent(event, owner, payload)
        end
    end

    if cb then cb() end

    p:resolve("Done")
    Utils.mbtDebugger("TriggerScopeEvent ~ Finished!, state of promise ", p.state, p.value)

    return p
end

AddEventHandler("playerEnteredScope", function(data)
    local playerEntering, player = data["player"], data["for"]
    local playerEnteringSource, playerSource = tonumber(playerEntering), tonumber(player)
    local playerEnteringCoords = GetEntityCoords(GetPlayerPed(playerEnteringSource))
    local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
    if playerEnteringCoords.x == 0.0 and playerEnteringCoords.y == 0.0 then return end
    if playerCoords.x == 0.0 and playerCoords.y == 0.0 then return end

    Utils.mbtDebugger(("^2%s is entering %s's scope"):format(playerEntering, player))
    if not playerEntering then return end
    Utils.mbtDebugger("playerEnteredScope check 2")
    if not player then return end
    Utils.mbtDebugger("playerEnteredScope check 3")

    if not playersToTrack[playerSource] then return end

    Utils.mbtDebugger("playerEnteredScope ~ Check passed!")

    if not scopes[player] then
        Utils.mbtDebugger("playerEnteredScope ~ Initialized scope for player ", player)
        scopes[player] = {}
    end

    addPlayerToPlayerScope(player, playerEntering)
end)

AddEventHandler("playerLeftScope", function(data)
    local playerLeaving, player = data["player"], data["for"]
    Utils.mbtDebugger(("^2%s is leaving %s's scope"):format(playerLeaving, player))
    removePlayerFromPlayerScope(playerLeaving, player);
end)

Citizen.CreateThread(function()
    Utils.mbtDebugger("Queuing Thread ~ Started!")
    while true do
        local diffs = Utils.getDifferences(oldScop, scopes)

        for source, values in pairs(diffs) do
            for i=1, #values do
                Utils.mbtDebugger("Queuing Thread ~ Key: ", source, "Type: ", values[i].type, "Value: ", values[i].value)
                functQueue[#functQueue+1] = {
                    funct = triggerCl,
                    args = {
                        event = "mbt_malisling:syncScope",
                        target = tonumber(values[i].value),
                        payload = {
                            tType = values[i].type == "Removed" and "del" or "add",
                            playerSource = tonumber(source),
                            playerJob = getPlayerJob(source),
                            playerJobs = getPlayerJobs(source),
                            pedSex = getPlayerSex(source),
                            playerWeapons = values[i].type == "Added" and Slung.snapshot(tonumber(source)) or nil
                        }
                    }
                }
            end
            oldScop[source] = scopes[source] and Utils.tableDeepCopy(scopes[source]) or nil
        end

        Citizen.Wait(100)
    end
end)

Citizen.CreateThread(function()
    local isBusy = false

    while true do
        Wait(200)
        if #functQueue > 0 then
            if isBusy then Utils.mbtDebugger("Execute queue thread ~ Busy!!!") end
            if not isBusy and functQueue[1] then
                isBusy = true
                local qElement = functQueue[1]

                Utils.mbtDebugger("Execute queue thread ~ Executing function ", qElement.args.event, " with target ", qElement.args.target, " and payload ", json.encode(qElement.args.payload))
                local ps = Citizen.Await(qElement.funct(qElement.args))
                table.remove(functQueue, 1)
                Utils.mbtDebugger("Execute queue thread ~ Resolved process event ", qElement.args.event, " Promise: ", ps)
                isBusy = false
            end
        end
    end
end)
