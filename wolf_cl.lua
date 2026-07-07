--[[
    Animal control system.

    Lets a player who is possessing an animal ped drive posture/emote
    animations from the keyboard (sit, rest, sleep, howl, sniff, eat, drink...).

    Three layers:
      1. Engine    - generic anim-ref helpers + the enter/hold state machine.
      2. Registry  - maps a ped model to its animal config; the mode activates
                     for any registered animal and hands its config to behaviors.
      3. Config    - per-animal data (models, animation catalog, tunables).
                     All model-specific strings live here. To add an animal,
                     write a config table and registerAnimal() it.
]]

local SetUpEagleEye = function()
    local playerId = PlayerId()
    -- local ped = PlayerPedId()
    EnableEagleeye(playerId, true)
    ModifyInfiniteTrailVision(playerId, false)
    -- Citizen.InvokeNative(0x22C8B10802301381, playerId, 20.0) -- EagleEyeSetRange(playerId, 10)
    -- EagleEyeSetColor(playerId, false)
    Citizen.InvokeNative(0x330CA55A3647FA1C, playerId, true) -- EagleEyeSetHideAllTrails(playerId, true)
end

-- ---------------------------------------------------------------------------
-- Shared state
-- ---------------------------------------------------------------------------
local BloodPools = {}
local ClearCam = false

-- ---------------------------------------------------------------------------
-- Cores (health / stamina)
-- ---------------------------------------------------------------------------
local function IncreaseCore(ped, amount, core)
    local coreValue = Citizen.InvokeNative(0x36731AC041289BB1, ped, core) -- GetAttributeCoreValue
    coreValue = tonumber(coreValue) or 0
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, core, math.ceil(coreValue + amount)) -- SetAttributeCoreValue
end

local function IncreaseHealth(ped, amount) IncreaseCore(ped, amount, 0) end
local function IncreaseStamina(ped, amount) IncreaseCore(ped, amount, 1) end

-- Drop the camera to a low, animal's-eye angle while an animation plays.
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

-- ---------------------------------------------------------------------------
-- Engine: animation references
--
-- An "anim ref" is a { dict = ..., clip = ... } pair. Behaviors name a ref
-- from the config instead of concatenating dictionary + clip strings inline,
-- and pass playback options by name instead of counting positional nils.
-- ---------------------------------------------------------------------------
local function animRef(dict, clip) return { dict = dict, clip = clip } end

local function isPlaying(ped, ref)
    return IsEntityPlayingAnim(ped, ref.dict, ref.clip, 3)
end

-- Play an "enter" clip, wait for it to finish, then hold a "base" loop.
-- This enter -> settle -> hold pattern is shared by sit/rest/sniff/drink/eat.
-- opts: { enter = <da_anim.ped opts>, hold = <da_anim.ped opts> }
local function enterThenHold(ped, enter, hold, opts)
    opts = opts or {}
    da_anim.ped(ped, enter.dict, enter.clip, opts.enter)
    Citizen.Wait(150)
    while isPlaying(ped, enter) do Citizen.Wait(0) end
    da_anim.ped(ped, hold.dict, hold.clip, opts.hold)
end

-- True (returns the carcass) if a dead ped is within `range` of the ped.
local function carcassNear(ped, range)
    local origin = GetEntityCoords(ped)
    for _, other in ipairs(GetGamePool("CPed")) do
        if other ~= ped and DoesEntityExist(other) and IsEntityDead(other) then
            if #(GetEntityCoords(other) - origin) < range then
                return other
            end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Engine: melee combat
--
-- Generic helpers shared by any animal's attack. An "attack profile" is
-- { anim = <ref>, radius, force, damage, cooldown }.
-- ---------------------------------------------------------------------------
local function isPvpEnabled()
    return GetRelationshipBetweenGroups(`PLAYER`, `PLAYER`) == 5
end

local function isValidTarget(ped)
    return not IsPedDeadOrDying(ped) and not (IsPedAPlayer(ped) and not isPvpEnabled())
end

-- Nearest attackable ped within `radius` of coords, excluding `self`.
local function closestTarget(coords, radius, self)
    local itemset = CreateItemset(true)
    local size = Citizen.InvokeNative(0x59B57C4B06531E1E, coords, radius, itemset, 1, Citizen.ResultAsInteger())

    local closest, minDist = nil, radius
    for i = 0, size - 1 do
        local ped = GetIndexedItemInItemset(i, itemset)
        if ped ~= self and isValidTarget(ped) then
            local dist = #(coords - GetEntityCoords(ped))
            if dist < minDist then
                closest, minDist = ped, dist
            end
        end
    end

    if IsItemsetValid(itemset) then DestroyItemset(itemset) end
    return closest
