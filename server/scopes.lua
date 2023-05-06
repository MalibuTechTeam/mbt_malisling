scopes = {}
functQueue = {}
-- local scop = {}

-- local b, b2 = false, false
-- TODO: Passing data with function and args as obj


AddEventHandler("playerEnteredScope", function(data)
    --TODO: Check if playerEnteredScope works on player joining server

    local playerEntering, player = data["player"], data["for"]
    local playerEnteringCoords = GetEntityCoords(GetPlayerPed(tonumber(playerEntering)))
    local playerCoords = GetEntityCoords(GetPlayerPed(tonumber(player)))

    print(playerEnteringCoords)
    print(playerCoords)
    print(playerEnteringCoords.x)
    print(playerCoords.x)

    if not playerEnteringCoords.x == 0.0 and playerEnteringCoords.y == 0.0 then return end
    if not playerCoords.x == 0.0 and playerCoords.y == 0.0 then return end

    print(("^2%s is entering %s's scope"):format(playerEntering, player))

    -- print("OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO ", GetPlayerPed(tonumber(playerEntering)))
    -- print("PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP ",playerEnteringCoords)

    if not playerEntering then return end
    print("playerEnteredScope check 2")
    if not player then return end
    print("playerEnteredScope check 3")

    if not playersToTrack[tonumber(player)] then return end

    print("playerEnteredScope passed!")

    if not scopes[player] then 
        print("playerEnteredScope INITIALIZED scopes[player]")
        scopes[player] = {} 
    end

    -- scopes[player][#scopes[player]+1] = playerEntering
    -- addPlayerToPlayerScope(player, playerEntering)
    -- Wait(200)
    -- dumpTable(playersToTrack[playerEntering])
    -- Wait(700)
    -- print(playerEntering, type(playerEntering))


    addPlayerToPlayerScope(player, playerEntering)

    -- TODO: Add function to queue and args
    -- TriggerScopeEvent("mbt_malisling:syncScope", playerEntering, false, nil, "add", { playerSource = tonumber(playerEntering), playerWeapons = playersToTrack[tonumber(playerEntering)] })

    -- functQueue[#functQueue+1] = {funct = TriggerScopeEvent, args = {
    --     event = "mbt_malisling:syncScope",
    --     scopeOwner = playerEntering,
    --     selfTrigger = false,
    --     payload = {
    --         tType = "add",
    --         playerSource = tonumber(playerEntering),
    --         playerWeapons = playersToTrack[tonumber(playerEntering)]
    --     },
    --     cb = function ()
    --         -- addPlayerToPlayerScope(player, playerEntering)
    --         print("^2Added function to queue for player ", playerEntering)
    --     end
    -- }}

end)

AddEventHandler("playerLeftScope", function(data)
    local playerLeaving, player = data["player"], data["for"]

    local playerLeavingCoords = GetEntityCoords(GetPlayerPed(tonumber(playerLeaving)))
    local playerCoords = GetEntityCoords(GetPlayerPed(tonumber(player)))

    -- print("playerCoords ", playerCoords)
    -- print("playerLeavingCoords ", playerLeavingCoords)
    -- print("POOOLZZZ ", playerLeavingCoords.x)
    -- if not playerLeavingCoords.x == 0.0 and playerLeavingCoords.y == 0.0 then return end
    -- if not playerCoords.x == 0.0 and playerCoords.y == 0.0 then return end

    print(("^2%s is leaving %s's scope"):format(playerLeaving, player))
    -- TriggerScopeEvent("mbt_malisling:syncScope", playerLeaving, false, function () Wait(1000) removePlayerFromPlayerScope(player, playerLeaving) end, "del", { playerSource = tonumber(playerLeaving) })
    -- Wait(500)
    -- removePlayerFromPlayerScope(player, playerLeaving)
    -- Wait(1000)
    -- TriggerClientEvent("mbt_malisling:syncScope", tonumber(playerLeaving), {
    --     tType = "del",
    --     playerSource = tonumber(playerLeaving)
    -- })
    -- Wait(1000)

    removePlayerFromPlayerScope(playerLeaving, player);

    -- functQueue[#functQueue+1] = {funct = TriggerScopeEvent, args = {
    --     event = "mbt_malisling:syncScope",
    --     scopeOwner = playerLeaving,
    --     selfTrigger = false,
    --     payload = {
    --         tType = "del",
    --         playerSource = tonumber(playerLeaving)
    --     },
    --     cb = function ()
    --         Wait(100);
    --         removePlayerFromPlayerScope(playerLeaving, player);
    --         print("^2Added function to queue for player ", playerLeaving)
    --     end
    -- }}
