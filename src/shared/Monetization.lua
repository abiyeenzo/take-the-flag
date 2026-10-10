-- Robux items. Create each one in the Creator Hub (Monetization) and paste its id here.
-- Id = 0 means "not created yet": the shop shows it as unavailable.
-- Robux is only the displayed price. The real price is the one set in the Creator Hub.
local Monetization = {}

Monetization.GamePasses = {
	VIP = {
		Id = 2026040351,
		Name = "VIP",
		Robux = 299,
		Description = "Double coins, 25% more XP, the Golden Blaster and the Aurora trail.",
	},
}

Monetization.Products = {
	coins_small = { Id = 3717584812, Name = "500 Coins", Robux = 49, Coins = 500 },
	coins_medium = { Id = 3717584912, Name = "2,000 Coins", Robux = 149, Coins = 2000 },
	coins_large = { Id = 3717584967, Name = "6,000 Coins", Robux = 399, Coins = 6000 },
	weapon_pulse = { Id = 3717585068, Name = "Pulse SMG", Robux = 79, Weapon = "Pulse" },
	weapon_scatter = { Id = 3717585162, Name = "Scatter Cannon", Robux = 129, Weapon = "Scatter" },
	weapon_rail = { Id = 3717585221, Name = "Rail Rifle", Robux = 199, Weapon = "Rail" },
}

-- Display order for the coin packs in the shop
Monetization.CoinPackOrder = { "coins_small", "coins_medium", "coins_large" }

function Monetization.IsAvailable(entry: { Id: number }): boolean
	return entry.Id ~= 0
end

return Monetization
