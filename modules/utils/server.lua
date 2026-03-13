local Utils = {}

---@param t table
---@param indent boolean
function Utils.dumpTable(t, indent)
    if MBT.Debug then
        indent = indent or 0
        for k,v in pairs(t) do
            local formatting = string.rep("    ", indent) .. k .. ": "
            if type(v) == "table" then
                print(formatting)
                Utils.dumpTable(v, indent + 1)
            else
                print(formatting .. tostring(v))
            end
        end
    end
end

function Utils.mbtDebugger(...)
    if MBT.Debug then
        local args = {...}
        local printResult = "^3[mbt_malisling] | "
        for i, arg in ipairs(args) do
            if type(arg) == "table" then
                Utils.dumpTable(arg)
            else
                printResult = printResult .. tostring(arg) .. "\t"
            end
        end
        printResult = printResult .. "\n"
        print(printResult)
    end
end

---@param array table
---@param value any
---@return boolean
---@return integer
function Utils.containsValue(array, value)
    for i=1, #array do
        if array[i] == value then
            return true, i
        end
    end
    return false, -1
end

---@param t table
---@return table
function Utils.tableDeepCopy(t)
    local copy = {}

    for k, v in pairs(t) do
        if type(v) == "table" then
            v = Utils.tableDeepCopy(v)
        end
        copy[k] = v
    end

    return copy
end

---@param name string
---@return table
function Utils.data(name)
    local resourceName = GetCurrentResourceName()
    local file = ('data/%s.lua'):format(name)
    local datafile = LoadResourceFile(resourceName, file)
    local path = ('@@%s/data/%s'):format(resourceName, file)

    if not datafile then
        warn(('no datafile found at path %s'):format(path:gsub('@@', '')))
        return {}
    end

    local func, err = load(datafile, path)

    if not func or err then
        warn(('failed to load datafile %s'):format(path:gsub('@@', '')))
        return
    end

    return func()
end

---@param t1 table
---@param t2 table
---@return table
local function except(t1, t2)
    local final, temp = {}, {}
    if not t1 then t1 = {} end
    if not t2 then t2 = {} end

    for i=1, #t2 do temp[t2[i]] = true end

    for i=1, #t1 do
        if not temp[t1[i]] then
            final[#final+1] = t1[i]
        end
    end

    return final
end

---@param table table
---@param element any
---@return boolean
local function contains(t, element)
    for _, value in pairs(t) do
        if value == element then return true end
    end
    return false
end

---@param t1 table
---@param t2 table
---@return table
local function getKeys(t1, t2)
    local keys = {}
    for key in pairs(t1) do keys[#keys+1] = key end

    for key in pairs(t2) do
        if not contains(keys, key) then keys[#keys+1] = key end
    end

    table.sort(keys, function(a, b) return a < b end)
    return keys
end

---@param t1 table
---@param t2 table
---@return table
function Utils.getDifferences(t1, t2)
    local allKeys = getKeys(t1, t2)
    local diffs = {}

    for i=1, #allKeys do
        local key = allKeys[i]
        local tExc = except(t1[key], t2[key])
        local tExc2 = except(t2[key], t1[key])

        diffs[key] = {}
        for i=1, #tExc do
            diffs[key][#diffs[key]+1] = { type = "Removed", key = key, value = tExc[i] }
            Utils.mbtDebugger("getDifferences ~ Content Removed", tExc[i])
        end

        for i=1, #tExc2 do
            Utils.mbtDebugger("getDifferences ~ Index analyzed ", i)
            diffs[key][#diffs[key]+1] = { type = "Added", key = key, value = tExc2[i] }
            Utils.mbtDebugger("getDifferences ~ Content Added", tExc2[i])
        end
    end

    return diffs
end

return Utils
