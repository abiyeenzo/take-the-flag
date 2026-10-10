-- Trails that players can buy with coins and wear while running.
local Cosmetics = {}

local function solid(color: Color3)
	return ColorSequence.new(color)
end

Cosmetics.Trails = {
	{ Id = "ember", Name = "Ember", Price = 150, Color = solid(Color3.fromRGB(255, 120, 40)), Swatch = Color3.fromRGB(255, 120, 40) },
	{ Id = "frost", Name = "Frost", Price = 150, Color = solid(Color3.fromRGB(120, 220, 255)), Swatch = Color3.fromRGB(120, 220, 255) },
	{ Id = "toxic", Name = "Toxic", Price = 250, Color = solid(Color3.fromRGB(120, 255, 70)), Swatch = Color3.fromRGB(120, 255, 70) },
	{ Id = "shadow", Name = "Shadow", Price = 300, Color = solid(Color3.fromRGB(120, 60, 200)), Swatch = Color3.fromRGB(120, 60, 200) },
	{ Id = "royal", Name = "Royal", Price = 400, Color = solid(Color3.fromRGB(70, 90, 255)), Swatch = Color3.fromRGB(70, 90, 255) },
	{ Id = "gold", Name = "Gold", Price = 600, Color = solid(Color3.fromRGB(255, 210, 70)), Swatch = Color3.fromRGB(255, 210, 70) },
	{
		Id = "rainbow",
		Name = "Rainbow",
		Price = 1000,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 230, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
		}),
		Swatch = Color3.fromRGB(190, 90, 255),
	},
}

Cosmetics.ById = {}
for _, trail in ipairs(Cosmetics.Trails) do
	Cosmetics.ById[trail.Id] = trail
end

return Cosmetics
