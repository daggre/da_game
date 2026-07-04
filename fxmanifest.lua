fx_version 'cerulean'
games {'rdr3'}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'daggre_actual'
description 'Token game script'
lua54 'yes'

shared_scripts {
    '@da_log/log_sh.lua',
}

server_scripts {
    'wolf_srv.lua',
}

client_scripts {
    '@da_lib/features/mode/mode_cl.lua',
    '@da_lib/features/control/control_cl.lua',
    '@da_lib/features/anim/anim_cl.lua',
    '@da_lib/features/hud/cores_cl.lua',
    '@da_lib/features/util/util_cl.lua',
    '@da_lib/features/raycast/raycast_cl.lua',
    '@da_lib/features/weapon/weapon_cl.lua',
    '@da_lib/features/move/move_cl.lua',
    '@da_lib/data/key.lua',
    'spawn_cl.lua',
    'game_cl.lua',
    'reticle_cl.lua',
    'zoom_cl.lua',
    'wolf_cl.lua',
}

dependencies {
    'da_log',
    'da_lib',
}
