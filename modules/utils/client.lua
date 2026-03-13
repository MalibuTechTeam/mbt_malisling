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
    local hasFlash = false
    for i=1, #compList do
        hasFlash = HasPedGotWeaponComponent(ped, joaat(weaponHash), compList[i])
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

return Utils
