local CarcassRange = 5.0
local EatRange = 1.0
local BloodPools = { }
local ClearCam = false
local SitDict = "amb_creature_mammal@world_wolf_sitting@"
local RestDict = "amb_creature_mammal@world_wolf_resting@"
local SleepDict = "amb_creature_mammal@world_wolf_sleeping@"
local DrinkDict = "amb_creature_mammal@world_wolf_drinking@"
local SniffDict = "amb_creature_mammal@world_wolf_sniffing_ground@"
local EatDict = "amb_creature_mammal@world_wolf_eating@"
local MarkDict = "amb_creature_mammal@world_wolf_mark_territory@"
local Wolf = {
    [`a_c_wolf`] = true,
    [`a_c_wolf_small`] = true,
    [`a_c_wolf_medium`] = true,
}
local function IsPedAWolf(ped) return Wolf[GetEntityModel(ped)] ~= nil end

local function IncreaseCore(ped, amount, core)
    local coreValue = Citizen.InvokeNative(0x36731AC041289BB1, ped, core) -- GetAttributeCoreValue
    coreValue = tonumber(coreValue) or 0
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, core, math.ceil(coreValue + amount)) -- SetAttributeCoreValue
end

local function IncreaseHealth(ped, amount) IncreaseCore(ped, amount, 0) end
local function IncreaseStamina(ped, amount) IncreaseCore(ped, amount, 1) end

local function LowCam(ped, delay)
    Citizen.CreateThread(function()
        delay = delay or 1000
        local flag = 3
        local initTime = GetGameTimer() + delay
        local timeout = GetGameTimer() + 60000
        while GetGameTimer() < initTime or IsEntityPlayingAnyAnim(ped, flag) do
            if ClearCam or GetGameTimer() > timeout then break end
            Citizen.InvokeNative(0x71D71E08A7ED5BD7, true)
            Citizen.Wait(0)
        end
        Citizen.InvokeNative(0x71D71E08A7ED5BD7, false)
        ClearCam = false
    end)
end

-- True if a dead ped (carcass) is within eating range of the wolf.
local function IsCarcassNearby(ped)
    local mc = GetEntityCoords(ped)
    for _, other in ipairs(GetGamePool("CPed")) do
        if other ~= ped and DoesEntityExist(other) and IsEntityDead(other) then
            if #(GetEntityCoords(other) - mc) < CarcassRange then
                return other
            end
        end
    end
    return false
end

local function Howl(ped)
    if GetEntitySpeed(ped) > 4.5 then return end
    da_anim.ped(ped, "amb_creature_mammal@world_wolf_howling@idle", "idle_a", 0.9, nil, -1, 67108888, nil, nil, "headandneckonly_filter")
end

local function Sniff(ped)
    if IsPedStopped(ped) then
        da_anim.ped(ped, SniffDict .. "stand_enter", "enter", 1.0)
        Citizen.Wait(150)
        while IsEntityPlayingAnim(ped, SniffDict .. "stand_enter", "enter", 3) do Citizen.Wait(0) end
        da_anim.ped(ped, SniffDict .. "base", "base", nil, 1.5, -1, 33)
        return
    end
end

local function SniffHigh(ped)
    log.debug(GetEntitySpeed(ped))
    if GetEntitySpeed(ped) > 3.0 then return end
    da_anim.ped(ped, MarkDict .. "idle", "idle_a", 1.0, nil, -1, 67108888, nil, nil, "headandneckonly_filter")
end

local function Loot(ped)
    if IsPedStopped(ped) then
        if IsEntityInWater(ped) then
            LowCam(ped, 2000)
            da_anim.ped(ped, DrinkDict .. "stand_enter", "enter", 1.0)
            Citizen.Wait(150)
            while IsEntityPlayingAnim(ped, DrinkDict .. "stand_enter", "enter", 3) do Citizen.Wait(0) end
            da_anim.ped(ped, DrinkDict .. "base", "base", nil, 1.5, -1, 33)
            Citizen.Wait(100)
            da_anim.ped(ped, DrinkDict .. "react_look@loop@face", "front_loop", 0.9, 1.5, -1, 57, nil, nil, "facialonly_filter")
            IncreaseStamina(ped, 10)
            return
        end
    end

    local carcass = IsCarcassNearby(ped)
    da_move.toEntity(ped, carcass, EatRange, 20000, 0.8)
    if carcass then
        if IsEntityPlayingAnim(ped, EatDict .. "base", "base", 3) then
            da_anim.ped(ped, EatDict .. "idle", "idle_b", 1.0)
            Citizen.Wait(2500)
        else
            LowCam(ped, 4000)
            da_anim.ped(ped, EatDict .. "stand_enter", "enter", 1.0)
            Citizen.Wait(150)
            while IsEntityPlayingAnim(ped, EatDict .. "stand_enter", "enter", 3) do Citizen.Wait(0) end
            da_anim.ped(ped, EatDict .. "idle", "idle_a", 1.0)

            if BloodPools[carcass] == nil or BloodPools[carcass] > GetGameTimer() then
                BloodPools[carcass] = GetGameTimer() + 5 * 60 * 1000
                local index = GetEntityBoneIndexByName(ped, "skel_head")
                local pos = GetWorldPositionOfEntityBone(ped, index)
                AddBloodPool(pos.x, pos.y, pos.z, 1)
            end

            Citizen.Wait(2000)
        end

        da_anim.ped(ped, EatDict .. "base", "base", nil, 1.5, -1, 1)
        IncreaseHealth(ped, 5)
    end
end