end)

function addPlayerToPlayerScope(player, playerToAdd)
    player = tostring(player)
    local playerN = tonumber(player)
    playerToAdd = tonumber(playerToAdd)
    local playerToAddS = tostring(playerToAdd)

    -- for k,v in pairs(scopes) do
    --     print(k, json.encode(v))
    -- end

  -- print("addPlayerToPlayerScope ~ BEFORE ")
    -- dumptable(scopes)

    local playerScope = scopes[player]
  -- print("Adding player "..playerToAdd.." to "..player.."'s scope")
    if containsValue(playerScope, playerToAdd) then return end
    playerScope[#playerScope+1] = playerToAdd

    -- for k,v in pairs(playerScope) do
    --   -- print(k, json.encode(v))
    -- end
  -- print("addPlayerToPlayerScope ~ AFTER ")
    -- dumptable(scopes)


    -- Wait(250)

    if scopes[playerToAddS] then
        local isIn = containsValue(scopes[playerToAddS], playerN)
        -- print("Is "..player.." in "..playerToAdd.."'s scope? "..tostring(isIn))
        if not isIn then
            scopes[playerToAddS][#scopes[playerToAddS]+1] = playerN
        end
    end

    print("addPlayerToPlayerScope ~ Added players!")

    dumpTable(scopes)
end

function removePlayerFromPlayerScope(player, playerToRemove)
    local playerN = tonumber(player)
    local playerToRemoveN = tonumber(playerToRemove)

    local playersInScope = scopes[player]

    -- print("removePlayerFromPlayerScope ~ checking scope for player ", player)
    -- print("removePlayerFromPlayerScope ~ wanting ro temove player ", playerToRemove)
    -- print("removePlayerFromPlayerScope ~ scopes before removal:")
    -- dumptable(scopes)

    if playersInScope then
        for i=1, #playersInScope do
            if playersInScope[i] == playerToRemoveN then
                table.remove(playersInScope, i)
                break
            end
        end
        print("removePlayerFromPlayerScope ~ scopes after removal:")
        -- changeScope()
        -- dumptable(scopes)
    end
end

function removePlayerFromScopes(s)
    local sSource = tostring(s)
    if scopes[sSource] then scopes[sSource] = nil end
    for k,v in pairs(scopes) do
        local containsDroppedPlayer, index = containsValue(v, s)
        if containsDroppedPlayer then
            table.remove(v, index)
        end
    end
end

function getPlayersInPlayerScope(player)
    if not player then return end
    return scopes[tostring(player)]
end

function TriggerScopeEvent(data)
    -- print("Trigger scopeeeeeeeeeeeeeeeeeee")
    local event = data.event
    local scopeOwner = tostring(data.scopeOwner)
    if not scopeOwner then return end
    local selfTrigger = data.selfTrigger
    local payload = data.payload
    local cb = data.cb
    local targets = scopes[scopeOwner]

    if not targets then return end

    -- print("Trigger scopeeeeee started for player ", scopeOwner)
    local p = promise.new()

    print("State of promise ", p.state)

    print("^2TriggerScopeEvent ~ targets of ", scopeOwner)

    for i=1, #targets do
        local target = tonumber(targets[i])
        print(target)
    end

    print("^2TriggerScopeEvent ~ Check 3")

    for i=1, #targets do
        local target = tonumber(targets[i])
        -- print("scopeOwner ", scopeOwner, " is triggering event on ", target)
        TriggerClientEvent(event, target, payload)
    end

    print("^2TriggerScopeEvent ~ Check 4")

    if selfTrigger then
        scopeOwner = tonumber(scopeOwner)
        TriggerClientEvent(event, scopeOwner, payload)
    end

    print("^2TriggerScopeEvent ~ Check 5")

    if cb then cb() end

    print("^2TriggerScopeEvent ~ Check 6")

    p:resolve("Done")
    print("State of promise ", p.state, p.value)

    return p
end


-- function findArrayDifferences(dict1, dict2)
--     local diffs = {}

--     for key, value in pairs(dict1) do
--         if dict2[key] == nil then
--             diffs[key] = { type = "Removed", key = key, value = value }
--         else
--             local arrDiff = {}
--             for i, v in ipairs(value) do
--                 if dict2[key][i] == nil then
--                     arrDiff[i] = { type = "Removed", key = key, value = v }
--                 elseif dict2[key][i] ~= v then
--                     arrDiff[i] = { type = "Different", key = key, value1 = v, value2 = dict2[key][i] }
--                 end
--             end

--             if #dict2[key] > #value then
--                 for i = #value + 1, #dict2[key] do
--                     arrDiff[i] = { type = "Added", key = key, value = dict2[key][i] }
--                 end
--             end

--             if next(arrDiff) ~= nil then
--                 diffs[key] = arrDiff
--             end
--         end
--     end

--     for key, value in pairs(dict2) do
--         if dict1[key] == nil then
--             diffs[key] = { type = "Added", key = key, value = value }
--         end
--     end

--     if getKeysNumber(playersToTrack) == 0 then diffs = {} end
--     return diffs
-- end

-- local scop = {}

-- function changeScope(tab)
--     tab = scopes
--     print("^1changeScope ~ Changing scope called!")
--     -- dumpTable(scopes)
--     -- dumpTable(scop)
--     -- scop = scopes
--     -- print("^1changeScope ~ New scope!")
--     -- dumpTable(scop)
-- end



local oldScop = {}

function triggerCl(data)
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

-- -- TODO: HERE!
-- function triggerCl(data)
--     TriggerClientEvent(data.event, data.target, data.payload)
-- end

Citizen.CreateThread(function()
    print("Queuing Thread ~ Started!")
    -- local oldScop = {}
    -- Citizen.CreateThread(function()
    --     print("First!")
    --     local i = 0
    --     while true do
    --         i += 1
    --         -- print("^3Waiting... ", i, " sec")
    --         print("^3Checking scop")
    --         dumpTable(scop)
    --         if i == 17 then i = 0 end
    --         Wait(1000)
    --     end
    -- end)

    local tempT = {}

    local diffs = {}

    while true do
        -- print("^3 Thread ~ STARTED")
        -- print(json.encode(scopes, {indent = true}))
        -- print(json.encode(oldScop, {indent = true}))
        -- print("^3 Thread ~ Setting oldScop to scopes!!!!")

        -- local diff = findArrayDifferences(oldScop, scopes)

        -- local allKeys = getKeys(oldScop, scopes)


        -- if next(diff) ~= nil then
        --     print("DIFFS")
        --     print("-------------------------------")
        --     dumpTable(diff)
        --     print("-------------------------------")
        -- end

        -- for i=1, #allKeys do
        --     local key = allKeys[i]
        --     print("Checking Exepctions for Key: ", key)
        --     local tExc = except(oldScop[key], scopes[key])
        --     local tExc2 = except(scopes[key], oldScop[key])
        
        --     diffs[key] = {}
        
        --     -- if next(tExc) ~= nil and next(tExc2) == nil then
        --     --     print("Key has been removed completely")
        --     --     goto continue
        --     -- end
        
        --     for i=1, #tExc do
        --         -- diffs[#diffs+1] = { type = "Removed", key = key, value = tExc[i] }
        --         diffs[key][#diffs[key]+1] = { type = "Removed", key = key, value = tExc[i] }
        --         print("Content Removed", tExc[i])
        --     end
            
        --     for i=1, #tExc2 do
        --         print("Index analyzed ", i)
        --         diffs[key][#diffs[key]+1] = { type = "Added", key = key, value = tExc2[i] }
        --         -- diffs[#diffs+1] = { type = "Added", key = key, value = tExc2[i] }
        --         print("Content Added", tExc2[i])
        --     end
        
        --     -- ::continue::
        -- end
        

        -- local diffs = findArrayDifferences(oldScop, scopes)

        -- local diff = getDifferences(oldScop, scopes)

        -- for k,v in pairs(diff) do
        --     print("INTO DIFF LOOP")
        --     print("----------------------------------------------------")
        --     dumpTable(v)
        --     print("END TABLE!!!")
        --     local x = {}
        --     -- print("Exist? ", v.value and v.value or "More than 1 diff")
        --     -- print("Type is v ", type(v))
        --     -- TriggerClientEvent('table', 5, v)

        --     -- print("Check m ", m, type(m))

        --     -- TODO: Adapt the iteration of dictionary to be able to accept multiple input types and fill only 1 table with unique data to pass to a function to fill FunctQueue
        --     local eventsToFire = {}
        --     local newEvent
        --     local sEvent = {}

        --     tempT[k] = {}

        --     for x,y in pairs(v) do

        --         if not y.value then
        --             print("^8More than one value for id ", k)
        --             print("^7Analyzing x is now: ", x, " and his y is ", y)

        --             if x == "type" then
        --                 sEvent.type = x == "type" and y
        --                 tempT[k].type = y
        --             end

        --             if x == "key" then
        --                 sEvent.key = x == "key" and y
        --                 tempT[k].key = y
        --             end

        --             if x == "value" and type(y) == "table" then
        --                 -- print("Analyzing values of index ", k, "temptT exist for this ", tempT[k] and tempT[k] ~= {})
        --                 if not tempT[k].value then tempT[k].value = {} end

        --                 for i=1, #y do
        --                     tempT[k].value[#tempT[k].value+1] = y[i]
        --                     -- print("Value content is ", y[i], " and its ", tempT[k].type, " from id ", tempT[k].key)
        --                     -- sEvent.targets[#newEvent.targets+1] = y[i]
        --                 end
        --             end

        --         else

        --             -- TriggerClientEvent("mbt_malisling:syncScope", v[i].value, {
        --             --     tType = "add",
        --             --     playerSource = tonumber(v[i].key),
        --             --     playerWeapons = playersToTrack[tonumber(v[i].key)]
        --             -- })

        --             -- TriggerClientEvent("mbt_malisling:syncScope", tonumber(v[i].value), {
        --             --     tType = "del",
        --             --     playerSource = tonumber(v[i].key)
        --             -- })

        --             print("^8Only one value for id ", k)
        --             print("^7")
        --             -- print(x, y.key, y.type, y.value)

        --             print("Adding DIO funct to target ", y.key, " and source ", y.value)

        --             functQueue[#functQueue+1] = {
        --                 funct = triggerCl,
        --                 args = {
        --                     event = "mbt_malisling:syncScope",
        --                     target = tonumber(y.key),
        --                     payload = {
        --                         tType = y.type == "Removed" and "del" or "add",
        --                         playerSource = tonumber(y.value),
        --                         playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.value)] or nil
        --                     }
        --                 }
        --             }

        --             -- print("Added ADD syncScope to functQueue - target ", y.key)
        --             -- print("Adding PORCO funct to target ", y.value, " and source ", y.key)


        --             -- functQueue[#functQueue+1] = {
        --             --     funct = triggerCl,
        --             --     args = {
        --             --         event = "mbt_malisling:syncScope",
        --             --         target = tonumber(y.value),
        --             --         payload = {
        --             --             tType = y.type == "Removed" and "del" or "add",
        --             --             playerSource = tonumber(y.key),
        --             --             playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.key)] or nil
        --             --         }
        --             --     }
        --             -- }
        --         end

        --         -- dumpTable(tempT)


        --         -- if y.value and type(y.value) == "table" then
        --         --     for i=1, #y.value do
        --         --         print("Value content is ", y.value[i])
        --         --     end
        --         -- end
        --     end

        --     dumpTable(tempT)
        --     print("PORCO PORCO")
        --     print("----------------------------------------------------------------------------------------------")
        --     print(tempT)
        --     print(tempT ~= {})

        --     if tempT and tempT ~= {} and hasValue(tempT) then

        --         print("Puttana")
        --         dumpTable(tempT)
        --         print("Maiale")

        --         for x, y in pairs(tempT) do
        --             -- local type = m.type

        --             -- print(x, y)
        --             -- print("Reading key ", x)
        --             -- print(y.key, y.type, y.value)

        --             if y and next(y) ~= nil then

        --                 for i=1, #y.value do
        --                     local t = y.value[i]

        --                     print("Adding DIO funct to target ", y.key, " and source ", t)

        --                     functQueue[#functQueue+1] = {
        --                         funct = triggerCl,
        --                         args = {
        --                             event = "mbt_malisling:syncScope",
        --                             target = tonumber(y.key),
        --                             payload = {
        --                                 tType = y.type == "Removed" and "del" or "add",
        --                                 playerSource = tonumber(t),
        --                                 playerWeapons = y.type == "Added" and playersToTrack[tonumber(t)] or nil
        --                             }
        --                         }
        --                     }

        --                     -- functQueue[#functQueue+1] = {
        --                     --     funct = triggerCl,
        --                     --     args = {
        --                     --         event = "mbt_malisling:syncScope",
        --                     --         target = tonumber(t),
        --                     --         payload = {
        --                     --             tType = y.type == "Removed" and "del" or "add",
        --                     --             playerSource = tonumber(y.key),
        --                     --             playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.key)] or nil
        --                     --         }
        --                     --     }
        --                     -- }
        --                 end
        --             end


        --             -- if n == "value" and type(n) == "table" then
        --             --     local key,
        --             --     for i=1, #m do
        --             --         functQueue[#functQueue+1] = {
        --             --         funct = triggerCl,
        --             --         args = {
        --             --             event = "mbt_malisling:syncScope",
        --             --             target = tonumber(m.key),
        --             --             payload = y{
        --             --                 tType = .type == "Removed" and "del" or "add",
        --             --                 playerSource = tonumber(v[i].value),
        --             --                 playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.value)] or nil
        --             --             }
        --             --         }
        --             --     }
        --             --     end
        --             -- end

        --             -- for i=1, #m do

        --             --     functQueue[#functQueue+1] = {
        --             --     funct = triggerCl,
        --             --     args = {
        --             --         event = "mbt_malisling:syncScope",
        --             --         target = tonumber(y.key),
        --             --         payload = y{
        --             --             tType = .type == "Removed" and "del" or "add",
        --             --             playerSource = tonumber(v[i].value),
        --             --             playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.value)] or nil
        --             --         }
        --             --     }
        --             -- }
        --             -- end

        --         end
        --     end

        --     print(json.encode(tempT[k], {indent = true}))


        --     -- if v.value then
        --     --     print("More than one value for id ", k)
        --     --     -- This is more than 1 change
        --     --     for n,m in pairs(v) do
        --     --         if n == "value" and type(m) == "table"	then
        --     --             for i=1, #m do
        --     --                 print("Value content is ", m[i])
        --     --             end
        --     --         else
        --     --             print(n, " is ", m)
        --     --         end
        --     --         -- print("Value table is type ", type(m.value))
        --     --         -- print(n, json.encode(m, {indent = true}))
        --     --         -- print(n, type(n))
        --     --         -- print(m, type(m))
        --     --     end
        --     -- end
        --         print("----------------------------------------------------")
        -- end

        local diffs = getDifferences(oldScop, scopes)

        for source, values in pairs(diffs) do
            for i=1, #values do
                print("Key: ", source, "Type: ", values[i].type, "Value: ", values[i].value)

                functQueue[#functQueue+1] = {
                    funct = triggerCl,
                    args = {
                        event = "mbt_malisling:syncScope",
                        target = tonumber(values[i].value),
                        payload = {
                            tType = values[i].type == "Removed" and "del" or "add",
                            playerSource = tonumber(source),
                            playerWeapons = values[i].type == "Added" and playersToTrack[tonumber(source)] or nil
                        }
                    }
                }
            end
        end


        -- print(json.encode(diff, {indent = true}))
        oldScop = tableDeepCopy(scopes)
        -- print("^3 Thread ~ oldScop set NOW!!!!!")
        -- changeScope(oldScop)
        Citizen.Wait(100)
    end
