fx_version "cerulean"

game "gta5"

lua54 "yes"

author "Malibù Tech Team"

description "mbt_malisling"

version "1.0"

shared_scripts {
	'@ox_lib/init.lua',
    "config.lua"
}

server_scripts {
    "server/*.lua"
}

client_scripts {
    "client/*.lua"
}

files {
    'data/*.lua',
    'utils.lua'
}

dependency { "ox_inventory", "ox_lib" }