local function ExitEat(ped)
    if IsEntityPlayingAnim(ped, EatDict .. "base", "base", 3) then
        StopAnimTask(ped, EatDict .. "base", "base")
        da_anim.ped(ped, EatDict .. "stand_exit", "exit", 3.0, 500)

    end
end

local function ExitWalk(ped)
    if IsEntityPlayingAnim(ped, SitDict .. "base", "base", 3) then
        da_anim.ped(ped, SitDict .. "walk_exit", "exit", 1.0, nil, 1200)
    end
    if IsEntityPlayingAnim(ped, RestDict .. "base", "base", 3) then
        da_anim.ped(ped, RestDict .. "walk_exit", "exit_front", 1.0, nil, 1200)
    end
    if IsEntityPlayingAnim(ped, SleepDict .. "base", "base", 3) then
        da_anim.ped(ped, SleepDict .. "walk_exit", "exit_front", 1.0, nil, 2000)
    end
end

local function ToggleCrouch(ped)
    if not IsPedStopped(ped) then return end

    if IsEntityPlayingAnim(ped, RestDict .. "stand_enter", "enter", 3) or
        IsEntityPlayingAnim(ped, RestDict .. "walk_enter", "enter", 3) then
        return
    end

    -- Wolf is resting, stand back up
    if IsEntityPlayingAnim(ped, RestDict .. "base", "base", 3) then
        da_anim.ped(ped, RestDict .. "stand_exit", "exit", 1.0, nil, 1000)
        return
    end

    -- Wolf is sitting, stand back up
    if IsEntityPlayingAnim(ped, SitDict .. "base", "base", 3) then
        da_anim.ped(ped, SitDict .. "stand_exit", "exit", 1.0, nil, 300)
        return
    end

    -- Wolf is standing still, sit down
    da_anim.ped(ped, SitDict .. "stand_enter", "enter", 1.0, nil, 2500)
    Citizen.Wait(150)
    while IsEntityPlayingAnim(ped, SitDict .. "stand_enter", "enter", 3) do Citizen.Wait(0) end
    local flags = 1
    da_anim.ped(ped, SitDict .. "base", "base", 1.0, nil, -1, flags)
end

local function Prone(ped)
    if IsEntityInWater(ped) then return end

    -- Wolf is sitting, rest
    if IsEntityPlayingAnim(ped, SitDict .. "base", "base", 3) then
        LowCam(ped, 2000)
        local flags = 1
        da_anim.ped(ped, RestDict .. "base", "base", 1.0, nil, -1, flags)
        return
    end

    -- Wolf is resting, go to sleep
    if IsEntityPlayingAnim(ped, RestDict .. "base", "base", 3) then
        LowCam(ped, 2000)
        local flags = 1
        da_anim.ped(ped, SleepDict .. "base", "base", 0.6, nil, -1, flags)
        return
    end

    -- Wolf is walking or standing still, rest
    if IsPedStopped(ped) then
        LowCam(ped, 2000)
        log.debug("rest blah1")
        da_anim.ped(ped, RestDict .. "stand_enter", "enter")
        Citizen.Wait(150)
        while IsEntityPlayingAnim(ped, RestDict .. "stand_enter", "enter", 3) do Citizen.Wait(0) end
        local flags = 1
        da_anim.ped(ped, RestDict .. "base", "base", 1.0, nil, -1, flags)
    elseif GetEntitySpeed(ped) < 7.0 then
        LowCam(ped, 4000)
        da_anim.ped(ped, RestDict .. "walk_enter", "enter")
        Citizen.Wait(150)
        while IsEntityPlayingAnim(ped, RestDict .. "walk_enter", "enter", 3) do Citizen.Wait(0) end
        local flags = 1
        da_anim.ped(ped, RestDict .. "base", "base", 1.0, nil, -1, flags)
    end
end

da_mode.register({
    name = "wolf",
    priority = 2, -- Lowest priority
    onActivate = function() log.spam("da_mode wolf startFn") end,
    onDeactivate = function() log.spam("da_mode wolf stopFn") end,
    keymaps = {
        {
            key = "HorseMelee",
            event = "justPressed",
            active = true,
            fn = function()
                local ped = PlayerPedId()
                da_control.trackShortPress("HorseMelee", function() ToggleCrouch(ped) end, 100)
                da_control.trackLongPress("HorseMelee", function() Prone(ped) end, 100)
            end
        },
        {
            key = "w",
            event = "justPressed",
            active = true,
            fn = function()
                local ped = PlayerPedId()
                ExitEat(ped)
                ExitWalk(ped)
            end,
        },
        {
            key = "1",
            event = "justPressed",
            active = true,
            fn = function()
                Howl(PlayerPedId())
            end
        },
        {
            key = "2",
            event = "justPressed",
            active = true,
            fn = function()
                Sniff(PlayerPedId())
            end
        },
        {
            key = "3",
            event = "justPressed",
            active = true,
            fn = function()
                SniffHigh(PlayerPedId())
            end
        },
        {
            key = "4",
            event = "justPressed",
            active = true,
            fn = function()
            end
        },
        {
            key = "Loot",
            event = "justPressed",
            active = true,
            fn = function()
                Loot(PlayerPedId())
            end
        },

    }
})

Citizen.CreateThread(function()
    local modeActive = da_mode.isActive("wolf")
    while true do
        local ped = PlayerPedId()
        modeActive = da_mode.isActive("wolf")
        if modeActive ~= IsPedAWolf(ped) then
            if modeActive then da_mode.deactivate("wolf")
            else da_mode.activate("wolf") end
        end
        Citizen.Wait(1000)
    end
end)
