-- Relay an animal melee attack from the attacker to the client that owns the
-- affected entity. The attacker triggers this with (target, entity):
--   target ~= -1 : a player's server id     -> forward to that player (PvP)
--   entity ~= -1 : a networked entity's id  -> broadcast so its owner applies it
RegisterNetEvent("da_game:animalAttack")
AddEventHandler("da_game:animalAttack", function(target, entity)
    TriggerClientEvent("da_game:animalAttack", target, source, entity)
end)
