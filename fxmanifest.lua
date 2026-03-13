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
    'ox_inventory'
}

shared_scripts {
    'modules/module.lua',
	'@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    'modules/**/server.lua',
    'core/server.lua',
}

client_scripts {
    'modules/**/client.lua',
    'core/client.lua',
}

files {
    'data/*.lua',
    'web/dist/index.html',
    'web/dist/assets/**',
}
