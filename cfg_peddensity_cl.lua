-- local TownDensity = 0.1
local WildernessDensity = 0.5

Citizen.CreateThread(function()
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
        Citizen.Wait(0)
    end
end)
