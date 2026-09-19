fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name '5Mspeakers'
author 'twizzy.codes'
description 'Advanced 3D Spatialized FiveM Speaker System'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/audio.lua',
    'client/menus.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'ox_lib',
    'ox_target'
}

