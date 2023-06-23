local utils = {}

---@param t table
---@param indent boolean
function utils.dumpTable(t, indent)
    if MBT.Debug then
        indent = indent or 0
        for k,v in pairs(t) do
            local formatting = string.rep("    ", indent) .. k .. ": "
            if type(v) == "table" then
                print(formatting)
                utils.dumpTable(v, indent + 1)
            else
                print(formatting .. tostring(v))
            end
        end
    end
end

function utils.mbtDebugger(...)
    if MBT.Debug then
        local args = {...}
        local printResult = "^3[mbt_malisling] | "
        for i, arg in ipairs(args) do
            if type(arg) == "table" then
                utils.dumpTable(arg)
            else
                printResult = printResult .. tostring(arg) .. "\t"
            end
        end
        printResult = printResult .. "\n"
        print(printResult)
    end
end

---@param compName string
---@return boolean
function utils.isComponentASkin(compName)
    local s, e = string.find(compName, "skin")
    if s and e then return true else return false end
end


---@param s string
---@return boolean
function utils.isWeapon (s)
    return string.sub(s, 1, 7) == "WEAPON_"
end

---@param t table
---@return integer
function utils.getTableLength (t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

---@param t table
---@return boolean
function utils.isTableEmpty(t)
    return next(t) == nil
end

---@param array table
---@param value any
---@return boolean
---@return integer
function utils.containsValue(array, value)
    for i=1, #array do
        if array[i] == value then
            return true, i
        end
    end
    return false, -1
end

---@param name string
---@return table
function utils.data(name)
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

---https://github.com/DeannaTD
---@param t1 table
---@param t2 table
---@return table
function utils.except(t1,t2)
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

---@param table table
---@param element any
---@return boolean
function utils.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

---@param t1 table
---@param t2 table
---@return table
function utils.getKeys(t1, t2)
    local keys = {}
    for key in pairs(t1) do
        keys[#keys+1] = key
    end

    for key in pairs(t2) do
        if not utils.contains(keys, key) then
            keys[#keys+1] = key
        end
    end

    table.sort(keys, function (a, b) return a < b end)

    return keys
end

---@param t table
---@return boolean
function utils.hasValue(t)

    for k, v in pairs(t) do
        if v ~= nil and next(v) ~= nil then
            return true
        end
    end
end

---@param t table
---@return integer
function utils.getKeysNumber(t)
    local c = 0
    for _ in pairs(t) do c += 1; end
    return c
end

---@param t1 table
---@param t2 table
---@return table
function utils.getDifferences(t1, t2)

    local allKeys = utils.getKeys(t1, t2)
    local diffs = {}

    for i=1, #allKeys do
        local key = allKeys[i]
        local tExc = utils.except(t1[key], t2[key])
        local tExc2 = utils.except(t2[key], t1[key])

        diffs[key] = {}
        for i=1, #tExc do
            diffs[key][#diffs[key]+1] = { type = "Removed", key = key, value = tExc[i] }
            utils.mbtDebugger("getDifferences ~ Content Removed", tExc[i])
        end

        for i=1, #tExc2 do
            utils.mbtDebugger("getDifferences ~ Index analyzed ", i)
            diffs[key][#diffs[key]+1] = { type = "Added", key = key, value = tExc2[i] }
            utils.mbtDebugger("getDifferences ~ Content Added", tExc2[i])
        end

    end

    return diffs
end

---@param t table
---@return table
function utils.tableDeepCopy (t)
    local copy = {}

	for k, v in pairs(t) do
		if type(v) == "table" then
			v = utils.tableDeepCopy(v)
        end

		copy[k] = v
    end

	return copy
end

---@param ped any
---@param weaponHash any
---@param compList any
---@return boolean
function utils.weaponHasFlashlight(ped, weaponHash, compList)
    local hasFlash = false
    for i=1, #compList do
        hasFlash = HasPedGotWeaponComponent(ped, joaat(weaponHash), compList[i])
        if hasFlash then break end
    end
    return hasFlash == 1
end

---@param t table
---@param compareFunc function
---@return function
local function orderedPairs(t, compareFunc)
    local keys = {}
    for key, _ in pairs(t) do
        table.insert(keys, key)
    end
    table.sort(keys, compareFunc)

    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key then
            return key, t[key]
        end
    end
end


---@param d number
local function getChance(d)
    local prevKey = nil
    for key in orderedPairs(MBT.Jamming["Chance"], function (a, b)  return a > b; end) do
        if prevKey and d > key and d < prevKey then
            return MBT.Jamming["Chance"][prevKey]
        end
        prevKey = key
    end
    return 0
end

---@param value any
---@return unknown
function utils.getJammingChance(value)
    local chance = getChance(value)
    math.randomseed(GetGameTimer() * math.random(30568, 90214))
    local random = math.random(1, 100)
    utils.mbtDebugger("random is ", random, "chance is ", chance)
    return random < chance
end

---@param ped number
---@return string
function utils.getPedSex(ped)
    local pedModel = GetEntityModel(ped)
    local pedSex

    if pedModel == `mp_m_freemode_01` then
        pedSex = "male"
    elseif pedModel == `mp_f_freemode_01` then
        pedSex = "female"
    else
        pedSex = IsPedMale(ped) and "male" or "female"
    end

    return pedSex
end

---@param componentName any
---@return boolean
function utils.isComponentAFlashlight(componentName)
    return componentName == "at_flashlight"
end
return utils


