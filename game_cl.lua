-- local TownDensity = 0.1
local WildernessDensity = 0.5

Citizen.CreateThread(function()
    EnableHudContext(-66088566) -- Money
    EnableHudContext(1058184710) -- Skill Cards
    UitutorialSetRpgIconVisibility(3, 2)    -- Deadeye Core
    EnableHudContext(`HUD_CTX_IN_FAST_TRAVEL_MENU`) -- Remove reticle, help, feed, award massages, etc all at once
    EnableHudContext(`HUD_CTX_ITEM_CONSUMPTION_HEALTH`) -- Show Health Core
    EnableHudContext(`HUD_CTX_ITEM_CONSUMPTION_HEALTH_CORE`) -- Show Health Core Bar
    EnableHudContext(`HUD_CTX_ITEM_CONSUMPTION_STAMINA`) -- Show Stamina Core
    EnableHudContext(`HUD_CTX_ITEM_CONSUMPTION_STAMINA_CORE`) -- Show Stamina Core Bar

    while true do
        SetAmbientAnimalDensityMultiplierThisFrame(WildernessDensity)
        SetAmbientHumanDensityMultiplierThisFrame(WildernessDensity)
        SetAmbientPedDensityMultiplierThisFrame(WildernessDensity)
        SetScenarioAnimalDensityMultiplierThisFrame(WildernessDensity)
        SetScenarioHumanDensityMultiplierThisFrame(WildernessDensity)
        SetScenarioPedDensityMultiplierThisFrame(WildernessDensity)
        SetParkedVehicleDensityMultiplierThisFrame(WildernessDensity)
        SetRandomVehicleDensityMultiplierThisFrame(WildernessDensity)
        SetVehicleDensityMultiplierThisFrame(WildernessDensity)

        DisableControlAction(0, `INPUT_HUD_SPECIAL`, true)
        DisableControlAction(0, `INPUT_REVEAL_HUD`, true)
        DisableControlAction(0, `INPUT_MULTIPLAYER_INFO`, true)
        DisableControlAction(0, `INPUT_SELECT_RADAR_MODE`, true)
        DisableControlAction(0, `INPUT_PC_FREE_LOOK`, true)

        UiPromptDisablePromptTypeThisFrame(7) -- Animal info
        SetPlayerTargetingMode(3) -- Set Targeting Mode Expert (Free Aim)
        SetMinimapType(0) -- Force Compass-Style Radar
        Citizen.Wait(0)
    end
end)

-- EnableHudContext(3141998988) -- Reticle/Crosshair/Ammo
-- EnableHudContext(`HUD_CTX_ITEM_CONSUMPTION_DEADEYE`) -- Show Deadeye Core
-- EnableHudContext(`HUD_CTX_ITEM_CONSUMPTION_DEADEYE_CORE`) -- Show Deadeye Core Bar

-- Mercy Kill
-- Citizen.InvokeNative(0x39363DFD04E91496, PlayerId(), true) -- Enable mercy kill