end

local function faceEntity(from, to)
    local a, b = GetEntityCoords(from), GetEntityCoords(to)
    SetEntityHeading(from, GetHeadingFromVector_2d(b.x - a.x, b.y - a.y))
end

-- Ragdoll + damage the target, per the attacker's profile.
local function applyAttack(attacker, target, profile)
    if profile.force > 0 then
        SetPedToRagdoll(target, 1000, 1000, 0, 0, 0, 0)
        SetEntityVelocity(target, GetEntityForwardVector(attacker) * profile.force)
    end
    if profile.damage > 0 then
        ApplyDamageToPed(target, profile.damage, 1, -1, 0)
    end
end

local function playerServerIdFromPed(ped)
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerPed(player) == ped then
            return GetPlayerServerId(player)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------
local Animals = {} -- model hash -> config

local function registerAnimal(cfg)
    for _, model in ipairs(cfg.models) do
        Animals[model] = cfg
    end
end

local function animalFor(ped) return Animals[GetEntityModel(ped)] end

-- ---------------------------------------------------------------------------
-- Config: wolf
--
-- Every wolf clip lives under the same ambient prefix, so the model-specific
-- string is spelled once here. A different animal is just another config with
-- its own prefix/clips/tunables.
-- ---------------------------------------------------------------------------
local function buildWolfAnims()
    local base = "amb_creature_mammal@world_wolf_"
    local r = function(suffix, clip) return animRef(base .. suffix, clip) end
    return {
        howl = r("howling@idle", "idle_a"),
        sniffHigh = r("mark_territory@idle", "idle_a"),
        sniff = {
            enter = r("sniffing_ground@stand_enter", "enter"),
            base  = r("sniffing_ground@base", "base"),
        },
        drink = {
            enter = r("drinking@stand_enter", "enter"),
            base  = r("drinking@base", "base"),
            face  = r("drinking@react_look@loop@face", "front_loop"),
        },
        eat = {
            enter     = r("eating@stand_enter", "enter"),
            base      = r("eating@base", "base"),
            standExit = r("eating@stand_exit", "exit"),
            idleA     = r("eating@idle", "idle_a"),
            idleB     = r("eating@idle", "idle_b"),
        },
        sit = {
            standEnter = r("sitting@stand_enter", "enter"),
            base       = r("sitting@base", "base"),
            standExit  = r("sitting@stand_exit", "exit"),
            walkExit   = r("sitting@walk_exit", "exit"),
        },
        rest = {
            standEnter = r("resting@stand_enter", "enter"),
            walkEnter  = r("resting@walk_enter", "enter"),
            base       = r("resting@base", "base"),
            standExit  = r("resting@stand_exit", "exit"),
            walkExit   = r("resting@walk_exit", "exit_front"),
        },
        sleep = {
            base     = r("sleeping@base", "base"),
            walkExit = r("sleeping@walk_exit", "exit_front"),
        },
    }
end

local WOLF = {
    name = "wolf",
    models = { `a_c_wolf`, `a_c_wolf_small`, `a_c_wolf_medium` },
    -- tunables
    carcassRange    = 5.0, -- how far to look for a meal
    eatRange        = 1.0, -- how close to stand before eating
    healthPerBite   = 5,
    staminaPerDrink = 10,
    howlMaxSpeed    = 4.5, -- above this speed the emote is suppressed
    sniffHighMaxSpeed    = 3.0,
    restMaxSpeed    = 7.0, -- fastest speed that can drop into a walking rest
    anims = buildWolfAnims(),
    -- Melee attack profile (its clip lives outside the ambient prefix).
    attack = {
        anim     = animRef("creatures_mammal@wolf@melee@attacks@streamed_core", "attack"),
        radius   = 3.0,  -- lunge reach
        force    = 3.0,  -- ragdoll knockback velocity
        damage   = 30,
        cooldown = 3000, -- ms between attacks
    },
}

registerAnimal(WOLF)

-- ---------------------------------------------------------------------------
-- Behaviors  (each receives the active animal config + player ped)
-- ---------------------------------------------------------------------------

-- Emote: howl (upper body only, held while standing still-ish).
local function Howl(cfg, ped)
    if GetEntitySpeed(ped) > cfg.howlMaxSpeed then return end
    da_anim.ped(ped, cfg.anims.howl.dict, cfg.anims.howl.clip, {
        blendIn = 0.9, duration = -1, flags = 67108888, filter = "headandneckonly_filter",
    })
