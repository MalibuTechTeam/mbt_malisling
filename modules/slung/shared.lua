-- ── Slung prop registry — shared identity ────────────────────────────────────────
-- Loaded in BOTH VMs on purpose: the serial key travels the network as a TABLE KEY, so
-- client and server have to derive it the same way from the same item or the two registries
-- stop agreeing on what "the same weapon" is.
--
-- Client half: modules/slung/client.lua (prop handles).
-- Server half: modules/slung/server.lua (weaponData + lane).

Slung = {}

--- Is this a type the registry accepts? Answered from MBT.PropInfo LIVE, not from a snapshot
--- taken at load: a custom type added to the config is valid automatically, and the position
--- editor rewrites PropInfo entries at runtime. The client used to carry three hardcoded
--- lists of six types while PropInfo held seven ('extinguisher' was in none of them).
--- Note PropInfo also holds non-slot entries — 'sling:<variant>', the tactical-sling strap
--- offsets seeded in default.lua. Harmless here: no weapon ever maps to one.
---@param propType string
---@return boolean
function Slung.isType(propType)
    return MBT.PropInfo ~= nil and MBT.PropInfo[propType] ~= nil
end

--- Registry key for one weapon item. ALWAYS a string: it crosses json.encode, and a table
--- mixing numeric and string keys loses its shape there.
--- Weapons with no serial exist by design — modules/serials skips stacks, EnsureGeneration
--- is optional, and the repair sweep only runs 7.5s after the first sling — so fall back to
--- the inventory slot. '#' can't collide: serials are A-Z0-9 or MBT-prefixed.
---@param item table   weapon item ({ name, slot, metadata })
---@return string
function Slung.serialKey(item)
    local s = item and item.metadata and item.metadata.serial
    if s then return tostring(s) end
    return '#' .. tostring(item and item.slot or '?')
end

--- Grouping key: two weapons share it when they look IDENTICAL on the body. NOT the name —
--- a suppressed carbine and a bare one share a name and don't share an appearance, and
--- hiding one of them contradicts what the inventory and the pat-down show.
--- Derived from the DECLARED components (both VMs see the same item), never from
--- DoesWeaponTakeWeaponComponent: that is a client native, and the server would answer
--- differently — the two keys have to match.
--- Unused in phase 1 (one weapon per type); phase 4 groups and assigns lanes with it.
---@param item table
---@return string
function Slung.visualKey(item)
    local name = item and item.name or '?'
    local comps = item and item.metadata and item.metadata.components
    if type(comps) ~= 'table' or #comps == 0 then return name end

    local known = MBT.WeaponsInfo and MBT.WeaponsInfo.Components
    local out = {}
    for i = 1, #comps do
        local c = comps[i]
        -- Unknown component names can't change the prop's look, so they must not split a group.
        if type(c) == 'string' and (not known or known[c]) then out[#out + 1] = c end
    end
    if #out == 0 then return name end

    table.sort(out)
    return name .. '|' .. table.concat(out, ',')
end
