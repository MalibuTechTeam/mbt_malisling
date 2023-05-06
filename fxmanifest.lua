fx_version "cerulean"

game "gta5"

lua54 "yes"

author "Malibù Tech Team"

description "mbt_malisling"

version      '0.0.1'

shared_scripts {
	'@ox_lib/init.lua',
    "config.lua",
    "helper.lua"
}

server_scripts {
    "server/*.lua"
}

client_scripts {
    "client/*.lua"
}

dependency { "ox_inventory", "ox_lib" }