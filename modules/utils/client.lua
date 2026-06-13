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

---@param ... any
function Utils.mbtDebugger(...)
    if not MBT.Debug then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = _serialize(select(i, ...))
    end
    print(("^2[%s]^7 ^3%s^7 >> %s^0"):format(_resName, _callerLoc(2), table.concat(parts, " ")))
end

---@param ... any
function Utils.mbtWarn(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = _serialize(select(i, ...))
    end
    print(("^2[%s] ^8[WARN]^7 ^3%s^7 >> %s^0"):format(_resName, _callerLoc(2), table.concat(parts, " ")))
end

---@param s string
---@return boolean
function Utils.isWeapon(s)
    return string.sub(s, 1, 7) == "WEAPON_"
end

---@param t table
---@return integer
function Utils.getTableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

---@param t table
---@return boolean
function Utils.isTableEmpty(t)
    return next(t) == nil
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

---@param ped number
---@param weaponHash any
---@param compList any
---@return boolean
function Utils.weaponHasFlashlight(ped, weaponHash, compList)
    -- Defensive: on some holster/disarm transitions the weapon name is nil before
    -- the next currentWeapon update — joaat(nil) would hard-error.
    if not weaponHash or type(compList) ~= 'table' then return false end
    local hash = (type(weaponHash) == 'number') and weaponHash or joaat(weaponHash)
    local hasFlash = false
    for i=1, #compList do
        hasFlash = HasPedGotWeaponComponent(ped, hash, compList[i])
        if hasFlash then break end
    end
    return hasFlash == 1
end

---@param componentName any
---@return boolean
function Utils.isComponentAFlashlight(componentName)
    return componentName == "at_flashlight"
end

---@param d number
local function getChance(d)
    local prevKey = nil
    local orderedPairs = function(t, compareFunc)
        local keys = {}
        for key, _ in pairs(t) do
            table.insert(keys, key)
        end
        table.sort(keys, compareFunc)
        local i = 0
        return function()
            i = i + 1
            local key = keys[i]
            if key then return key, t[key] end
        end
    end

    for key in orderedPairs(MBT.Jamming["Chance"], function(a, b) return a > b end) do
        if prevKey and d > key and d < prevKey then
            return MBT.Jamming["Chance"][prevKey]
        end
        prevKey = key
    end
    return 0
end

---@param value any
---@return unknown
function Utils.getJammingChance(value)
    local chance = getChance(value)
    math.randomseed(GetGameTimer() * math.random(30568, 90214))
    local random = math.random(1, 100)
    Utils.mbtDebugger("random is ", random, "chance is ", chance)
    return random < chance
end

--- Map a weapon's durability (0-100) to a discrete condition tier 1-5
--- (5 = pristine, 1 = damaged). Single source of truth for the shooting bridge
--- export GetWeaponCondition and any condition HUD. Derived on read — no second
--- metadata field to keep in sync with durability.
---@param durability number?
---@return integer? tier  1..5, or nil if durability is unknown
function Utils.durabilityToTier(durability)
    if type(durability) ~= 'number' then return nil end
    if durability >= 85 then return 5 end
    if durability >= 60 then return 4 end
    if durability >= 35 then return 3 end
    if durability >= 10 then return 2 end
    return 1
end

