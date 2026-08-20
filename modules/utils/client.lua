Utils = {}

-- Logging — canonical logger lives in modules/utils/logger.lua (shared_script,
-- loaded first). Aliased onto Utils so existing call sites keep working.
Utils.Debug = MBTLog.Debug
Utils.Info  = MBTLog.Info
Utils.Warn  = MBTLog.Warn
Utils.Error = MBTLog.Error
Utils.mbtDebugger = MBTLog.Debug   -- back-compat alias (lowercase, malisling call sites)
Utils.mbtWarn     = MBTLog.Warn    -- back-compat alias

---@param s string
---@return boolean
function Utils.isWeapon(s)
    -- Case-insensitive: qb-inventory item names are lowercase; ox/GTA/MBT uppercase.
    return type(s) == "string" and string.upper(string.sub(s, 1, 7)) == "WEAPON_"
end

---Weapon type ('side'/'back'/'back2'/'melee'…) for a canonical WEAPON_ name, or nil.
---@param name string?
---@return string?
function Utils.weaponType(name)
    local w = name and MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[name]
    return w and w.type
end

function Utils.isTableEmpty(t)
    return next(t) == nil
end

function Utils.containsValue(array, value)
    for i=1, #array do
        if array[i] == value then
            return true, i
        end
    end
    return false, -1
end

--- Match an attached prop's alpha to the ped wearing it — a ped's alpha does NOT propagate to attached entities, so a script that fades a ped out (multichar switch, relog) leaves our props hanging in mid-air.
---@param prop number
---@param pedAlpha number  0-255, from GetEntityAlpha on the owner ped
function Utils.syncPropAlpha(prop, pedAlpha)
    -- Any alpha is honoured, not just 0/255, so partial fades work too.
    if GetEntityAlpha(prop) == pedAlpha then return end
    if pedAlpha < 255 then
        SetEntityAlpha(prop, pedAlpha, false)
    else
        ResetEntityAlpha(prop)   -- cleaner than SetEntityAlpha(255): clears the override outright
    end
end

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

function Utils.weaponHasFlashlight(ped, weaponHash, compList)
    -- Defensive: weapon name can be nil mid holster/disarm transition — joaat(nil) hard-errors.
    if not weaponHash or type(compList) ~= 'table' then return false end
    local hash = (type(weaponHash) == 'number') and weaponHash or joaat(weaponHash)
    local hasFlash = false
    for i=1, #compList do
        hasFlash = HasPedGotWeaponComponent(ped, hash, compList[i])
        if hasFlash then break end
    end
    return hasFlash == 1
end

function Utils.isComponentAFlashlight(componentName)
    return componentName == "at_flashlight"
end

--- Jam chance (%) for a durability, read off MBT.Jamming.Chance — the LOWEST threshold the weapon still falls under wins; a weapon above every threshold never jams.
---@param d number?  durability 0-100; nil (e.g. a qb item with no info.quality) = no jam
---@return number chance  0-100
local function getChance(d)
    if type(d) ~= 'number' then return 0 end
    local chance, lowest = 0, nil
    for key, value in pairs(MBT.Jamming["Chance"]) do
        if d <= key and (not lowest or key < lowest) then
            chance, lowest = value, key
        end
    end
    return chance
end

function Utils.getJammingChance(value)
    local chance = getChance(value)
    math.randomseed(GetGameTimer() * math.random(30568, 90214))
    local random = math.random(1, 100)
    Utils.mbtDebugger("random is ", random, "chance is ", chance)
    return random < chance
end

--- Durability (0-100) -> condition tier 1-5 (5 = pristine); single source of truth for the shooting-bridge export GetWeaponCondition, derived on read, not stored.
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


