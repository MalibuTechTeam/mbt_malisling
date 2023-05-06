-- function debugTrace(t)
--     -- assert(type(t) == "string", "Arg is not a string!")
--     if Config.Debug then
--         if t then
--             print("DEBUG | "..t.." [Type: "..type(t).."]") 
--         else
--             print("Trying to print a nil value!!")
--         end 
--     end
-- end


function debugTrace(...)
    if Config.Debug then
        for i,arg in ipairs{...} do
            if type(arg) == "table" then
                dumpTable(arg)
            else
                print(arg)
            end
        end
    end
end

function isComponentASkin(compName)
    local s, e = string.find(compName, "skin")
    if s and e then return true else return false end	   
end

function dumpTable(t, indent)
    -- if Config.Debug then 
        indent = indent or 0
        for k,v in pairs(t) do
            local formatting = string.rep("    ", indent) .. k .. ": "
            if type(v) == "table" then
                print(formatting)
                dumpTable(v, indent + 1)
            else
                print(formatting .. tostring(v))
            end
        end
    -- end
end

function table_print (tt, indent, done)
    done = done or {}
    indent = indent or 0
    if type(tt) == "table" then
      local sb = {}
      for key, value in pairs (tt) do
        table.insert(sb, string.rep (" ", indent)) -- indent it
        if type (value) == "table" and not done [value] then
          done [value] = true
          table.insert(sb, "{\n");
          table.insert(sb, table_print (value, indent + 2, done))
          table.insert(sb, string.rep (" ", indent)) -- indent it
          table.insert(sb, "}\n");
        elseif "number" == type(key) then
          table.insert(sb, string.format("\"%s\"\n", tostring(value)))
        else
          table.insert(sb, string.format(
              "%s = \"%s\"\n", tostring (key), tostring(value)))
         end
      end
      print(table.concat(sb))
    else
      print(tt .. "\n")
    end
end
  


function loadData (data)
    -- Config.Weapons = data.WeaponsData
    -- Config.WeaponsInfo = data.WeaponsInfo

    -- for k, v in pairs(Config) do
    --     print(k, v)
    -- end
end

function isWeapon (s)
    return string.sub(s, 1, 7) == "WEAPON_"
end

function requestModel (m)
    RequestModel(m)
	while not HasModelLoaded(m) do Wait(0) end
end

function getTableLength (t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end
  
function isTableEmpty(t)
    return next(t) == nil
end

function containsValue(array, value)
    for i=1, #array do
        if array[i] == value then 
            return true, i 
        end
    end
    return nil
end

function data(name)
    local resourceName = GetCurrentResourceName()
	local file = ('data/%s.lua'):format(name)
	local datafile = LoadResourceFile(resourceName, file)
	local path = ('@@%s/data/%s'):format(resourceName, file)

	if not datafile then
		warn(('no datafile found at path %s'):format(path:gsub('@@', '')))
		return {}
	end

	local func, err = load(datafile, path)

    print(err)

	if not func or err then
		warn(('failed to load datafile %s'):format(path:gsub('@@', '')))
        return
	end

	return func()
end
  

function requestWeaponAsset(weaponHash, cb)
	if not HasWeaponAssetLoaded(weaponHash) then
		RequestWeaponAsset(weaponHash)

		while not HasWeaponAssetLoaded(weaponHash) do
			Wait(0)
		end
	end

	if cb ~= nil then
		cb()
	end
end

function handleSling(data)
    TriggerServerEvent("mbt_malisling:syncSling", data)
end