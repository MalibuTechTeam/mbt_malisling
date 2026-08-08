-- ── Weapon Drop Logging — server ──
-- Logs weapon drops to a Discord webhook via WeaponDropServer.Create, covering the active
-- paths: DEATH-drop, THROW, manual dropCurrentWeapon. NOT native ox drag-drop (by design:
-- it never reaches our Create, and ox already logs its own drops).
-- Exposes MBT.LogWeaponDrop(src, item, coords).

MBT = MBT or {}

--- Fire-and-forget log of a weapon drop; reads MBT.WeaponDrop.Logging fresh each call so the admin menu's live-apply takes effect without a restart.
function MBT.LogWeaponDrop(src, item, coords)
    local cfg = (MBT.WeaponDrop or {}).Logging or {}
    if not cfg.Enabled then return end
    if type(item) ~= 'table' or type(item.name) ~= 'string' then return end

    if not cfg.Webhook or cfg.Webhook == '' then return end

    local name   = GetPlayerName(src) or 'unknown'
    local serial = (item.metadata and item.metadata.serial) or 'n/a'
    local label  = (item.metadata and item.metadata.label) or item.name
    local pos    = ('%.1f, %.1f, %.1f'):format(coords.x, coords.y, coords.z)

    do
        local payload = {
            username = cfg.BotName or 'MBT Malisling',
            embeds = { {
                title = 'Weapon Dropped',
                color = 15158332,  -- red
                fields = {
                    { name = 'Player',  value = ('%s (%s)'):format(name, src), inline = true },
                    { name = 'Weapon',  value = label,  inline = true },
                    { name = 'Serial',  value = serial, inline = true },
                    { name = 'Coords',  value = pos,    inline = false },
                },
                footer = { text = ('item: %s'):format(item.name) },
            } },
        }
        PerformHttpRequest(cfg.Webhook, function() end, 'POST',
            json.encode(payload), { ['Content-Type'] = 'application/json' })
    end
end
