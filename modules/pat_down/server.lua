-- ─────────────────────────────────────────────────────────────────────────────
-- Pat-down (LEO frisk) — server
-- TRUTH lives here: server reads the target's inventory weapons and derives carry
-- status (visible / concealed poor|good / back) from the concealment statebag and
-- weapon type. Target consents unless cuffed + bypass. NOT an inventory search:
-- only weapons + carry status + serial leave the server. Optional Discord audit.
-- ─────────────────────────────────────────────────────────────────────────────

if not MBT.PatDown then return end

local cfg     = MBT.PatDown
local pending = {}   -- [targetSrc] = { officer, expires }
local lastUse = {}   -- [officer] = GetGameTimer()

local function maxDist() return (cfg.MaxDistance or 2.0) + 2.0 end
local function isCopJob(src) return cfg.Jobs and cfg.Jobs[getPlayerJob(src)] == true end

--- Build the weapon findings for a target: { name, label, serial, status, quality }.
local function frisk(target)
    local items = Inventory:GetInventoryItems(target)
    if type(items) ~= 'table' then return {} end

    local concealed = Player(target).state.mbt_concealed
    concealed = type(concealed) == 'table' and concealed or {}

    local out = {}
    for _, item in pairs(items) do
        if type(item) == 'table' and type(item.name) == 'string'
            and item.name:sub(1, 7) == 'WEAPON_' then
            local w = MBT.WeaponsInfo and MBT.WeaponsInfo.Weapons and MBT.WeaponsInfo.Weapons[item.name]
            local wtype = w and w.type
            if wtype then
                -- Forensic backbone: a frisked weapon always carries a serial.
                local serial = item.metadata and item.metadata.serial
                if not serial and MBT.EnsureSerial then serial = MBT.EnsureSerial(target, item) end

                local status, quality = 'visible', nil
                if concealed[wtype] then
                    status, quality = 'concealed', concealed[wtype]   -- 'good' | 'poor'
                elseif wtype == 'back' or wtype == 'back2' then
                    status = 'carried'        -- visible on the back anyway
                end
                out[#out + 1] = {
                    label   = (item.metadata and item.metadata.label) or item.name,
                    serial  = serial,
                    status  = status,
                    quality = quality,
                }
            end
        end
    end
    return out
end

--- Worst (longest) search time among the findings: a well-hidden gun makes the frisk take longer, a poorly-hidden or visible one is quick.
local function searchMs(findings)
    local ms = cfg.SearchMsPoor or 600
    for _, f in ipairs(findings) do
        if f.status == 'concealed' and f.quality == 'good' then
            ms = math.max(ms, cfg.SearchMsGood or 2600)
        end
    end
    return ms
end

local function logFrisk(officer, target, findings)
    local log = cfg.Logging or {}
    if not log.Enabled or not log.Webhook or log.Webhook == '' then return end
    local oName = getPlayerName(officer)
    local tName = getPlayerName(target)
    local lines = {}
    for _, f in ipairs(findings) do
        lines[#lines + 1] = ('• %s [%s] — %s'):format(f.label, f.serial or 'n/a',
            f.status == 'concealed' and ('concealed (' .. (f.quality or '?') .. ')') or f.status)
    end
    if #lines == 0 then lines[1] = '• none' end
    PerformHttpRequest(log.Webhook, function() end, 'POST', json.encode({
        username = log.BotName or 'MBT Pat-Down',
        embeds = { {
            title = 'Pat-down', color = 3447003,
            fields = {
                { name = 'Officer',  value = ('%s (%s)'):format(oName, officer), inline = true },
                { name = 'Suspect',  value = ('%s (%s)'):format(tName, target),  inline = true },
                { name = 'Weapons',  value = table.concat(lines, '\n'), inline = false },
            },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

-- ── Officer initiates ─────────────────────────────────────────────────────────
RegisterNetEvent('mbt_malisling:patdown:request', function(targetServerId)
    local officer = source
    if not cfg.Enabled or not isCopJob(officer) then return end

    local now = GetGameTimer()
    if lastUse[officer] and (now - lastUse[officer]) < 1500 then return end
    lastUse[officer] = now

    local target = tonumber(targetServerId)
    if not target or target == officer or not GetPlayerName(target) then return end
    if pending[target] then return end

    local pedA, pedB = GetPlayerPed(officer), GetPlayerPed(target)
    if pedA == 0 or pedB == 0 or #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) > maxDist() then
        TriggerClientEvent('mbt_malisling:patdown:result', officer, { reason = 'patdown_no_target' })
        return
    end

    -- Cuffed targets skip consent (config). IsPedCuffed reads the TARGET's ped state
    -- (client-influenced server-side) so prefer a trusted cfg.IsRestrained(src); fall
    -- back to the native only when it isn't provided.
    local cuffed = false
    if cfg.CuffedBypass then
        if type(cfg.IsRestrained) == 'function' then
            cuffed = cfg.IsRestrained(target) == true
        else
            local ok, c = pcall(IsPedCuffed, pedB)
            cuffed = ok and c == true
        end
    end
    if cfg.RequireConsent and not cuffed then
        pending[target] = { officer = officer, expires = now + (cfg.RequestTimeoutMs or 8000) }
        TriggerClientEvent('mbt_malisling:patdown:prompt', target, { officer = GetPlayerName(officer) })
        TriggerClientEvent('mbt_malisling:patdown:result', officer, { reason = 'patdown_sent' })
    else
        -- No consent needed → run it straight away.
        local findings = frisk(target)
        TriggerClientEvent('mbt_malisling:patdown:run', officer,
            { target = target, searchMs = searchMs(findings), findings = findings })
        TriggerClientEvent('mbt_malisling:patdown:searched', target)
        logFrisk(officer, target, findings)
    end
end)

-- ── Target responds ───────────────────────────────────────────────────────────
RegisterNetEvent('mbt_malisling:patdown:respond', function(accept)
    local target = source
    local offer = pending[target]
    pending[target] = nil
    if not offer or GetGameTimer() > offer.expires then return end
    local officer = offer.officer

    if not accept then
        TriggerClientEvent('mbt_malisling:patdown:result', officer, { reason = 'patdown_declined' })
        return
    end

    -- Re-validate proximity at accept time.
    local pedA, pedB = GetPlayerPed(officer), GetPlayerPed(target)
    if pedA == 0 or pedB == 0 or #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) > maxDist() then
        TriggerClientEvent('mbt_malisling:patdown:result', officer, { reason = 'patdown_no_target' })
        return
    end

    local findings = frisk(target)
    TriggerClientEvent('mbt_malisling:patdown:run', officer,
        { target = target, searchMs = searchMs(findings), findings = findings })
    TriggerClientEvent('mbt_malisling:patdown:searched', target)
    logFrisk(officer, target, findings)
end)

CreateThread(function()
    while true do
        Wait(2000)
        local now = GetGameTimer()
        for target, offer in pairs(pending) do
            if now > offer.expires then
                pending[target] = nil
                TriggerClientEvent('mbt_malisling:patdown:expired', target)
                TriggerClientEvent('mbt_malisling:patdown:result', offer.officer, { reason = 'patdown_declined' })
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local s = source
    if not s then return end
    lastUse[s] = nil
    pending[s] = nil
    -- The officer may have dropped while their request is still pending under the TARGET's key.
    for target, offer in pairs(pending) do
        if offer.officer == s then
            pending[target] = nil
            TriggerClientEvent('mbt_malisling:patdown:expired', target)
        end
    end
end)
