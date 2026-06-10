fx_version 'cerulean'
games {'rdr3'}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'daggre_actual'
description 'Token game script'
lua54 'yes'

shared_scripts {
    '@da_log/log_sh.lua',
}

client_scripts {
    '@da_lib/features/mode/mode_cl.lua',
    'game_cl.lua',
    'cfg_peddensity_cl.lua',
}
