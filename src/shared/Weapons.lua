-- Weapons. Firing stats come from the weapon, damage is then scaled by the class DamageMult.
-- CoinPrice == nil and VipOnly == nil means the weapon is free and owned by everyone.
-- RobuxKey points at an entry of Monetization.Products that sells the weapon for Robux.
local Weapons = {}

Weapons.Order = { "Blaster", "Pulse", "Scatter", "Rail", "GoldBlaster" }
Weapons.Default = "Blaster"

Weapons.Defs = {
	Blaster = {
		Id = "Blaster",
		Name = "Blaster",
		Description = "Reliable all-rounder.",
		Damage = 18,
		FireDelay = 0.18,
		Pellets = 1,
		SpreadDeg = 0.5,
		Range = 400,
		HandleSize = Vector3.new(0.6, 0.9, 2.4),
		Color = Color3.fromRGB(40, 44, 60),
	},
	Pulse = {
		Id = "Pulse",
		Name = "Pulse SMG",
		Description = "Very fast fire, a bit wild at range.",
		Damage = 10,
		FireDelay = 0.085,
		Pellets = 1,
		SpreadDeg = 2.2,
		Range = 300,
		CoinPrice = 600,
		RobuxKey = "weapon_pulse",
		HandleSize = Vector3.new(0.6, 0.8, 1.9),
		Color = Color3.fromRGB(45, 70, 90),
	},
	Scatter = {
		Id = "Scatter",
		Name = "Scatter Cannon",
		Description = "Eight pellets in a wide burst. Best up close.",
		Damage = 9,
		FireDelay = 0.85,
		Pellets = 8,
		SpreadDeg = 6,
		Range = 90,
		CoinPrice = 900,
		RobuxKey = "weapon_scatter",
		HandleSize = Vector3.new(0.8, 1.0, 2.8),
		Color = Color3.fromRGB(80, 50, 45),
	},
	Rail = {
		Id = "Rail",
		Name = "Rail Rifle",
		Description = "One slow, precise, heavy shot.",
		Damage = 55,
		FireDelay = 0.8,
		Pellets = 1,
		SpreadDeg = 0,
		Range = 500,
		CoinPrice = 1500,
		RobuxKey = "weapon_rail",
		HandleSize = Vector3.new(0.5, 0.8, 3.4),
		Color = Color3.fromRGB(60, 40, 90),
	},
	GoldBlaster = {
		Id = "GoldBlaster",
		Name = "Golden Blaster",
		Description = "VIP exclusive skin of the Blaster.",
		Damage = 18,
		FireDelay = 0.18,
		Pellets = 1,
		SpreadDeg = 0.5,
		Range = 400,
		VipOnly = true,
		HandleSize = Vector3.new(0.6, 0.9, 2.4),
		Color = Color3.fromRGB(235, 190, 60),
	},
}

return Weapons
