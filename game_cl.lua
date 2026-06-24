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

Citizen.CreateThread(function()
    while true do
        DisableControlAction(0, `INPUT_HUD_SPECIAL`, true)
        DisableControlAction(0, `INPUT_REVEAL_HUD`, true)
        DisableControlAction(0, `INPUT_MULTIPLAYER_INFO`, true)
        DisableControlAction(0, `INPUT_SELECT_RADAR_MODE`, true)
        -- DisableControlAction(0, `INPUT_PC_FREE_LOOK`, true)

        UiPromptDisablePromptTypeThisFrame(7) -- Animal info
        SetPlayerTargetingMode(3) -- Set Targeting Mode Expert (Free Aim)
        SetMinimapType(0) -- Force Compass-Style Radar

        Citizen.Wait(0)
    end
end)

EnableHudContext(-66088566) -- Money
-- EnableHudContext(3141998988) -- Reticle/Crosshair/Ammo
EnableHudContext(1058184710) -- Skill Cards
Citizen.InvokeNative(0xC116E6DF68DCE667, 3, 2)    -- Deadeye Core

-- Citizen.InvokeNative(0x4CC5F2FC1332577F, `HUD_CTX_IN_FAST_TRAVEL_MENU`) -- Remove reticle, help, feed, award massages, etc all at once

Citizen.InvokeNative(0x4CC5F2FC1332577F, `HUD_CTX_ITEM_CONSUMPTION_HEALTH`) -- Show Health Core
Citizen.InvokeNative(0x4CC5F2FC1332577F, `HUD_CTX_ITEM_CONSUMPTION_HEALTH_CORE`) -- Show Health Core Bar
Citizen.InvokeNative(0x4CC5F2FC1332577F, `HUD_CTX_ITEM_CONSUMPTION_STAMINA`) -- Show Stamina Core
Citizen.InvokeNative(0x4CC5F2FC1332577F, `HUD_CTX_ITEM_CONSUMPTION_STAMINA_CORE`) -- Show Stamina Core Bar
--Citizen.InvokeNative(0x4CC5F2FC1332577F, `HUD_CTX_ITEM_CONSUMPTION_DEADEYE`) -- Show Deadeye Core
--Citizen.InvokeNative(0x4CC5F2FC1332577F, `HUD_CTX_ITEM_CONSUMPTION_DEADEYE_CORE`) -- Show Deadeye Core Bar


