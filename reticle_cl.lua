-- Aim reticle for da_game.
--
-- The native reticle is disabled (see game_cl.lua's HUD_CTX blanket), so this draws a
-- minimal center dot while the player is free-aiming a weapon. It only fades in once
-- aim has been *held* longer than AimHoldMs — a "steadied shot" reticle — and resets the
-- moment aim drops.
--
-- Performance: a single thread that idles at IdleWait ms (a few checks/sec) while not
-- aiming and only spins at Wait(0) — drawing every frame — while actually aiming. No
-- per-frame work, no draws, when you're not holding aim.

local Reticle = {
    AimHoldMs   = 3000,   -- must hold aim this long before the dot starts to appear
    FadeMs      = 600,    -- fade-in duration once the hold threshold is crossed
    Size        = 0.0016, -- dot height as a fraction of screen height
    ScreenRatio = 0.5625, -- 9/16; squares the dot for a 16:9 screen (width = Size * this)
    Color       = { r = 255, g = 255, b = 255 },
    IdleWait    = 250,    -- ms between checks while not aiming
}
Reticle.SizeRatio = Reticle.ScreenRatio * Reticle.Size

-- A bow aims like any other weapon (the steady-hold delay still applies), but the moment
-- the player draws the string — aim (right) + attack (left) held together — the reticle
-- reveals immediately, regardless of how long they've been aiming.
local BowWeapons = {
    [`weapon_bow`]          = true,
    [`weapon_bow_improved`] = true,
}

local function isBowEquipped(ped)
    local _, weaponHash = GetCurrentPedWeapon(ped, true, 0, true) -- active/in-hand weapon
    return BowWeapons[weaponHash] == true
end

local function isDrawingBow()
    local aim    = IsControlPressed(0, `INPUT_AIM`) == 1 or IsDisabledControlPressed(0, `INPUT_AIM`) == 1
    local attack = IsControlPressed(0, `INPUT_ATTACK`) == 1 or IsDisabledControlPressed(0, `INPUT_ATTACK`) == 1
    return aim and attack
end

local function drawDot(alpha)
    DrawRect(0.5, 0.5,
        Reticle.SizeRatio, Reticle.Size,
        Reticle.Color.r, Reticle.Color.g, Reticle.Color.b, alpha)
end

Citizen.CreateThread(function()
    local playerId = PlayerId()
    local aimStart = nil
    local isBow = false  -- cached once per aim (in-hand weapon can't change mid-aim)
    local alpha = 0.0    -- ramps toward 255 when the reticle should show, toward 0 otherwise

    while true do
        local wait = Reticle.IdleWait

        if IsPlayerFreeAiming(playerId) == 1 then
            wait = 0 -- draw every frame while aiming
            local now = GetGameTimer()
            if not aimStart then
                aimStart = now
                isBow = isBowEquipped(PlayerPedId())
                alpha = 0.0
            end

            -- Show once aim has been held steady long enough, or the instant a bow is drawn.
            local steadied = (now - aimStart) >= Reticle.AimHoldMs
            local shouldShow = steadied or (isBow and isDrawingBow())

            -- Ramp alpha toward the target over FadeMs (smooth in and out, either trigger).
            local step = (GetFrameTime() * 1000.0) / Reticle.FadeMs * 255.0
            alpha = shouldShow and math.min(alpha + step, 255.0) or math.max(alpha - step, 0.0)

            if alpha > 0.0 then drawDot(math.floor(alpha)) end
        else
            aimStart = nil -- dropped aim: reset (re-aiming restarts the hold)
            alpha = 0.0
        end

        Citizen.Wait(wait)
    end
end)
