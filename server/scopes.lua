local functQueue, oldScop = {}, {}
scopes = {}

local utils = require 'utils'
 
---@param player number | string
---@param playerToAdd number | string
function addPlayerToPlayerScope(player, playerToAdd)
    local player = tostring(player)
    local playerSource = tonumber(player)
    local playerToAdd = tonumber(playerToAdd)
    local playerToAddSource = tostring(playerToAdd)

    local playerScope = scopes[player]
    if utils.containsValue(playerScope, playerToAdd) then return end
    playerScope[#playerScope+1] = playerToAdd

    if scopes[playerToAddSource] then
        local isIn = utils.containsValue(scopes[playerToAddSource], playerSource)
        if not isIn then
            scopes[playerToAddSource][#scopes[playerToAddSource]+1] = playerSource
        end
    end

    utils.mbtDebugger("addPlayerToPlayerScope ~ Added players!")
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
        local isContaining, index = utils.containsValue(scopes[player], playerToRemoveSource)
        if isContaining then
            table.remove(scopes[player], index)
        end
    end

    if scopes[playerToRemove] then
        local isContaining, index = utils.containsValue(scopes[playerToRemove], playerSource)
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
    if not data.event then warn("No event has passed in triggerCl function")return end
    local target = data.target
    if not data.target then warn("No target has passed in triggerCl function") return end
    local payload = data.payload
    if not data.payload then warn("No payload has passed in triggerCl function") return end

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
    local scopeOwner = tostring(data.scopeOwner)
    if not scopeOwner then return end
    local selfTrigger = data.selfTrigger
    local payload = data.payload
    local cb = data.cb
    local targets = scopes[scopeOwner]

    if not targets then return end

    local p = promise.new()

    utils.mbtDebugger("^2TriggerScopeEvent ~ targets of ", scopeOwner)
    for i=1, #targets do
        local target = tonumber(targets[i])
        TriggerClientEvent(event, target, payload)
    end

    if selfTrigger then
        scopeOwner = tonumber(scopeOwner)
        TriggerClientEvent(event, scopeOwner, payload)
    end

    if cb then cb() end

    p:resolve("Done")
    utils.mbtDebugger("TriggerScopeEvent ~ Finished!, state of promise ", p.state, p.value)

    return p
end

AddEventHandler("playerEnteredScope", function(data)
    local playerEntering, player = data["player"], data["for"]
    local playerEnteringSource, playerSource = tonumber(playerEntering), tonumber(player)
    local playerEnteringCoords = GetEntityCoords(GetPlayerPed(playerEnteringSource))
    local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
    if not playerEnteringCoords.x == 0.0 and playerEnteringCoords.y == 0.0 then return end
    if not playerCoords.x == 0.0 and playerCoords.y == 0.0 then return end

    utils.mbtDebugger(("^2%s is entering %s's scope"):format(playerEntering, player))
    if not playerEntering then return end
    utils.mbtDebugger("playerEnteredScope check 2")
    if not player then return end
    utils.mbtDebugger("playerEnteredScope check 3")

    if not playersToTrack[playerSource] then return end

    utils.mbtDebugger("playerEnteredScope ~ Check passed!")

    if not scopes[player] then 
        utils.mbtDebugger("playerEnteredScope ~ Initialized scope for player ", player)
        scopes[player] = {} 
    end

    addPlayerToPlayerScope(player, playerEntering)
end)

AddEventHandler("playerLeftScope", function(data)
    local playerLeaving, player = data["player"], data["for"]
    utils.mbtDebugger(("^2%s is leaving %s's scope"):format(playerLeaving, player))
    removePlayerFromPlayerScope(playerLeaving, player);
end)

Citizen.CreateThread(function()
    utils.mbtDebugger("Queuing Thread ~ Started!")
    while true do

        local diffs = utils.getDifferences(oldScop, scopes)

        for source, values in pairs(diffs) do
            for i=1, #values do
                utils.mbtDebugger("Queuing Thread ~ Key: ", source, "Type: ", values[i].type, "Value: ", values[i].value)

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
        end

        oldScop = utils.tableDeepCopy(scopes)
        Citizen.Wait(100)
    end
end)

Citizen.CreateThread(function()
    local isBusy = false

    while true do
        Wait(200)
        if #functQueue > 0 then
            if isBusy then utils.mbtDebugger("Execute queue thread ~ Busy!!!") end
            if not isBusy and functQueue[1] then
                isBusy = true
                local qElement = functQueue[1]

                utils.mbtDebugger("Execute queue thread ~ Executing function ", qElement.args.event, " with target ", qElement.args.target, " and payload ", json.encode(qElement.args.payload))
                local ps = Citizen.Await(qElement.funct(qElement.args))
                table.remove(functQueue, 1)
                utils.mbtDebugger("Execute queue thread ~ Resolved process event ", qElement.args.event, " Promise: ", ps)
                isBusy = false
            end
        end
    end
end)
