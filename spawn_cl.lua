-- Player spawn / respawn hook for da_game.
--
-- This server has no spawnmanager dependency, so there's no built-in "playerSpawned"
-- event to hook. Instead we poll the local player ped's alive/active state and fire
-- registered handlers on each transition into a live, controllable ped:
--   * once for the initial spawn after the resource starts, and
--   * again after every death -> respawn.
--
-- Register code with da_game.onSpawn(fn); fn is called as fn(isRespawn) where isRespawn
-- is false for the first spawn and true for every respawn after. A 'da_game:playerSpawned'
-- event is also emitted (same isRespawn arg) so other resources can listen without a
-- dependency on this resource's global.
--
-- Note: HUD contexts and similar per-session settings (see game_cl.lua) can reset on
-- respawn -- this hook is the place to re-apply anything that needs to survive death.

da_game = da_game or {}

local handlers = {} -- list of fns, called as fn(isRespawn)

-- Register a function to run when the local player spawns or respawns.
-- handler(isRespawn): false on the first spawn after this resource starts, true after.
function da_game.onSpawn(handler)
    handlers[#handlers + 1] = handler
end

-- True only once the player is in the session and controlling a living ped.
local function isPlayerSpawned()
    local playerId = PlayerId()
    if NetworkIsPlayerActive(playerId) ~= 1 then return false end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return false end
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return false end

    return true
end

local function fire(isRespawn)
    for _, fn in ipairs(handlers) do
        local ok, err = pcall(fn, isRespawn)
        if not ok then log.error("da_game.onSpawn handler error: " .. tostring(err)) end
    end
    TriggerEvent("da_game:playerSpawned", isRespawn)
end

Citizen.CreateThread(function()
    local wasAlive  = false -- last observed alive state (start dead so the first spawn fires)
    local firstDone = false -- becomes true after the initial spawn; later spawns are respawns

    while true do
        local alive = isPlayerSpawned()

        -- Rising edge: dead/absent -> live, controllable ped.
        if alive and not wasAlive then
            local isRespawn = firstDone
            firstDone = true
            fire(isRespawn)
        end

        wasAlive = alive
        -- Poll a little faster while waiting to (re)spawn than while alive and idle.
        Citizen.Wait(alive and 500 or 200)
    end
end)
