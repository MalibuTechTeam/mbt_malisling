fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mbt_malisling'
author 'Malibù Tech Team'
version      '1.1.4'
repository 'https://github.com/MalibuTechTeam/mbt_malisling'
description 'Weapon on back with various features'

ui_page 'web/dist/index.html'

dependencies {
    '/onesync',
    'ox_lib',
    -- ox_inventory and qb-inventory are soft dependencies: detected at runtime
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'modules/locales.lua',
    'locales/*.lua',
}

server_scripts {
    'modules/ox_patch/installer.js',   -- auto-applies the ox_inventory patch (cross-platform, no shell)
    'modules/utils/server.lua',
    'modules/weapon_sounds/server.lua',
    'modules/bridge/esx/server.lua',
    'modules/bridge/ox/server.lua',
    'modules/bridge/qb/server.lua',
    'modules/bridge/qbox/server.lua',
    'modules/bridge/jobs.lua',
    'modules/inventory/ox/server.lua',
    'modules/inventory/qb/server.lua',
    'modules/serials/server.lua',
    'modules/weapon_drop/logging.lua',
    'modules/weapon_drop/server.lua',
    'modules/weapon_jamming/server.lua',
    'modules/weapon_throw/server.lua',
    'modules/weapon_inspect/server.lua',
    'modules/low_ready/server.lua',
    'modules/weapon_name/server.lua',
    'modules/weapon_weight/server.lua',
    'modules/charge_weapon/server.lua',
    'modules/showcase_poses/server.lua',
    'modules/vehicle_trunk_rack/server.lua',
    'modules/prop_position_editor/server.lua',
    'modules/chain_of_custody/server.lua',
    'modules/weapon_rack/server.lua',
    'modules/shell_casings/server.lua',
    'modules/weapon_handoff/server.lua',
    'modules/concealed_carry/server.lua',
    'modules/pat_down/server.lua',
    'modules/config/server.lua',
    'core/server.lua',
}

client_scripts {
    'modules/utils/client.lua',
    'modules/shooting_bridge/client.lua',
    'modules/target/client.lua',
    'modules/weapon_sounds/client.lua',
    'modules/bridge/esx/client.lua',
    'modules/bridge/ox/client.lua',
    'modules/bridge/qb/client.lua',
    'modules/bridge/qbox/client.lua',
    'modules/inventory/ox/client.lua',
    'modules/inventory/qb/client.lua',
    'modules/weapon_drop/client.lua',
    'modules/weapon_jamming/client.lua',
    'modules/weapon_throw/client.lua',
    'modules/config/client.lua',
    'core/client.lua',
    'modules/suppressor_heat/client.lua',
    'modules/weapon_inspect/client.lua',
    'modules/low_ready/client.lua',
    'modules/tactical_sling/client.lua',
    'modules/weapon_safety/client.lua',
    'modules/weapon_name/client.lua',
    'modules/weapon_weight/client.lua',
    'modules/charge_weapon/client.lua',
    'modules/showcase_poses/client.lua',
    'modules/vehicle_trunk_rack/client.lua',
    'modules/weapon_rack/client.lua',
    'modules/shell_casings/client.lua',
    'modules/weapon_handoff/client.lua',
    'modules/concealed_carry/client.lua',
    'modules/pat_down/client.lua',
    'modules/prop_position_editor/client.lua',
    'modules/no_draw_zones/client.lua',
    'modules/prop_editor/client.lua',
}

files {
    'data/*.lua',
    'web/dist/index.html',
    'web/dist/assets/**',
    'web/dist/sounds/*.ogg',
}

-- Tactical Sling clothing asset lives in the dedicated mbt_sling_clothing
-- resource (mixing clothing stream + script/ui_page here is unreliable).

-- Supported inventories (soft dependencies — detected at runtime):
--   ox_inventory  >= 2.30.0
--   qb-inventory  (any modern version)
--
-- oxmysql: soft dependency, used ONLY by the Vehicle Trunk Weapon Rack for
-- persistence (table mbt_vehicle_trunk). Detected at runtime — if oxmysql isn't
-- started that feature disables itself and the rest of the script stays DB-free.
-- This is the one documented exception to the "no database" rule.