end

-- Emote: Sniff the air with head held higher (upper body only).
local function SniffHigh(cfg, ped)
    if GetEntitySpeed(ped) > cfg.sniffHighMaxSpeed then return end
    da_anim.ped(ped, cfg.anims.sniffHigh.dict, cfg.anims.sniffHigh.clip, {
        blendIn = 1.0, duration = -1, flags = 67108888, filter = "headandneckonly_filter",
    })
end

-- Emote: Sniff the ground (only while stopped).
local function Sniff(cfg, ped)
    if not IsPedStopped(ped) then return end
    enterThenHold(ped, cfg.anims.sniff.enter, cfg.anims.sniff.base, {
        enter = { blendIn = 1.0 },
        hold  = { blendOut = 1.5, duration = -1, flags = 33 },
    })
end

-- Drink from water underfoot; restores stamina.
local function Drink(cfg, ped)
    local a = cfg.anims
    LowCam(ped, 2000)
    enterThenHold(ped, a.drink.enter, a.drink.base, {
        enter = { blendIn = 1.0 },
        hold  = { blendOut = 1.5, duration = -1, flags = 33 },
    })
    Citizen.Wait(100)
    da_anim.ped(ped, a.drink.face.dict, a.drink.face.clip, {
        blendIn = 0.9, blendOut = 1.5, duration = -1, flags = 57, filter = "facialonly_filter",
    })
    IncreaseStamina(ped, cfg.staminaPerDrink)
end

-- Approach and eat a nearby carcass; restores health and leaves a blood pool.
local function Eat(cfg, ped)
    local a = cfg.anims
    local carcass = carcassNear(ped, cfg.carcassRange)
    da_move.toEntity(ped, carcass, cfg.eatRange, 20000, 0.8)
    if not carcass then return end

    if isPlaying(ped, a.eat.base) then
        -- Already eating: play a chewing beat.
        da_anim.ped(ped, a.eat.idleB.dict, a.eat.idleB.clip, { blendIn = 1.0 })
        Citizen.Wait(2500)
    else
        LowCam(ped, 4000)
        da_anim.ped(ped, a.eat.enter.dict, a.eat.enter.clip, { blendIn = 1.0 })
        Citizen.Wait(150)
        while isPlaying(ped, a.eat.enter) do Citizen.Wait(0) end
        da_anim.ped(ped, a.eat.idleA.dict, a.eat.idleA.clip, { blendIn = 1.0 })

        if BloodPools[carcass] == nil or BloodPools[carcass] > GetGameTimer() then
            BloodPools[carcass] = GetGameTimer() + 5 * 60 * 1000
            local index = GetEntityBoneIndexByName(ped, "skel_head")
            local pos = GetWorldPositionOfEntityBone(ped, index)
            AddBloodPool(pos.x, pos.y, pos.z, 1)
        end

        Citizen.Wait(2000)
    end

    da_anim.ped(ped, a.eat.base.dict, a.eat.base.clip, { blendOut = 1.5, duration = -1, flags = 1 })
    IncreaseHealth(ped, cfg.healthPerBite)
end

-- Loot key: drink if standing in water, otherwise eat a nearby carcass.
local function Loot(cfg, ped)
    if IsPedStopped(ped) and IsEntityInWater(ped) then
        Drink(cfg, ped)
        return
    end
    Eat(cfg, ped)
end

-- Break out of an eating loop back to standing.
local function ExitEat(cfg, ped)
    local a = cfg.anims
    if isPlaying(ped, a.eat.base) then
        -- StopAnimTask(ped, a.eat.base.dict, a.eat.base.clip)
        da_anim.ped(ped, a.eat.standExit.dict, a.eat.standExit.clip, { blendIn = 3.0, blendOut = 500 })
    end
end

-- Break out of sit/rest/sleep into a walk (triggered by moving forward).
local function ExitWalk(cfg, ped)
    local a = cfg.anims
    if isPlaying(ped, a.sit.base)   then da_anim.ped(ped, a.sit.walkExit.dict, a.sit.walkExit.clip,   { blendIn = 1.0, duration = 1200 }) end
    if isPlaying(ped, a.rest.base)  then da_anim.ped(ped, a.rest.walkExit.dict, a.rest.walkExit.clip,  { blendIn = 1.0, duration = 1200 }) end
    if isPlaying(ped, a.sleep.base) then da_anim.ped(ped, a.sleep.walkExit.dict, a.sleep.walkExit.clip, { blendIn = 1.0, duration = 2000 }) end
