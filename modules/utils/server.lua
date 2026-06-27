Utils = {}

-- Logging — the canonical leveled logger lives in modules/utils/logger.lua
-- (shared_script, loaded before this). Alias it onto Utils so the existing call
-- sites keep working; new code can use Utils.Debug/Info/Warn/Error directly.
Utils.Debug = MBTLog.Debug
Utils.Info  = MBTLog.Info
Utils.Warn  = MBTLog.Warn
Utils.Error = MBTLog.Error
Utils.mbtDebugger = MBTLog.Debug   -- back-compat alias (lowercase, malisling call sites)
Utils.mbtWarn     = MBTLog.Warn    -- back-compat alias

---Refuse to run under a renamed folder (the usual clone-and-rebrand). Prints a console
---error and returns false when the resource isn't named expectedName.
---@param expectedName string
---@return boolean ok
function Utils.MbtResourceNameCheck(expectedName)
    local actual = GetCurrentResourceName()
    if actual == expectedName then return true end
    print(('^1[MalibuTech] ERROR: This resource must be named "%s"!^0'):format(expectedName))
    print(('^1[MalibuTech] Current folder name: "%s" — please rename it and restart.^0'):format(actual))
    return false
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

---Weapon type ('side'/'back'/'back2'/'melee'…) for a canonical WEAPON_ name, or nil.
---@param name string?
---@return string?
function Utils.weaponType(name)
    local w = name and MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]
    return w and w.type
end

---True if n is a real number within sane world-coordinate bounds (rejects NaN/inf and
---absurd magnitudes) — the guard for coords arriving over net events.
---@param n any
---@return boolean
function Utils.finite(n)
    return type(n) == 'number' and n == n and n > -1e6 and n < 1e6
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

