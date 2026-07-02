-- Hold-to-zoom on Right Bracket ] — a baseline Game keymap.
--
-- Registered via da_mode.addGameKey so it rides the "game" baseline; the Mode
-- Controller suppresses it whenever a take-over mode (disableGame = true) is active.
--
-- The gameplay *hint* camera (SetGameplayCoordHint) was tried first but it yields to
-- player look input by design — any mouse movement cancels it. RedM also has no setter
-- for the gameplay cam's own FOV (docs/adr/0010): SET_CAM_FOV only affects scripted cams.
-- So we render a scripted cam at a ramped-down FOV.
--
-- Look while zoomed uses the same capture pattern as da_dev's freecam CheckMovementControls:
-- we DISABLE the native look controls (so the gameplay cam doesn't move), then read the mouse
-- delta off the *disabled* controls (GetDisabledControlNormal) and apply it to our own scripted
-- cam rotation — scaled down by how far we're zoomed (fov/SensRefFov), so a narrow FOV gives
-- finer aim. That's the reduced-sensitivity feel, with no relative-cam math. Position still
-- tracks the gameplay cam so walking works. On release the view eases back to the live gameplay
-- cam rotation, so handing rendering back is smooth instead of a snap.
--
-- Holding alt while zoomed retargets the FOV with mouse up/down (the same gesture as da_dev's
-- freecam) — look is suppressed for that frame so the mouse only dials FOV, and the new target
-- sticks for the rest of the zoom.

local ZoomKey = "LeftBracket"
local TaskFilterChanged = false

local Zoom = {
    KeyHash    = dat.keyHash[ZoomKey],
    TargetFov  = 10.0, -- FOV while fully zoomed in (lower = closer)
    MinFov     = 5.0,  -- floor for the alt+mouse FOV adjust (can't go tighter than this)
    FovRate    = 6.0,  -- FOV units per mouse-delta while adjusting (matches freecam Fov.RateChange)
    RateChange = 1.4,  -- ~FOV units per frame at 60fps (ramp speed, both directions)
    Snap       = 0.05, -- treat as "back home" once FOV is within this of the seed
    LookSpeed  = 6.0,  -- base mouse-look speed (matches da_dev freecam Speed.Mouse)
    SensRefFov = 50.0, -- look is full-speed at/above this FOV; below it scales by fov/ref
    ReturnRate = 8.0,  -- how fast the view eases back to the gameplay cam on release
    Anim = {
        Dict = "script_mp@emotes@look_distance@male@unarmed@upper",
        TaskFilter = "headneckandrightarm_filter"
    }
}

Zoom.Anim.Enter = function(ped, taskFilter)
    if not IsPedHuman(ped) then return end
    local anim = "intro"
    local blendIn = 3.0
    local blendOut = 0.5
    local duration = -1
    local flags = 24
    local rate = 1
    local ikFlags = 0
    taskFilter = taskFilter or Zoom.Anim.TaskFilter
    da_anim.ped(ped, Zoom.Anim.Dict, anim, blendIn, blendOut, duration, flags, rate, ikFlags, taskFilter)
end
Zoom.Anim.Idle = function(ped, taskFilter, force)
    if not IsPedHuman(ped) then return end
    if IsEntityPlayingAnim(ped, Zoom.Anim.Dict, "intro", 3) then return end
    if IsEntityPlayingAnim(ped, Zoom.Anim.Dict, "outro", 3) then return end
    if not force and IsEntityPlayingAnim(ped, Zoom.Anim.Dict, "loop", 49) then return end
    local anim = "loop"
    local blendIn = 3.0
    local blendOut = 0.5
    local duration = -1
    local flags = 25
    local rate = 1
    local ikFlags = 0
    taskFilter = taskFilter or Zoom.Anim.TaskFilter

    StopAnimTask(ped, Zoom.Anim.Dict, "loop", 1.0)
    da_anim.ped(ped, Zoom.Anim.Dict, anim, blendIn, blendOut, duration, flags, rate, ikFlags, taskFilter)
end
Zoom.Anim.Exit = function(ped, taskFilter)
    if not IsPedHuman(ped) then return end
    if IsEntityPlayingAnim(ped, Zoom.Anim.Dict, "outro", 3) then return end
    local anim = "outro"
    local blendIn = 3.0
    local blendOut = 0.5
    local duration = 500
    local flags = 24
    local rate = 1
    local ikFlags = 0
    taskFilter = taskFilter or Zoom.Anim.TaskFilter
    da_anim.ped(ped, Zoom.Anim.Dict, anim, blendIn, blendOut, duration, flags, rate, ikFlags, taskFilter)
end
Zoom.Anim.GetTaskFilter = function(ped)
    if not IsPedHuman(ped) then return "" end
    local armedFilter = "headandneckonly_filter"
    local unarmedFilter = "headneckandrightarm_filter"
    if IsPlayerFreeAiming(ped) == 1 then return armedFilter end
    if da_weapon.unarmed() then return unarmedFilter end
    local primaryWeap = da_weapon.equipped()
    -- if primaryWeap == `weapon_bow` or primaryWeap == `weapon_bow_improved` then return unarmedFilter end
    if primaryWeap ~= `weapon_unarmed` then return armedFilter end
    return unarmedFilter
end

local running = false -- guards against a second thread while one is winding down

local function approach(cur, goal, step)
    if cur < goal then return math.min(cur + step, goal); end
    if cur > goal then return math.max(cur - step, goal); end
    return goal
end

-- Shortest signed difference target - cur, wrapped to (-180, 180] (Lua's % takes the
-- divisor's sign, so the inner result is always 0..360 first). Lets us ease a yaw home
-- across the +/-180 seam without spinning the long way around.
local function angDelta(target, cur)
    return ((target - cur + 180.0) % 360.0) - 180.0
end

local function isZoomKeyDown()
    return IsControlPressed(0, Zoom.KeyHash) == 1 or IsDisabledControlPressed(0, Zoom.KeyHash) == 1
end

-- Alt is disabled while zoomed (so it can't fire its HUD/radar action), so check the
-- disabled state too — matches how the zoom key itself is read above.
local function isAltDown()
    return IsControlPressed(0, dat.keyHash['alt']) == 1 or IsDisabledControlPressed(0, dat.keyHash['alt']) == 1
end

local function runZoom()
    if running then return; end
    running = true
    local ped = PlayerPedId()
    local taskFilter = Zoom.Anim.GetTaskFilter(ped)
    Zoom.Anim.Enter(ped, taskFilter)

    local baseFov = GetGameplayCamFov() + 0.0
    local fov = baseFov
    local zoomedFov = Zoom.TargetFov -- retargetable while zoomed via alt + mouse up/down

    -- Our own rotation, seeded from the gameplay cam so the view starts exactly where we were
    -- looking (rot order 2 / ZXY: x = pitch, y = roll, z = yaw). Roll just rides along.
    local pitch, roll, yaw = table.unpack(GetGameplayCamRot(2))

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, table.unpack(GetGameplayCamCoord()))
    SetCamRot(cam, pitch, roll, yaw, 2)
    SetCamFov(cam, fov)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)

    while true do
        -- DisableAllControlActions(0)
        for _, k in ipairs({
            'MouseLR', 'MouseUD',
            'MouseX', 'MouseY',
            'HorseGunLR', 'HorseGunUD',
            'alt', -- suppress its HUD/radar action; we read it via isAltDown for the FOV gesture
        }) do
            DisableControlAction(0, dat.keyHash[k], true)
        end

        local previousTaskFilter = taskFilter
        taskFilter = Zoom.Anim.GetTaskFilter(ped)
        Zoom.Anim.Idle(ped, taskFilter, taskFilter ~= previousTaskFilter)

        local down = isZoomKeyDown()
        local altHeld = down and isAltDown()

        if altHeld then
            -- Hold alt while zoomed to dial FOV with mouse up/down, same gesture as freecam.
            -- We retarget zoomedFov (not fov directly) so the ramp below carries the change,
            -- and it sticks for the rest of the zoom. Clamped between MinFov and the seed FOV.
            local dUD = GetDisabledControlNormal(0, dat.keyHash['MouseUD'])
            zoomedFov = math.max(Zoom.MinFov, math.min(baseFov, zoomedFov + dUD * Zoom.FovRate))
        end

        local goal = down and zoomedFov or baseFov
        fov = approach(fov, goal, Zoom.RateChange * GetFrameTime() * 60.0)

        if altHeld then
            -- Mouse is driving FOV, not look: hold the view still so it doesn't drift while adjusting.
        elseif down then
            -- Capture the look the way freecam does: disable native look so the gameplay cam
            -- doesn't turn, read the delta off the disabled controls, and apply it to our own
            -- rotation scaled by FOV. (Flip a sign here if an axis ever feels inverted.)
            local dLR  = GetDisabledControlNormal(0, dat.keyHash['MouseLR'])
            local dUD  = GetDisabledControlNormal(0, dat.keyHash['MouseUD'])
            local sens = Zoom.LookSpeed * (math.min(fov, Zoom.SensRefFov) / Zoom.SensRefFov)
            yaw   = yaw - dLR * sens
            pitch = math.max(-89.9, math.min(89.9, pitch - dUD * sens))
        else
            -- Released: ease our view back onto the live gameplay cam orientation (which may
            -- have followed the body if the player moved), so the hand-back below is seamless.
            local k = math.min(1.0, Zoom.ReturnRate * GetFrameTime())
            local tx, _, tz = table.unpack(GetGameplayCamRot(2))
            pitch = pitch + (tx - pitch) * k
            yaw   = yaw + angDelta(tz, yaw) * k
        end

        -- Track the gameplay cam's position (so walking still moves us) but use our own rotation.
        local c = GetGameplayCamCoord()
        SetCamCoord(cam, c.x, c.y, c.z)
        SetCamRot(cam, pitch, roll, yaw, 2)
        SetCamFov(cam, fov)

        -- Released, FOV is home and the view has settled onto the gameplay cam: hand back.
        if not down and math.abs(fov - baseFov) < Zoom.Snap then
            StopAnimTask(ped, Zoom.Anim.Dict, "loop", 1.0)
            Zoom.Anim.Exit(ped, taskFilter)
            local tx, _, tz = table.unpack(GetGameplayCamRot(2))
            if math.abs(tx - pitch) < 0.5 and math.abs(angDelta(tz, yaw)) < 0.5 then break; end
        end
        Citizen.Wait(0)
    end

    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(cam, false)
    running = false
end

-- justPressed only fires while the game baseline owns the key (no take-over mode active),
-- so zoom can only *start* during normal play. The thread then reads the key state
-- directly, so it always resets even if the release event is later suppressed.
da_mode.addGameKey(ZoomKey, {
    justPressed = function()
        Citizen.CreateThread(runZoom)
    end,
})
