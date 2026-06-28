-- Hold-to-zoom on Left Bracket [ — a baseline Game keymap.
--
-- Registered via da_mode.addGameKey so it rides the "game" baseline; the Mode
-- Controller suppresses it whenever a take-over mode (disableGame = true) is active.
--
-- The gameplay *hint* camera (SetGameplayCoordHint) was tried first but it yields to
-- player look input by design — any mouse movement cancels it, so it fought a zoom you
-- can still look around in. RedM also has no setter for the gameplay cam's own FOV
-- (docs/adr/0010): SET_CAM_FOV only affects scripted cams. So we render a scripted cam
-- that mirrors the gameplay cam's coord/rot every frame — free look is preserved because
-- mouse-look still drives the gameplay cam underneath — at a ramped-down FOV. Releasing
-- ramps the FOV back to the seed and hands rendering back to the gameplay cam.

local ZoomInput = `INPUT_SNIPER_ZOOM_OUT_ONLY` -- the control the [ key is bound to

local Zoom = {
    TargetFov  = 10.0, -- FOV while fully zoomed in (lower = closer)
    RateChange = 1.4,  -- ~FOV units per frame at 60fps (ramp speed, both directions)
    Snap       = 0.05, -- stop rendering once back within this of the seed FOV
}

local running = false -- guards against a second thread while one is winding down

local function approach(cur, goal, step)
    if cur < goal then return math.min(cur + step, goal); end
    if cur > goal then return math.max(cur - step, goal); end
    return goal
end

local function isZoomKeyDown()
    return IsControlPressed(0, ZoomInput) == 1 or IsDisabledControlPressed(0, ZoomInput) == 1
end

local function runZoom()
    if running then return; end
    running = true

    local baseFov = GetGameplayCamFov() + 0.0
    local fov = baseFov

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(cam, fov)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)

    while true do
        local down = isZoomKeyDown()
        local goal = down and Zoom.TargetFov or baseFov
        fov = approach(fov, goal, Zoom.RateChange * GetFrameTime() * 60.0)

        -- Mirror the gameplay cam so mouse-look/movement still drive the view (rot order 2 / ZXY).
        local c = GetGameplayCamCoord()
        local r = GetGameplayCamRot(2)
        SetCamCoord(cam, c.x, c.y, c.z)
        SetCamRot(cam, r.x, r.y, r.z, 2)
        SetCamFov(cam, fov)

        -- Released and ramped back to the seed FOV: tear down, return to the gameplay cam.
        if not down and math.abs(fov - baseFov) < Zoom.Snap then break; end
        Citizen.Wait(0)
    end

    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(cam, false)
    running = false
end

-- justPressed only fires while the game baseline owns the key (no take-over mode active),
-- so zoom can only *start* during normal play. The thread then reads the key state
-- directly, so it always resets even if the release event is later suppressed.
da_mode.addGameKey("LeftBracket", {
    justPressed = function()
        Citizen.CreateThread(runZoom)
    end,
})