end)

Citizen.CreateThread(function()
    local availableIndex = 0
    local isBusy = false

    while true do
        Wait(200)
        -- if #arr < 1 then print("NO FUNCT IN QUEUE") end

        if #functQueue > 0 then
            -- for i=1, #arr do
            --     if arr[i] then availableIndex = i break end
            -- end

            -- print("AVAILABLE INDEX ", availableIndex)
            if isBusy then print("BUSY") end
            if not isBusy and functQueue[1] then
                isBusy = true
                local qElement = functQueue[1]

                print("aSync thread ~ Executing function ", qElement.args.event, " with target ", qElement.args.target, " and payload ", json.encode(qElement.args.payload))
                local ps = Citizen.Await(qElement.funct(qElement.args))
                table.remove(functQueue, 1)
                print("aSync thread ~ Resolved process event ", qElement.args.event, " Promise: ", ps)
                isBusy = false
            end

        end
    end
end)

-- Thread to store scopes in a variable and check if it's changed

RegisterCommand("scopes", function (source, args, raw)
    for k,v in pairs(scopes) do
        print(k, json.encode(v))
    end

    -- for k,v in pairs(oldScop) do
    --     print(k, json.encode(v))
    -- end
end)


RegisterCommand("podio", function (source, args, raw)
    print("OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO ", GetPlayerPed(source))

end)




