da_mode.register({
    name = "game",
    priority = 1,
    onActivate = function() log.spam("da_mode game startFn") end,
    onDeactivate = function() log.spam("da_mode game stopFn") end,
    -- keymaps = {
    --     x = {
    --         justPressed = {
    --             primary = "game",
    --             fn = function()
    --                 log.debug("da_mode game x justPressed")
    --                 TriggerEvent("da_xanims:batchCache")
    --             end,
    --         },
    --         justReleased = {
    --             primary = "game",
    --             fn = function()
    --                 log.debug("da_mode game x justReleased")
    --                 da_mode.activate("xanims")
    --             end,
    --         },
    --     }
    -- }
})

Citizen.CreateThread(function() da_mode.activate("game") end)

EnableHudContext(-66088566) -- Money
EnableHudContext(3141998988) -- Ammo
EnableHudContext(1058184710) -- Skill Cards
-- Citizen.InvokeNative(0x4CC5F2FC1332577F, -66088566) -- Hide money
-- Citizen.InvokeNative(0x4CC5F2FC1332577F, 3141998988)
-- Citizen.InvokeNative(0x4CC5F2FC1332577F, 1058184710)    -- Skill Cards
Citizen.InvokeNative(0xC116E6DF68DCE667, 3, 2)    -- Deadeye Core
