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
			if not hit.Parent then
				return
			end
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

local LOBBY_SIZE = 90
local lobbySign: TextLabel? = nil

local function buildArch(folder: Folder, center: Vector3, color: Color3, label: string)
	local pillarSize = Vector3.new(3, 22, 3)
	for _, side in ipairs({ -1, 1 }) do
		newPart({
			Name = label .. "Pillar",
			Size = pillarSize,
			Position = center + Vector3.new(side * 9, 11, 0),
			Color = Color3.fromRGB(34, 40, 60),
		}, folder)
		neon({
			Name = label .. "PillarGlow",
			Size = Vector3.new(0.6, 20, 3.2),
			Position = center + Vector3.new(side * 7.4, 11, 0),
			Color = color,
		}, folder)
	end
	newPart({
		Name = label .. "Beam",
		Size = Vector3.new(21, 3, 3),
		Position = center + Vector3.new(0, 23.5, 0),
		Color = Color3.fromRGB(34, 40, 60),
	}, folder)
	neon({
		Name = label .. "BeamGlow",
		Size = Vector3.new(21, 0.8, 3.2),
		Position = center + Vector3.new(0, 21.8, 0),
		Color = color,
	}, folder)
	local portal = neon({
		Name = label .. "Portal",
		Size = Vector3.new(14, 20, 0.6),
		Position = center + Vector3.new(0, 10.5, 0),
		Color = color,
		Transparency = 0.7,
	}, folder)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 34
	light.Brightness = 2
	light.Parent = portal
end

local function buildLobby(): Folder
	local old = Workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"

	local c = Config.LobbyCenter
	local half = LOBBY_SIZE / 2

	newPart({
		Name = "LobbyFloor",
		Size = Vector3.new(LOBBY_SIZE, 2, LOBBY_SIZE),
		Position = c + Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(34, 44, 66),
	}, folder)

	-- Glowing ring and soft lines on the floor
	neon({
		Name = "LobbyRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 40, 40),
		CFrame = CFrame.new(c + Vector3.new(0, 0.1, -4)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 200, 255),
		Transparency = 0.6,
	}, folder)
	neon({
		Name = "LobbyRingInner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 22, 22),
		CFrame = CFrame.new(c + Vector3.new(0, 0.12, -4)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 200, 255),
		Transparency = 0.75,
	}, folder)
	for i = -1, 1, 2 do
		neon({
			Name = "LobbyStripe",
			Size = Vector3.new(1, 0.2, LOBBY_SIZE - 10),
			Position = c + Vector3.new(i * 36, 0.1, 0),
			Color = i < 0 and Config.TeamColor("Red") or Config.TeamColor("Blue"),
			Transparency = 0.45,
		}, folder)
	end

	-- Low walls with a soft glowing top
	local wallHeight = 4
	local walls = {
		{ Vector3.new(LOBBY_SIZE + 2, wallHeight, 2), Vector3.new(0, 0, half + 1) },
		{ Vector3.new(LOBBY_SIZE + 2, wallHeight, 2), Vector3.new(0, 0, -half - 1) },
		{ Vector3.new(2, wallHeight, LOBBY_SIZE), Vector3.new(half + 1, 0, 0) },
		{ Vector3.new(2, wallHeight, LOBBY_SIZE), Vector3.new(-half - 1, 0, 0) },
	}
	for i, wall in ipairs(walls) do
		newPart({
			Name = "LobbyWall" .. i,
			Size = wall[1],
			Position = c + wall[2] + Vector3.new(0, wallHeight / 2, 0),
			Color = Color3.fromRGB(40, 50, 76),
		}, folder)
		neon({
			Name = "LobbyWallGlow" .. i,
			Size = wall[1] + Vector3.new(0.2, 0.4 - wallHeight, 0.2),
			Position = c + wall[2] + Vector3.new(0, wallHeight + 0.1, 0),
			Color = Color3.fromRGB(140, 190, 255),
			Transparency = 0.2,
		}, folder)
		-- Invisible tall barrier so nobody leaves the lobby
		newPart({
			Name = "LobbyBarrier" .. i,
			Size = Vector3.new(wall[1].X, 100, wall[1].Z),
			Position = c + wall[2] + Vector3.new(0, 50, 0),
			Transparency = 1,
			CanQuery = false,
		}, folder)
	end
	newPart({
		Name = "LobbyCeiling",
		Size = Vector3.new(LOBBY_SIZE + 4, 2, LOBBY_SIZE + 4),
		Position = c + Vector3.new(0, 101, 0),
		Transparency = 1,
		CanQuery = false,
	}, folder)

	-- Team portal arches at the back of the lobby
	buildArch(folder, c + Vector3.new(-30, 0, half - 4), Config.TeamColor("Red"), "Red")
	buildArch(folder, c + Vector3.new(30, 0, half - 4), Config.TeamColor("Blue"), "Blue")

	-- Big countdown sign between the arches
	for _, side in ipairs({ -1, 1 }) do
		newPart({
			Name = "SignPost",
			Size = Vector3.new(2, 20, 2),
			Position = c + Vector3.new(side * 17, 10, half - 4),
			Color = Color3.fromRGB(34, 40, 60),
		}, folder)
	end
	local board = newPart({
		Name = "LobbySign",
		Size = Vector3.new(40, 12, 1),
		Position = c + Vector3.new(0, 20, half - 4),
		Color = Color3.fromRGB(14, 18, 30),
	}, folder)
	neon({
		Name = "LobbySignFrame",
		Size = Vector3.new(41, 13, 0.8),
		Position = c + Vector3.new(0, 20, half - 3.6),
		Color = Color3.fromRGB(150, 200, 255),
		Transparency = 0.3,
	}, folder)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 245, 255)
	label.Text = "Waiting for players"
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 30)
	padding.PaddingRight = UDim.new(0, 30)
	padding.PaddingTop = UDim.new(0, 40)
	padding.PaddingBottom = UDim.new(0, 40)
	padding.Parent = label
	lobbySign = label

	-- A few glowing pillars of light around the floor
	for _, spot in ipairs({ { -38, -38 }, { 38, -38 }, { -38, 38 }, { 38, 38 } }) do
		local post = neon({
			Name = "LobbyLamp",
			Size = Vector3.new(1.4, 12, 1.4),
			Position = c + Vector3.new(spot[1], 6, spot[2]),
			Color = Color3.fromRGB(150, 220, 255),
			Transparency = 0.2,
		}, folder)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(150, 220, 255)
		light.Range = 36
		light.Brightness = 1.5
		light.Parent = post
	end

	folder.Parent = Workspace
	return folder
end

function MapBuilder.SetLobbySign(text: string)
	if lobbySign then
		lobbySign.Text = text
	end
end

function MapBuilder.RandomLobbyPoint(): Vector3
	local c = Config.LobbyCenter
	return c + Vector3.new(math.random(-32, 32) + math.random(), 4, math.random(-30, 22) + math.random())
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
	buildLobby()

	arena.Parent = Workspace
	info.Lobby = { Center = Config.LobbyCenter }
	return info
end

return MapBuilder