end

-- Short press: cycle standing <-> sitting.
local function ToggleCrouch(cfg, ped)
    local a = cfg.anims
    if not IsPedStopped(ped) then return end

    -- Mid-transition into rest: ignore.
    if isPlaying(ped, a.rest.standEnter) or isPlaying(ped, a.rest.walkEnter) then return end

    -- Resting: stand back up.
    if isPlaying(ped, a.rest.base) then
        da_anim.ped(ped, a.rest.standExit.dict, a.rest.standExit.clip, { blendIn = 1.0, duration = 1000 })
        return
    end

    -- Sitting: stand back up.
    if isPlaying(ped, a.sit.base) then
        da_anim.ped(ped, a.sit.standExit.dict, a.sit.standExit.clip, { blendIn = 1.0, duration = 300 })
        return
    end

    -- Standing: sit down.
    enterThenHold(ped, a.sit.standEnter, a.sit.base, {
        enter = { blendIn = 1.0, duration = 2500 },
        hold  = { blendIn = 1.0, duration = -1, flags = 1 },
    })
end

-- Long press: descend one posture deeper (sit -> rest -> sleep).
local function Prone(cfg, ped)
    local a = cfg.anims
    if IsEntityInWater(ped) then return end

    -- Sitting -> resting.
    if isPlaying(ped, a.sit.base) then
        LowCam(ped, 2000)
        da_anim.ped(ped, a.rest.base.dict, a.rest.base.clip, { blendIn = 1.0, duration = -1, flags = 1 })
        return
    end

    -- Resting -> sleeping.
    if isPlaying(ped, a.rest.base) then
        LowCam(ped, 2000)
        da_anim.ped(ped, a.sleep.base.dict, a.sleep.base.clip, { blendIn = 0.6, duration = -1, flags = 1 })
        return
    end

    -- Standing/walking -> resting (from either a standing or moving start).
    if IsPedStopped(ped) then
        LowCam(ped, 2000)
        enterThenHold(ped, a.rest.standEnter, a.rest.base, {
            hold = { blendIn = 1.0, duration = -1, flags = 1 },
        })
    elseif GetEntitySpeed(ped) < cfg.restMaxSpeed then
        LowCam(ped, 4000)
        enterThenHold(ped, a.rest.walkEnter, a.rest.base, {
            hold = { blendIn = 1.0, duration = -1, flags = 1 },
        })
    end
end

-- Melee attack: lunge at the nearest ped and ragdoll/damage it.
local attackCooldown = false
local function Attack(cfg, ped)
    local atk = cfg.attack
    if not atk or attackCooldown then return end
    if IsPedDeadOrDying(ped) or IsPedRagdoll(ped) then return end

    local target = closestTarget(GetEntityCoords(ped), atk.radius, ped)
    if not target then return end

    attackCooldown = true
    faceEntity(ped, target)
    da_anim.ped(ped, atk.anim.dict, atk.anim.clip, { blendIn = 4.0, blendOut = 4.0, duration = -1 })

    -- The attacker can only affect peds it has network control over. For a
    -- player target or an unowned networked ped, ask the server to relay the
    -- hit to the client that does.
    if IsPedAPlayer(target) then
        TriggerServerEvent("da_game:animalAttack", playerServerIdFromPed(target), -1)
    elseif NetworkGetEntityIsNetworked(target) and not NetworkHasControlOfEntity(target) then
        TriggerServerEvent("da_game:animalAttack", -1, PedToNet(target))
    else
        applyAttack(ped, target, atk)
    end

    Citizen.SetTimeout(atk.cooldown, function() attackCooldown = false end)
end

-- Receive an attack relayed from another player's animal and apply it locally.
RegisterNetEvent("da_game:animalAttack")
AddEventHandler("da_game:animalAttack", function(attacker, entity)
    local attackerPed = GetPlayerPed(GetPlayerFromServerId(attacker))
    local cfg = animalFor(attackerPed)
    local atk = cfg and cfg.attack
    if not atk then return end

    if entity == -1 then
        if isPvpEnabled() then applyAttack(attackerPed, PlayerPedId(), atk) end
    else
        applyAttack(attackerPed, NetToPed(entity), atk)
    end
end)

-- ---------------------------------------------------------------------------
-- Input: wrap a behavior so it only fires while possessing a known animal.
-- ---------------------------------------------------------------------------
local function action(fn)
    return function()
        local ped = PlayerPedId()
        local cfg = animalFor(ped)
        if cfg then fn(cfg, ped) end
    end
end

