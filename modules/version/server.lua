-- ── Version check — server ──
-- One request at boot to the GitHub Releases API, compared against the fxmanifest
-- version. Replaces lib.versionCheck: that one prints to the server console and keeps
-- the result to itself, and nobody reads a server console — we need the answer in the
-- admin dashboard too, so we own the check and expose MBT.UpdateInfo.
-- Fails silent by design: a private/renamed repo, a rate limit or no network must never
-- warn the owner about something they can't act on.

local REPO = 'MalibuTechTeam/mbt_malisling'

--- Semver as a comparable triple. Tags carry a leading 'v', the manifest doesn't.
---@return number, number, number
local function parseVersion(s)
    local ma, mi, pa = tostring(s):match('^v?(%d+)%.(%d+)%.(%d+)')
    return tonumber(ma) or 0, tonumber(mi) or 0, tonumber(pa) or 0
end

--- True when `latest` is newer than `current`. Compared FIELD BY FIELD, never as
--- strings: '2.10.0' < '2.9.0' lexically, which would hide every release past x.9.
local function isNewer(latest, current)
    local lMa, lMi, lPa = parseVersion(latest)
    local cMa, cMi, cPa = parseVersion(current)
    if lMa ~= cMa then return lMa > cMa end
    if lMi ~= cMi then return lMi > cMi end
    return lPa > cPa
end

CreateThread(function()
    if MBT.VersionCheck == false then return end   -- server owners who block outbound HTTP
    Wait(2000)   -- let the resource finish booting; this is never urgent

    local current = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
    if not current then return end

    PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(REPO),
        function(status, body)
            -- 404 while the repo is still private, 403 on rate limit: both are normal.
            if status ~= 200 or type(body) ~= 'string' then return end
            local ok, data = pcall(json.decode, body)
            if not ok or type(data) ~= 'table' or type(data.tag_name) ~= 'string' then return end
            if not isNewer(data.tag_name, current) then return end

            MBT.UpdateInfo = {
                current = current,
                latest  = data.tag_name:gsub('^v', ''),
                url     = type(data.html_url) == 'string' and data.html_url
                          or ('https://github.com/%s/releases/latest'):format(REPO),
            }
            Utils.mbtWarn(('update available: %s → %s  (%s)')
                :format(current, MBT.UpdateInfo.latest, MBT.UpdateInfo.url))
        end, 'GET', '', { ['User-Agent'] = 'mbt_malisling' })
end)
