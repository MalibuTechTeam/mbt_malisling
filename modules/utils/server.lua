Utils = {}

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
function Utils.getDifferences(t1, t2)
    local diffs = {}

    -- Build unified key set in O(n+m) using hash dedup
    local allKeys = {}
    for key in pairs(t1) do allKeys[key] = true end
    for key in pairs(t2) do allKeys[key] = true end

    for key in pairs(allKeys) do
        local a = t1[key] or {}
        local b = t2[key] or {}

        -- Build lookup tables for a single comparison pass
        local inB = {}
        for i = 1, #b do inB[b[i]] = true end
        local inA = {}
        for i = 1, #a do inA[a[i]] = true end

        local entry = nil

        for i = 1, #a do
            if not inB[a[i]] then
                if not entry then entry = {} end
                entry[#entry+1] = { type = "Removed", key = key, value = a[i] }
                Utils.mbtDebugger("getDifferences ~ Content Removed", a[i])
            end
        end

        for i = 1, #b do
            if not inA[b[i]] then
                if not entry then entry = {} end
                entry[#entry+1] = { type = "Added", key = key, value = b[i] }
                Utils.mbtDebugger("getDifferences ~ Content Added", b[i])
            end
        end

        if entry then diffs[key] = entry end
    end

    return diffs
end

