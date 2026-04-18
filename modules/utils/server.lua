Utils = {}

local _resName = GetCurrentResourceName()

local function _prettyTable(t, indent)
    indent = indent or 1
    local pad = string.rep("  ", indent)
    local lines = {}
    for k, v in pairs(t) do
        local key = type(k) == "number" and ("[" .. k .. "]") or tostring(k)
        if type(v) == "table" then
            lines[#lines+1] = pad .. key .. " = " .. _prettyTable(v, indent + 1)
        else
            lines[#lines+1] = pad .. key .. " = " .. tostring(v)
        end
    end
    return "{\n" .. table.concat(lines, ",\n") .. "\n" .. string.rep("  ", indent - 1) .. "}"
end

local function _serialize(v)
    if type(v) == "table" then return _prettyTable(v) end
    return tostring(v)
end

local function _callerLoc(level)
    local info = debug.getinfo(level, "Sl")
    if not info then return "?" end
    local src = info.short_src:gsub("^@@?[^/\\]+[/\\]", "")
    return src .. ":" .. (info.currentline or "?")
end

local function _timestamp()
    return os.date("%H:%M:%S") .. " "
end

---@param ... any
function Utils.mbtDebugger(...)
    if not MBT.Debug then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = _serialize(select(i, ...))
    end
    print(("^2[%s]^7 ^3%s%s^7 >> %s^0"):format(_resName, _timestamp(), _callerLoc(2), table.concat(parts, " ")))
end

---@param ... any
function Utils.mbtWarn(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = _serialize(select(i, ...))
    end
    print(("^2[%s] ^8[WARN]^7 ^3%s%s^7 >> %s^0"):format(_resName, _timestamp(), _callerLoc(2), table.concat(parts, " ")))
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
        Utils.mbtWarn(('no datafile found at path %s'):format(path:gsub('@@', '')))
        return {}
    end

    local func, err = load(datafile, path)

    if not func or err then
        Utils.mbtWarn(('failed to load datafile %s'):format(path:gsub('@@', '')))
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

