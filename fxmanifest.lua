fx_version 'cerulean'
games { 'gta5' }

author 'Next Dev Labs '
description 'Free Standalone Duty System - itzzkratos Made some changes :)'
version '1.1'

shared_script 'config/shared_config.lua'

server_script {
    'config/server_config.lua',
    'server.lua'
}

client_script 'client.lua'
