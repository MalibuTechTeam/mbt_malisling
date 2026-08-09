-- ─────────────────────────────────────────────────────────────────────────────
-- Forensic Shell Casings — server
-- In-memory casing registry keyed by id, linked to the firing weapon's SERIAL.
-- Ephemeral: global FIFO cap + expiry, no DB. Client reports the shot (coords +
-- weapon); CHANCE roll, throttle and serial resolution happen HERE (never trust
-- client for outcomes). Examine reveals weapon family + masked serial + age.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.ShellCasings then return end

local cfg      = MBT.ShellCasings
local casings  = {}    -- [id] = { id, x, y, z, weapon, wtype, serial, at }
local order    = {}    -- insertion order (FIFO cap)
local seq      = 0
local lastShot = {}    -- [src] = GetGameTimer() (throttle)

local finite     = Utils.finite
local weaponType = Utils.weaponType

--- True if (x,y,z) is inside any configured no-casing zone (ranges/armories). 3D sphere.
local function inExcludeZone(x, y, z)
    local zones = cfg.ExcludeZones
    if type(zones) ~= 'table' then return false end
    local at = vec3(x, y, z)
    for i = 1, #zones do
        local zn = zones[i]
        if zn and zn.coords and #(at - zn.coords) <= (zn.radius or 20.0) then return true end
    end
    return false
end

local function removeCasing(id)
    casings[id] = nil   -- order is cleaned lazily
end

--- FIFO room: drop the oldest live casing once the global cap is reached.
local function makeRoom()
    local cap = cfg.MaxCasings or 150
    local live = 0
    for _ in pairs(casings) do live = live + 1 end
    if live < cap then return end
    for i = 1, #order do
        local id = order[i]
        if casings[id] then removeCasing(id) break end
    end
end

RegisterNetEvent('mbt_malisling:casing:shot', function(p)
    local src = source
    if not cfg.Enabled or type(p) ~= 'table' then return end
    if not (finite(p.x) and finite(p.y) and finite(p.z)) then return end
    if inExcludeZone(p.x, p.y, p.z) then return end   -- ranges/armories: no forensic casings

    local now = GetGameTimer()
    if lastShot[src] and (now - lastShot[src]) < (cfg.MinIntervalMs or 1200) then return end
    lastShot[src] = now

    -- The casing must land where the shooter actually is.
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - vec3(p.x, p.y, p.z)) > 10.0 then return end

    -- Resolve the shooter's ACTUAL held weapon server-side (ox) so a scripted client can't forge
    -- evidence (wrong weapon family / someone else's serial). qb has no server-side resolver, so
    -- there it falls back to the client-reported value (best effort, documented limitation).
    local weapon, serial = p.weapon, nil
    if GetResourceState('ox_inventory') == 'started' then
        local ok, w = pcall(function() return exports.ox_inventory:GetCurrentWeapon(src) end)
        if ok and type(w) == 'table' and type(w.name) == 'string' then
            weapon, serial = w.name, (w.metadata and w.metadata.serial)
        end
    end
    if not serial and type(p.serial) == 'string' and #p.serial <= 24 then serial = p.serial end

    if type(weapon) ~= 'string' or weapon:sub(1, 7) ~= 'WEAPON_' then return end
    local wtype = weaponType(weapon)
    if not wtype or (cfg.ExcludeTypes and cfg.ExcludeTypes[wtype]) then return end

    -- Server-side roll: the client only reports the shot.
    if math.random() > (cfg.Chance or 0.5) then return end

    makeRoom()
    seq = seq + 1
    local id = ('c%d_%d'):format(os.time(), seq)
    casings[id] = {
        id = id, x = p.x, y = p.y, z = p.z,
        weapon = weapon, wtype = wtype, serial = serial,
        at = os.time(),
    }
    order[#order + 1] = id
end)

-- ── Queries ──────────────────────────────────────────────────────────────────────
--- Nearby casings for the world renderer (ids + coords only — data stays here).
lib.callback.register('mbt_malisling:casing:getNearby', function(src)
    if not cfg.Enabled then return {} end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return {} end
    local pc = GetEntityCoords(ped)
    local out, n = {}, 0
    for id, c in pairs(casings) do
        if #(pc - vec3(c.x, c.y, c.z)) < 40.0 then
            n = n + 1
            out[n] = { id = id, x = c.x, y = c.y, z = c.z }
            if n >= 30 then break end
        end
    end
    return out
end)

-- Gate for the /mbt_casingzone dev zone editor. Effect is client-only (a marker + a printed
-- config line, no server write), so this is for tidiness: MBT.Debug builds or admins get it.
local adminCommand = (MBT.Admin and MBT.Admin.Command) or GetCurrentResourceName()
local adminPerm    = (MBT.Admin and MBT.Admin.Permission) or ('command.' .. adminCommand)
lib.callback.register('mbt_malisling:casing:canTune', function(src)
    return (MBT.Debug == true) or IsPlayerAceAllowed(src, adminPerm)
end)

local function canExamine(src)
    if not cfg.ExamineJobs then return true end
    return playerHasAnyJob(src, cfg.ExamineJobs)
end

--- Serial → what the examine card reveals ('partial' keeps head + tail).
local function maskSerial(serial)
    local mode = cfg.SerialReveal or 'partial'
    if not serial or mode == 'none' then return nil end
    if mode == 'full' then return serial end
    if #serial <= 4 then return serial end
    return serial:sub(1, 2) .. string.rep('•', #serial - 4) .. serial:sub(-2)
end

local function guard(src, id)
    if not cfg.Enabled or type(id) ~= 'string' then return end
    local c = casings[id]
    if not c then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) > (cfg.InteractRange or 1.2) + 2.5 then return end
    return c
end

lib.callback.register('mbt_malisling:casing:examine', function(src, id)
    local c = guard(src, id)
    if not c or not canExamine(src) then return false end
    return {
        weapon = c.weapon,
        serial = maskSerial(c.serial),
        agoMin = math.floor((os.time() - c.at) / 60),
    }
end)

lib.callback.register('mbt_malisling:casing:collect', function(src, id)
    if not (cfg.AllowCollect ~= false) then return false end
    local c = guard(src, id)
    if not c then return false end
    removeCasing(id)
    return true
end)

-- ── Expiry sweep ─────────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(60000)
        local cutoff = os.time() - (cfg.ExpireMinutes or 30) * 60
        for id, c in pairs(casings) do
            if c.at < cutoff then removeCasing(id) end
        end
        -- Compact the FIFO order list while we're here.
        local fresh = {}
        for i = 1, #order do
            if casings[order[i]] then fresh[#fresh + 1] = order[i] end
        end
        order = fresh
    end
end)

AddEventHandler('playerDropped', function()
    if source then lastShot[source] = nil end
end)
