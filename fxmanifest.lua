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
    'config.lua'
}

server_scripts {
    'modules/utils/server.lua',
    'modules/bridge/esx/server.lua',
    'modules/bridge/ox/server.lua',
    'modules/bridge/qb/server.lua',
    'modules/bridge/qbox/server.lua',
    'modules/inventory/ox/server.lua',
    'modules/inventory/qb/server.lua',
    'modules/weapon_drop/server.lua',
    'modules/weapon_jamming/server.lua',
    'modules/weapon_throw/server.lua',
    'modules/config/server.lua',
    'core/server.lua',
}

client_scripts {
    'modules/utils/client.lua',
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
}

files {
    'data/*.lua',
    'web/dist/index.html',
    'web/dist/assets/**',
}

-- Supported inventories (soft dependencies — detected at runtime):
--   ox_inventory  >= 2.30.0
--   qb-inventory  (any modern version)
