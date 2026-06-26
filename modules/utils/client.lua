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

---@param s string
---@return boolean
function Utils.isWeapon(s)
    -- Case-insensitive: qb-inventory weapon item names are lowercase
    -- ('weapon_pistol'); ox + GTA hashes + MBT.WeaponsInfo are uppercase.
    return type(s) == "string" and string.upper(string.sub(s, 1, 7)) == "WEAPON_"
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

    -- A weapon with unknown durability (e.g. a qb-inventory item with no info.quality) gives
    -- d = nil — guard before the comparisons below, which would otherwise error on `nil > key`.
    if type(d) ~= 'number' then return 0 end
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

