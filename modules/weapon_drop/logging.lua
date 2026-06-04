-- ─────────────────────────────────────────────────────────────────────────────
-- Weapon Drop Logging — server
--
-- Logs weapon drops to a Discord webhook: who, weapon, serial, coords, timestamp.
-- Hooked into WeaponDropServer.Create, which covers the
-- "active" drop paths: DEATH-drop, THROW, and the manual dropCurrentWeapon export.
--
-- NOT covered (by design): the native ox_inventory drag-drop (dragging a weapon
-- out of the inventory UI). That never reaches our server Create — it's a pure ox
-- drop we only intercept client-side to render the prop — and ox_inventory already
-- logs its own drops, so logging it here would duplicate ox's audit trail.
--
-- Exposes MBT.LogWeaponDrop(src, item, coords) — called from weapon_drop/server.
-- ─────────────────────────────────────────────────────────────────────────────

MBT = MBT or {}

--- Fire-and-forget log of a weapon drop.
--- Reads MBT.WeaponDrop.Logging fresh each call so the admin menu's live-apply
--- (which rewrites MBT.*) takes effect without a restart.
---@param src number          dropping player's server id
---@param item table          the inventory item ({ name, metadata = { serial, label, ... } })
---@param coords vector3      where it landed
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