--- The Draw Style in force for THIS player: their job's override, or the server default.
---@return string  a style id — 'standard' when nothing matches
function Utils.activeDrawStyle()
    -- Local-player only, and that's correct rather than a limitation: each client resolves the
    -- gesture for its own ped, and the game replicates the animation it plays — so everyone
    -- around sees the police draw as police, without a single extra event on the wire.
    local byJob = MBT.DrawStyleByJob
    if byJob and next(byJob) and PlayerData then
        if PlayerData.groups then
            -- ox_core has groups instead of one job, so the first group with an override wins.
            -- Order is not stable across pairs(), but a player in two jobs that both override
            -- is a server's own ambiguity to resolve, not one this function should invent an
            -- answer for.
            for g in pairs(PlayerData.groups) do
                if byJob[g] then return byJob[g] end
            end
        elseif PlayerData.job and PlayerData.job.name and byJob[PlayerData.job.name] then
            return byJob[PlayerData.job.name]
        end
    end
    return MBT.DrawStyle or 'standard'
end

--- The holster gesture for a slot, with the active Draw Style applied.
---@param wtype string?  prop slot — 'side', 'back', 'back2', 'melee'…
---@param styleId string?  resolve against THIS style instead of the player's active one. Only
---  the gesture picker passes it: it edits a style the admin may not be assigned to, and
---  showing them their own job's gesture as "current" while they edit another is the one
---  mistake this whole overlay exists to prevent.
---@return table?  { dict, animIn, animOut, sleep, sleepOut }, or nil if the slot has none
function Utils.holsterAnim(wtype, styleId)
    -- ONE resolver for TWO consumers: sendAnimations builds the table the ox patch writes into
    -- Items[name].anim, and the qb path reads it at draw time in five places. Applied to only
    -- one, a style would work on ox and silently do nothing on qb.
    local base = wtype and MBT.PropInfo and MBT.PropInfo[wtype] and MBT.PropInfo[wtype].HolsterAnim
    if not base then return nil end

    -- Timing first, and read from ONE place regardless of style: per slot, server-wide. See
    -- MBT.SlotTiming for why this is the only override of these two fields that exists.
    local t     = MBT.SlotTiming and MBT.SlotTiming[wtype]
    local sleep    = (t and tonumber(t.sleep))    or base.sleep
    local sleepOut = (t and tonumber(t.sleepOut)) or base.sleepOut

    -- Three layers, in this order: the slot's own clip, the style shipped in default.lua, and
    -- the one the owner picked in-game. Only the third persists; the first two are code.
    local id    = styleId or Utils.activeDrawStyle()
    local style = MBT.DrawStyles and MBT.DrawStyles[id]
    local owner = MBT.DrawStyleOverrides and MBT.DrawStyleOverrides[id]
    local over  = owner and owner[wtype] or (style and style[wtype])
    -- Still goes through the merge when only the timing was retuned, so a slot with no clip
    -- override does not silently keep the shipped duration.
    if not over then
        if not t then return base end
        return {
            dict = base.dict, dictOut = base.dictOut, animIn = base.animIn, animOut = base.animOut,
            sleep = sleep, sleepOut = sleepOut,
        }
    end

    -- An empty string is truthy in Lua, so a blank saved dict would suppress the fallback and
    -- leave the gesture silently dead rather than falling through to the layer below. Blank
    -- is treated as absent at every level, not only at save time.
    local pick = function(a, b, c)
        if type(a) == 'string' and a ~= '' then return a end
        if type(b) == 'string' and b ~= '' then return b end
        return c
    end

    -- Field-level merge, and the clip fields ONLY. `sleep` and `sleepOut` come from the slot
    -- (PropInfo, or MBT.SlotTiming above) and never from the style, even if a style declares
    -- them — enforced here rather than trusted to config, because this is the boundary between
    -- the two scripts and a config file is where someone eventually writes a smaller number
    -- "just to try".
    --
    -- `sleep` is how long the player stands with empty hands: a style at 1000ms against a
    -- base of 1200 hands out two tenths of a second in a firefight. That is Quick Draw, and
    -- Quick Draw is mbt_shooting's. A style changes the gesture, not what it costs.
    local dict = pick(over.dict, base.dict)
    return {
        dict     = dict,
        -- Optional second dict for the put-away. Falls back to `dict`, so a style that does
        -- not care never has to mention it.
        dictOut  = pick(over.dictOut, base.dictOut, dict),
        animIn   = pick(over.animIn,  base.animIn),
        animOut  = pick(over.animOut, base.animOut),
        sleep    = sleep,
        sleepOut = sleepOut,
    }
end