-- RegisterCommand("loji", function()
--     local scopes = {
--         ["1"] = {2},
--         ["2"] = {1}
--     }

--     local oldScop = {
--         ["1"] = {2,3},
--         ["2"] = {1,3},
--         ["3"] = {1,2}
--     }

--     local diff = findArrayDifferences(oldScop, scopes)
--     local tempT = {}

--     -- dumpTable(diff)




--     for k,v in pairs(diff) do
--         print("INTO DIFF LOOP")
--         print("----------------------------------------------------")
--         dumpTable(v)
--         print("END TABLE!!!")
--         local x = {}
--         -- print("Exist? ", v.value and v.value or "More than 1 diff")
--         -- print("Type is v ", type(v))
--         -- TriggerClientEvent('table', 5, v)

--         -- print("Check m ", m, type(m))

--         -- TODO: Adapt the iteration of dictionary to be able to accept multiple input types and fill only 1 table with unique data to pass to a function to fill FunctQueue
--         local eventsToFire = {}
--         local newEvent
--         local sEvent = {}

--         tempT[k] = {}

--         for x,y in pairs(v) do

--             if not y.value then
--                 -- print("More than one value for id ", k)
--                 print("Analyzing x is now: ", x, " and his y is ", y)

--                 if x == "type" then
--                     sEvent.type = x == "type" and y
--                     tempT[k].type = y
--                 end

--                 if x == "key" then
--                     sEvent.key = x == "key" and y
--                     tempT[k].key = y
--                 end

--                 if x == "value" and type(y) == "table" then
--                     -- print("Analyzing values of index ", k, "temptT exist for this ", tempT[k] and tempT[k] ~= {})
--                     if not tempT[k].value then tempT[k].value = {} end

--                     for i=1, #y do
--                         tempT[k].value[#tempT[k].value+1] = y[i]
--                         -- print("Value content is ", y[i], " and its ", tempT[k].type, " from id ", tempT[k].key)
--                         -- sEvent.targets[#newEvent.targets+1] = y[i]
--                     end
--                 end


--             else

--                 -- TriggerClientEvent("mbt_malisling:syncScope", v[i].value, {
--                 --     tType = "add",
--                 --     playerSource = tonumber(v[i].key),
--                 --     playerWeapons = playersToTrack[tonumber(v[i].key)]
--                 -- })

--                 -- TriggerClientEvent("mbt_malisling:syncScope", tonumber(v[i].value), {
--                 --     tType = "del",
--                 --     playerSource = tonumber(v[i].key)
--                 -- })

--                 print("Only one value for id ", k)
--                 print(x, y.key, y.type, y.value)

--                 functQueue[#functQueue+1] = {
--                     funct = triggerCl,
--                     args = {
--                         event = "mbt_malisling:syncScope",
--                         target = tonumber(y.key),
--                         payload = {
--                             tType = y.type == "Removed" and "del" or "add",
--                             playerSource = tonumber(y.value),
--                             playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.value)] or nil
--                         }
--                     }
--                 }

--                 print("Added ADD syncScope to functQueue - target ", y.key)

--                 functQueue[#functQueue+1] = {
--                     funct = triggerCl,
--                     args = {
--                         event = "mbt_malisling:syncScope",
--                         target = tonumber(y.value),
--                         payload = {
--                             tType = y.type == "Removed" and "del" or "add",
--                             playerSource = tonumber(y.key),
--                             playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.key)] or nil
--                         }
--                     }
--                 }
--             end

