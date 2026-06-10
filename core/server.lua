lib.versionCheck('MalibuTechTeam/mbt_malisling')

local isReady = false
playersToTrack = {}

-- Inventory and loadInventoryWeaponsData() are provided by modules/inventory/*/server.lua
if not Inventory then
    Utils.mbtWarn("mbt_malisling: No supported inventory found! Install ox_inventory >= 2.30.0 or qb-inventory.")
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
    playersToTrack[s] = nil
    removePlayerFromScopes(s)
end

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadWeaponsInfo()
end)

AddEventHandler("playerDropped", function()
    if not source then return end
    dropPlayer(source)
end)

RegisterNetEvent("mbt_malisling:getPlayersInPlayerScope")
AddEventHandler("mbt_malisling:getPlayersInPlayerScope", function(data)
    if type(data) ~= "table" then return end
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
    Utils.mbtDebugger("checkInventory ~ Checking inventory for source ", source)
    local items = Inventory:GetInventoryItems(source)
    if type(items) ~= "table" then items = {} end
    TriggerClientEvent("mbt_malisling:checkWeaponProps", source, items)
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
    if not playersToTrack[_source] then playersToTrack[_source] = {} end
    for k, v in pairs(data.playerWeapons) do
        if _validWeaponTypes[k] and (type(v) == "table" or v == false) then
            playersToTrack[_source][k] = v
        end
    end
    -- Chain of Custody: record holders AFTER the sling sync (a server-side ledger
    -- keyed by serial — NOT a metadata write, which would re-trigger updateInventory
    -- and re-spawn the slung prop while the weapon is in hand).
    if MBT.ChainOfCustody and MBT.ChainOfCustody.RecordHolders then
        MBT.ChainOfCustody.RecordHolders(_source, data.playerWeapons)
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
            pedSex = getPlayerSex(_source),
            calledBy = "mbt_malisling:syncSling ~ 162",
            playerWeapons = playersToTrack[_source]
        }
    })
end)

RegisterNetEvent("mbt_malisling:syncDeletion")
AddEventHandler("mbt_malisling:syncDeletion", function(weaponType)
    local _source = source
    if playersToTrack[_source] == nil then return end
    playersToTrack[_source][weaponType] = false

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
    if not data.event then Utils.mbtWarn("No event has passed in triggerCl function") return end
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
                            pedSex = getPlayerSex(source),
                            playerWeapons = values[i].type == "Added" and playersToTrack[tonumber(source)] or nil
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
