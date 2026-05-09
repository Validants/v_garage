fx_version 'cerulean'
game 'gta5'

name 'ug_garage'
author 'ChatGPT'
description 'Universal ESX/QBCore Garage with NUI Admin Creator'
version '1.0.20'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/locales.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/framework.lua',
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/i18n.js',
    'web/app.js',
    'web/img/*.png',
    'web/img/*.jpg',
    'web/img/*.jpeg'
}

dependencies {
    'ox_lib',
    'oxmysql'
}

-- Optional but recommended for automatic vehicle photos:
-- ensure screenshot-basic before this resource
