# da_game

Game configuration resource for RedM. Manages HUD context, the base game mode, and world density settings.

## Dependencies

- `da_log`
- `da_lib`

## Installation

1. Place `da_game` in your resources directory
2. Add to `server.cfg` after da_log and da_lib:
   ```
   ensure da_game
   ```

## What It Does

### Game Mode

Registers a `"game"` mode (priority 1) via da_lib's mode system and immediately activates it. This is the baseline mode that is always active — other modes with higher priorities stack on top of it.

### HUD Configuration

Enables the following HUD contexts on startup:
- **Money** — displays the player's currency
- **Ammo** — displays current weapon ammo
- **Skill Cards** — displays skill card UI

Disables:
- **Deadeye Core** — the deadeye core display is hidden

### Ped & Vehicle Density

`cfg_peddensity_cl.lua` runs each frame and sets density multipliers for ambient and scenario peds, animals, and vehicles. The default multiplier is `0.5` (50% of the game's default population density).

**To change density**, edit the `WildernessDensity` value at the top of `cfg_peddensity_cl.lua`:

```lua
local WildernessDensity = 0.5  -- 0.0 = none, 1.0 = full game default
```

This affects:
- Ambient animals and humans
- Scenario animals, humans, and peds
- Parked, random, and active vehicles

## Files

| File | Side | Purpose |
|------|------|---------|
| `game_cl.lua` | Client | Game mode registration, HUD setup |
| `cfg_peddensity_cl.lua` | Client | Per-frame density multipliers |

## Authors

- daggre_actual
