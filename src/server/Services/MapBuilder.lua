local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MapBuilder = {}

local FLOOR_COLOR = Color3.fromRGB(24, 27, 40)
local COVER_COLORS = {
	Color3.fromRGB(38, 44, 66),
	Color3.fromRGB(46, 52, 78),
	Color3.fromRGB(33, 38, 58),
}

local function newPart(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function neon(props: { [string]: any }, parent: Instance): Part
	props.Material = Enum.Material.Neon
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return newPart(props, parent)
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(46, 52, 84)
	Lighting.OutdoorAmbient = Color3.fromRGB(62, 68, 104)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.GlobalShadows = true

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.2
	color.Contrast = 0.12
	color.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(110, 120, 190)
	atmosphere.Decay = Color3.fromRGB(40, 40, 80)
	atmosphere.Parent = Lighting
end

local function buildFloorAndWalls(arena: Folder)
	local length, width = Config.ArenaLength, Config.ArenaWidth

	newPart({
		Name = "Floor",
		Size = Vector3.new(length + 60, 2, width + 40),
		Position = Vector3.new(0, -1, 0),
		Color = FLOOR_COLOR,
	}, arena)

	neon({
		Name = "CenterLine",
		Size = Vector3.new(1, 0.2, width),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(190, 200, 255),
		Transparency = 0.35,
	}, arena)

	local ring = neon({
		Name = "CenterRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 44, 44),
		CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 200, 255),
		Transparency = 0.6,
	}, arena)
	ring.Name = "CenterRing"

	-- Low visible rim all around the playfield
	local rimHeight = 6
	local halfL, halfW = length / 2 + 25, width / 2 + 15
	local rims = {
		{ Vector3.new(2, rimHeight, halfW * 2), Vector3.new(halfL, rimHeight / 2, 0) },
		{ Vector3.new(2, rimHeight, halfW * 2), Vector3.new(-halfL, rimHeight / 2, 0) },
		{ Vector3.new(halfL * 2, rimHeight, 2), Vector3.new(0, rimHeight / 2, halfW) },
		{ Vector3.new(halfL * 2, rimHeight, 2), Vector3.new(0, rimHeight / 2, -halfW) },
	}
	for i, rim in ipairs(rims) do
		newPart({ Name = "Rim" .. i, Size = rim[1], Position = rim[2], Color = Color3.fromRGB(30, 34, 52) }, arena)
		neon({
			Name = "RimGlow" .. i,
			Size = rim[1] + Vector3.new(0.2, 0, 0.2) - Vector3.new(0, rimHeight - 0.4, 0),
			Position = rim[2] + Vector3.new(0, rimHeight / 2 - 0.2, 0),
			Color = Color3.fromRGB(120, 140, 255),
		}, arena)
	end

	-- Invisible tall walls so nobody leaves the arena
	for i, rim in ipairs(rims) do
		newPart({
			Name = "Barrier" .. i,
			Size = Vector3.new(rim[1].X, 120, rim[1].Z),
			Position = rim[2] + Vector3.new(0, 60, 0),
			Transparency = 1,
			CanQuery = false,
		}, arena)
	end
	newPart({
		Name = "Ceiling",
		Size = Vector3.new(length + 60, 2, width + 40),
		Position = Vector3.new(0, 121, 0),
		Transparency = 1,
		CanQuery = false,
	}, arena)
end

