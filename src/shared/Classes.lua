-- Playable classes. Level is the player level needed to unlock the class.
local Classes = {}

Classes.Order = { "Striker", "Scout", "Guardian" }

Classes.Defs = {
	Striker = {
		Id = "Striker",
		Name = "Striker",
		Level = 1,
		Health = 100,
		Speed = 16,
		DamageMult = 1.0,
		Ability = "Overcharge",
		AbilityDuration = 5,
		Cooldown = 14,
		Description = "Balanced fighter. Overcharge boosts damage and fire rate for 5 seconds.",
	},
	Scout = {
		Id = "Scout",
		Name = "Scout",
		Level = 3,
		Health = 85,
		Speed = 21,
		DamageMult = 0.9,
		Ability = "Dash",
		AbilityDuration = 0,
		Cooldown = 6,
		Description = "Fast flag runner. Dash launches you forward in a flash.",
	},
	Guardian = {
		Id = "Guardian",
		Name = "Guardian",
		Level = 5,
		Health = 150,
		Speed = 13.5,
		DamageMult = 1.0,
		Ability = "Shield",
		AbilityDuration = 3,
		Cooldown = 16,
		Description = "Tough defender. Shield blocks all damage for 3 seconds.",
	},
}

Classes.Default = "Striker"

return Classes