da_mode.register({
    name = "animal",
    priority = 2, -- Lowest priority
    onActivate = function()
        log.spam("da_mode animal startFn")
        SetUpEagleEye()
    end,
    onDeactivate = function()
        log.spam("da_mode animal stopFn")
        local playerId = PlayerId()
        EnableEagleeye(playerId, false)
    end,
    keymaps = {
        {
            key = "HorseMelee",
            event = "justPressed",
            active = true,
            fn = action(function(cfg, ped)
                da_control.trackShortPress("HorseMelee", function() ToggleCrouch(cfg, ped) end, 200)
                da_control.trackLongPress("HorseMelee", function() Prone(cfg, ped) end, 200)
            end),
        },
        {
            key = "w",
            event = "justPressed",
            active = true,
            fn = action(function(cfg, ped)
                ExitEat(cfg, ped)
                ExitWalk(cfg, ped)
            end),
        },
        { key = "MouseLeft", event = "justPressed", active = true, fn = action(Attack) },
        { key = "1", event = "justPressed", active = true, fn = action(Howl) },
        { key = "2", event = "justPressed", active = true, fn = action(Sniff) },
        { key = "3", event = "justPressed", active = true, fn = action(SniffHigh) },
        { key = "4", event = "justPressed", active = true, fn = function()
            -- Testing in progress, this targets the animal in vision and tracks it for Eagle Eye
            local playerId = PlayerId()
            local ped = PlayerPedId()
            SecondarySpecialAbilitySetActive(playerId)
            Citizen.InvokeNative(0xE5D3EB37ABC1EB03, playerId) -- EagleEyeClearRegisteredTrails(playerId)
            local entity = da_raycast.getEntity(500.0, 20.0, ped)
            RegisterEagleEyeForEntity(playerId, entity, false)
            RegisterEagleEyeTrailsForEntity(playerId, entity, false)
            Citizen.InvokeNative(0xBC02B3D151D3859F, entity, true) -- EagleEyeSetRegisteredEntityGlow(entity, true)
            EagleEyeSetCustomEntityTint(entity, 999, 0, 0)
            EagleEyeSetFocusOnAssociatedClueTrail(playerId, entity)
            EagleEyeSetCustomDistance(entity, 100.0)
            -- ModifyInfiniteTrailVision(playerId, true)

            da_hud.Icon.Set(da_hud.Icon.STAMINA_CORE, da_hud.Icon.ALWAYS_HIDE)
            da_hud.Icon.Set(da_hud.Icon.HEALTH, da_hud.Icon.ALWAYS_HIDE)
            da_hud.Icon.Set(da_hud.Icon.HEALTH_CORE, da_hud.Icon.ALWAYS_HIDE)
            da_hud.Icon.Set(da_hud.Icon.DEADEYE, da_hud.Icon.ALWAYS_HIDE)
            da_hud.Icon.Set(da_hud.Icon.DEADEYE_CORE, da_hud.Icon.ALWAYS_HIDE)
        end },
        { key = "5", event = "justPressed", active = true, fn = function()
            -- Testing in progress, this untargets entity that is being looked at
            -- SecondarySpecialAbilitySetDisabled(PlayerId())
            local playerId = PlayerId()
            local entity = da_raycast.getEntity(500.0, 20.0, PlayerPedId())
            UnregisterEagleEyeForEntity(playerId, entity)
            UnregisterEagleEyeTrailsForEntity(playerId, entity)
            EagleEyeSetFocusOnAssociatedClueTrail(playerId, 0)

            da_hud.Icon.Set(da_hud.Icon.STAMINA_CORE, da_hud.Icon.ALWAYS_SHOW)
            da_hud.Icon.Set(da_hud.Icon.HEALTH, da_hud.Icon.ALWAYS_SHOW)
            da_hud.Icon.Set(da_hud.Icon.HEALTH_CORE, da_hud.Icon.ALWAYS_SHOW)
            da_hud.Icon.Set(da_hud.Icon.DEADEYE, da_hud.Icon.ALWAYS_HIDE)
            da_hud.Icon.Set(da_hud.Icon.DEADEYE_CORE, da_hud.Icon.ALWAYS_HIDE)
        end },
        { key = "Loot", event = "justPressed", active = true, fn = action(Loot) },
    },
})

-- Activate the mode whenever the player possesses a registered animal.
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isAnimal = animalFor(ped) ~= nil
        if da_mode.isActive("animal") ~= isAnimal then
            if isAnimal then da_mode.activate("animal")
            else da_mode.deactivate("animal") end
        end
        Citizen.Wait(1000)
    end
end)