--             dumpTable(tempT)


--             -- if y.value and type(y.value) == "table" then
--             --     for i=1, #y.value do
--             --         print("Value content is ", y.value[i])
--             --     end
--             -- end
--         end

--         print("PORCO PORCO")
--         print("----------------------------------------------------------------------------------------------")

--         if tempT and tempT ~= {} then

--             dumpTable(tempT)

--             for x, y in pairs(tempT) do
--                 -- local type = m.type

--                 -- print(x, y)
--                 print("Reading key ", x)
--                 print(y.key, y.type, y.value)

--                 if y and next(y) ~= nil then

--                     for i=1, #y.value do
--                         local t = y.value[i]

--                         functQueue[#functQueue+1] = {
--                             funct = triggerCl,
--                             args = {
--                                 event = "mbt_malisling:syncScope",
--                                 target = tonumber(y.key),
--                                 payload = {
--                                     tType = y.type == "Removed" and "del" or "add",
--                                     playerSource = tonumber(t),
--                                     playerWeapons = y.type == "Added" and playersToTrack[tonumber(t)] or nil
--                                 }
--                             }
--                         }

--                         functQueue[#functQueue+1] = {
--                             funct = triggerCl,
--                             args = {
--                                 event = "mbt_malisling:syncScope",
--                                 target = tonumber(t),
--                                 payload = {
--                                     tType = y.type == "Removed" and "del" or "add",
--                                     playerSource = tonumber(y.key),
--                                     playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.key)] or nil
--                                 }
--                             }
--                         }
--                     end
--                 end


