function getKeys(t1, t2)
    local keys = {}

    local function contains(table, element)
        for _, value in pairs(table) do
            if value == element then
                return true
            end
        end
        return false
    end

    for key in pairs(t1) do
        keys[#keys+1] = key
    end

    for key in pairs(t2) do
        if not contains(keys, key) then
            keys[#keys+1] = key
        end
    end

    table.sort(keys, function (a, b) return a < b end)

    return keys
end

function except(t1,t2)
    local final, temp = {}, {}
    if not t1 then t1 = {} end
    if not t2 then t2 = {} end

    for i=1, #t2 do temp[t2[i]] = true; end
    
    for i=1,#t1 do
        if not temp[t1[i]] then
            final[#final+1] = t1[i]
        end
    end
    
    return final
end

function hasValue(t)
    
    for k, v in pairs(t) do
        if v ~= nil and next(v) ~= nil then
            return true        
        end
    end
end

function getKeysNumber(t)
    local c = 0
    for k, v in pairs(t) do
        c += 1
    end
    return c
end

function getDifferences(t1, t2)

    local allKeys = getKeys(t1, t2)
    local diffs = {}

    for i=1, #allKeys do
        local key = allKeys[i]
        -- print("Checking Exepctions for Key: ", key)
        local tExc = except(t1[key], t2[key])
        local tExc2 = except(t2[key], t1[key])
    
        diffs[key] = {}
    
        -- if next(tExc) ~= nil and next(tExc2) == nil then
        --     print("Key has been removed completely")
        --     goto continue
        -- end
    
        for i=1, #tExc do
            -- diffs[#diffs+1] = { type = "Removed", key = key, value = tExc[i] }
            diffs[key][#diffs[key]+1] = { type = "Removed", key = key, value = tExc[i] }
            print("Content Removed", tExc[i])
        end
        
        for i=1, #tExc2 do
            print("Index analyzed ", i)
            diffs[key][#diffs[key]+1] = { type = "Added", key = key, value = tExc2[i] }
            -- diffs[#diffs+1] = { type = "Added", key = key, value = tExc2[i] }
            print("Content Added", tExc2[i])
        end
    
    end

    return diffs
end

function tableDeepCopy (t)
    local copy = {}

	for k, v in pairs(t) do
		if type(v) == "table" then
			v = tableDeepCopy(v)
        end

		copy[k] = v
    end

	return copy
end
