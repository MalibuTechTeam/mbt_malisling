fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mbt_malisling'
author 'Malibù Tech Team'
version      '1.1.4'
repository 'https://github.com/MalibuTechTeam/mbt_malisling'
description 'Weapon on back with various features'

dependencies { 
    '/onesync',
    'ox_lib', 
    'ox_inventory' 
}

shared_scripts {
	'@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    'server/*.lua'
}

client_scripts {
    'client/*.lua'
}

files {
    'data/*.lua',
    'utils.lua'
}