--                 -- if n == "value" and type(n) == "table" then
--                 --     local key,
--                 --     for i=1, #m do
--                 --         functQueue[#functQueue+1] = {
--                 --         funct = triggerCl,
--                 --         args = {
--                 --             event = "mbt_malisling:syncScope",
--                 --             target = tonumber(m.key),
--                 --             payload = y{
--                 --                 tType = .type == "Removed" and "del" or "add",
--                 --                 playerSource = tonumber(v[i].value),
--                 --                 playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.value)] or nil
--                 --             }
--                 --         }
--                 --     }
--                 --     end
--                 -- end

--                 -- for i=1, #m do

--                 --     functQueue[#functQueue+1] = {
--                 --     funct = triggerCl,
--                 --     args = {
--                 --         event = "mbt_malisling:syncScope",
--                 --         target = tonumber(y.key),
--                 --         payload = y{
--                 --             tType = .type == "Removed" and "del" or "add",
--                 --             playerSource = tonumber(v[i].value),
--                 --             playerWeapons = y.type == "Added" and playersToTrack[tonumber(y.value)] or nil
--                 --         }
--                 --     }
--                 -- }
--                 -- end

--             end
--         end

--         print(json.encode(tempT[k], {indent = true}))


--         -- if v.value then
--         --     print("More than one value for id ", k)
--         --     -- This is more than 1 change
--         --     for n,m in pairs(v) do
--         --         if n == "value" and type(m) == "table"	then
--         --             for i=1, #m do
--         --                 print("Value content is ", m[i])
--         --             end
--         --         else
--         --             print(n, " is ", m)
--         --         end
--         --         -- print("Value table is type ", type(m.value))
--         --         -- print(n, json.encode(m, {indent = true}))
--         --         -- print(n, type(n))
--         --         -- print(m, type(m))
--         --     end
--         -- end
--             print("----------------------------------------------------")
--     end

-- end, false)