local function buildBase(arena: Folder, teamDef: any, sign: number)
	local baseX = sign * Config.BaseOffset
	local color = teamDef.Color
	local folder = Instance.new("Folder")
	folder.Name = teamDef.Name .. "Base"
	folder.Parent = arena

	newPart({
		Name = "Platform",
		Size = Vector3.new(44, 1, 70),
		Position = Vector3.new(baseX, 0.5, 0),
		Color = Color3.fromRGB(30, 34, 52),
	}, folder)
	neon({
		Name = "PlatformEdge",
		Size = Vector3.new(0.6, 0.3, 70),
		Position = Vector3.new(baseX - sign * 22, 1.05, 0),
		Color = color,
	}, folder)

	-- Back wall with a glowing stripe
	newPart({
		Name = "BackWall",
		Size = Vector3.new(2, 16, 70),
		Position = Vector3.new(baseX + sign * 24, 8, 0),
		Color = Color3.fromRGB(26, 29, 46),
	}, folder)
	neon({
		Name = "BackStripe",
		Size = Vector3.new(2.2, 1.2, 70),
		Position = Vector3.new(baseX + sign * 24, 12, 0),
		Color = color,
	}, folder)

	-- Capture pad under the flag
	local padPosition = Vector3.new(baseX, 1.1, 0)
	local pad = neon({
		Name = "CapturePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = CFrame.new(padPosition) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.3,
	}, folder)
	pad.CanTouch = true

	-- A collision plate slightly above so the touch event is reliable
	local trigger = newPart({
		Name = "CaptureTrigger",
		Size = Vector3.new(12, 6, 12),
		Position = Vector3.new(baseX, 4, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, folder)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 30
	light.Brightness = 2
	light.Parent = pad

	-- Spawn pads behind the flag
	for i = -2, 2 do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(baseX + sign * 14, 1.5, i * 11)
		spawn.Neutral = false
		spawn.TeamColor = teamDef.BrickColor
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0
		spawn.Material = Enum.Material.Neon
		spawn.Color = color
		spawn.Transparency = 0.55
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = folder
	end

	return {
		FlagPosition = Vector3.new(baseX, 1.2, 0),
		Trigger = trigger,
		Pad = pad,
	}
end

local function buildCover(arena: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Cover"
	folder.Parent = arena

	-- x, z, width, height, depth: mirrored on both sides of the field
	local layout = {
		{ -62, -32, 8, 7, 8 },
		{ -62, 32, 8, 7, 8 },
		{ -44, 0, 6, 10, 22 },
		{ -26, -42, 16, 4, 6 },
		{ -26, 42, 16, 4, 6 },
		{ -12, -20, 6, 5, 6 },
		{ -12, 20, 6, 5, 6 },
		{ -76, 0, 4, 4, 18 },
		{ -30, 0, 5, 3, 5 },
	}

	local index = 0
	local function place(x: number, z: number, sx: number, sy: number, sz: number)
		index += 1
		local color = COVER_COLORS[index % #COVER_COLORS + 1]
		newPart({
			Name = "Block",
			Size = Vector3.new(sx, sy, sz),
			Position = Vector3.new(x, sy / 2, z),
			Color = color,
		}, folder)
		neon({
			Name = "BlockTrim",
			Size = Vector3.new(sx + 0.2, 0.3, sz + 0.2),
			Position = Vector3.new(x, sy + 0.05, z),
			Color = Color3.fromRGB(120, 140, 255),
			Transparency = 0.2,
		}, folder)
	end

	for _, entry in ipairs(layout) do
		place(entry[1], entry[2], entry[3], entry[4], entry[5])
		place(-entry[1], entry[2], entry[3], entry[4], entry[5])
	end

	-- Raised center platform
	place(0, 0, 16, 3, 16)
end

local function buildJumpPads(arena: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "JumpPads"
	folder.Parent = arena

	local debounce: { [Player]: number } = {}
	local positions = { { -34, -50 }, { -34, 50 }, { 34, -50 }, { 34, 50 } }

	for _, p in ipairs(positions) do
		local x, z = p[1], p[2]
		local pad = neon({
			Name = "JumpPad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 9, 9),
			CFrame = CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(80, 255, 220),
		}, folder)
		pad.CanTouch = true

		local sensor = newPart({
			Name = "JumpSensor",
			Size = Vector3.new(8, 3, 8),
			Position = Vector3.new(x, 1.8, z),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}, folder)
		sensor.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			local now = os.clock()
			if debounce[player] and now - debounce[player] < 1 then
				return
			end
			debounce[player] = now
			Remotes.AbilityFx:FireClient(player, "Bounce", Vector3.new(-math.sign(x) * 22, 0, 0))
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		debounce[player] = nil
	end)
end

function MapBuilder.Build()
	setupLighting()

	local old = Workspace:FindFirstChild("Arena")
	if old then
		old:Destroy()
	end
	local arena = Instance.new("Folder")
	arena.Name = "Arena"

	buildFloorAndWalls(arena)
	local info = {}
	info.Red = buildBase(arena, Config.Teams[1], -1)
	info.Blue = buildBase(arena, Config.Teams[2], 1)
	buildCover(arena)
	buildJumpPads(arena)

	arena.Parent = Workspace
	return info
end

return MapBuilder
