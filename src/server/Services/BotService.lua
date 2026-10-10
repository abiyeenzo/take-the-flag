-- Bots fill the match so nobody plays alone. They are actors (see Actors.lua): a plain table
-- with a real R15 character, no Player instance, no data, no coins.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Actors = require(script.Parent.Actors)
local ClassService = require(script.Parent.ClassService)
local CombatService = require(script.Parent.CombatService)
local FlagService = require(script.Parent.FlagService)
local MapBuilder = require(script.Parent.MapBuilder)
local TeamService = require(script.Parent.TeamService)

local BotService = {}

type Bot = any

local NAMES = {
	"Dragon_Slayer07", "xKaiden", "PixelPanda", "NovaStrike", "TacoWizard", "Frostbyte22",
	"LunaFox", "BlockBuddy99", "SkyRunner", "Mr_Zigzag", "CosmoKid", "TurboTurtle",
	"NightOwl_X", "ZapZap2010", "RiverStone", "Jelly_Bean_", "ShadowMango", "RocketRaccoon",
	"IcyPhoenix", "MiloTheGreat", "SirPancake", "Glitchy_Gus", "AquaBlitz", "PepperJack",
	"KiwiCrusher", "Orbit_Ollie", "StarDustDan", "BoltBunny", "YetiSpaghetti", "CrimsonLark",
	"MegaMuffin", "Dash_Dasher", "TinyTornado", "ZenKoala", "PixelPirate", "Echo_Ranger",
	"CoolCucumber", "SwiftSparrow", "HyperHedgehog", "LavaLlama", "WaffleKnight", "NeonNinja_",
	"Captain_Crumb", "Skylar_J", "DinoDude88", "FizzyPop", "Maverick_Mo", "SunnyDaze",
	"ThunderThumbs", "Quiet_Quokka", "RedPandaRush", "Mochi_Mage", "ByteBandit", "Gizmo_Gal",
	"OtterOdyssey", "BravoBeans", "Nimbus_Nate", "CupcakeCommando", "LittleLynx", "VortexVic",
}

local SKIN_TONES = {
	Color3.fromRGB(255, 219, 172), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36), Color3.fromRGB(94, 60, 38), Color3.fromRGB(245, 205, 160),
}
local OUTFIT_COLORS = {
	Color3.fromRGB(70, 90, 140), Color3.fromRGB(60, 120, 90), Color3.fromRGB(200, 160, 60),
	Color3.fromRGB(150, 70, 70), Color3.fromRGB(80, 80, 90), Color3.fromRGB(230, 230, 235),
	Color3.fromRGB(60, 140, 160), Color3.fromRGB(190, 110, 60), Color3.fromRGB(40, 40, 50),
}

local ANIM_IDS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
	tool = "rbxassetid://507768375",
}

local CLASS_WEIGHTS = { { "Striker", 50 }, { "Scout", 30 }, { "Guardian", 20 } }

local SIGHT_RANGE = 70
local ARENA_SPAWN_PADS = { -2, -1, 0, 1, 2 }

local nextBotId = 0
local started = false
local syncing = false

local function now(): number
	return os.clock()
end

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function isPlaying(): boolean
	return Workspace:GetAttribute("RoundState") == "Playing"
end

local function pickName(): string
	local used: { [string]: boolean } = {}
	for _, actor in ipairs(Actors.All()) do
		used[string.lower(actor.Name)] = true
	end
	local pool = {}
	for _, name in ipairs(NAMES) do
		if not used[string.lower(name)] then
			table.insert(pool, name)
		end
	end
	if #pool > 0 then
		return pool[math.random(1, #pool)]
	end
	return "Player" .. math.random(1000, 9999)
end

local function pickClass(): string
	local total = 0
	for _, entry in ipairs(CLASS_WEIGHTS) do
		total += entry[2]
	end
	local roll = math.random() * total
	for _, entry in ipairs(CLASS_WEIGHTS) do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1]
		end
	end
	return Classes.Default
end

local function pickWeapon(): string
	local pool = {}
	for _, id in ipairs(Weapons.Order) do
		local def = Weapons.Defs[id]
		if def and not def.VipOnly then
			table.insert(pool, id)
		end
	end
	return pool[math.random(1, #pool)] or Weapons.Default
end

local function makeBot(): Bot
	nextBotId += 1
	local attributes: { [string]: any } = {}
	local bot: Bot = {
		Name = pickName(),
		UserId = -(1000 + nextBotId),
		IsBot = true,
		Team = nil,
		Character = nil,
		Class = Classes.Default,
		Weapon = Weapons.Default,
		Attrs = attributes,
		Mode = "Lobby",
		Generation = 0,
		Alive = false,
		Role = "Attacker",
	}
	function bot.GetAttribute(_self: Bot, key: string): any
		return attributes[key]
	end
	function bot.SetAttribute(_self: Bot, key: string, value: any)
		attributes[key] = value
	end
	return bot
end

------------------------------------------------------------------------------------------------
-- Character creation and animation
------------------------------------------------------------------------------------------------

local function randomDescription(): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN_TONES[math.random(1, #SKIN_TONES)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = OUTFIT_COLORS[math.random(1, #OUTFIT_COLORS)]
	local legs = OUTFIT_COLORS[math.random(1, #OUTFIT_COLORS)]
	desc.LeftLegColor = legs
	desc.RightLegColor = legs
	return desc
end

local function setupAnimation(bot: Bot, humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animatorInstance = animator :: Animator

	local priorities: { [string]: Enum.AnimationPriority } = {
		idle = Enum.AnimationPriority.Idle,
		walk = Enum.AnimationPriority.Movement,
		run = Enum.AnimationPriority.Movement,
		jump = Enum.AnimationPriority.Action,
		fall = Enum.AnimationPriority.Action,
		tool = Enum.AnimationPriority.Action2,
	}
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in pairs(ANIM_IDS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animatorInstance:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = priorities[name]
			track.Looped = name ~= "jump"
			tracks[name] = track
		end
	end

	local current: string? = nil
	local function play(name: string, speed: number?)
		local track = tracks[name]
		if not track then
			return
		end
		if current ~= name then
			if current and tracks[current] then
				tracks[current]:Stop(0.2)
			end
			current = name
			track:Play(0.2)
		end
		if speed then
			track:AdjustSpeed(speed)
		end
	end

	local airborne = false
	humanoid.Running:Connect(function(speed)
		if airborne then
			return
		end
		if speed < 0.5 then
			play("idle")
		elseif speed > 13 then
			play("run", speed / 20)
		else
			play("walk", speed / 12)
		end
	end)
	humanoid.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Jumping then
			airborne = true
			play("jump")
		elseif new == Enum.HumanoidStateType.Freefall then
			airborne = true
			play("fall")
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			if airborne then
				airborne = false
				current = nil
				if tracks.jump then
					tracks.jump:Stop(0.1)
				end
				if tracks.fall then
					tracks.fall:Stop(0.1)
				end
				play(humanoid.MoveDirection.Magnitude > 0.1 and "run" or "idle")
			end
		end
	end)
	play("idle")
	if tracks.tool then
		tracks.tool:Play(0.2)
	end
	bot.PlayAnim = play
end

local function addNameTag(bot: Bot, character: Model, humanoid: Humanoid)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BotTag"
	gui.Size = UDim2.fromOffset(160, 24)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 130
	gui.AlwaysOnTop = false
	gui.Adornee = head :: BasePart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Text = bot.Name
	label.TextColor3 = bot.Team and Config.TeamColor(bot.Team.Name) or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = head
end

local function destroyCharacter(bot: Bot)
	FlagService.DropIfCarrying(bot)
	local character = bot.Character
	bot.Character = nil
	bot.Alive = false
	if character then
		character:Destroy()
	end
end

local function spawnCFrame(bot: Bot, mode: string): CFrame
	if mode == "Lobby" then
		return CFrame.new(MapBuilder.RandomLobbyPoint())
	end
	local sign = (bot.Team and bot.Team.Name == "Red") and -1 or 1
	local pad = ARENA_SPAWN_PADS[math.random(1, #ARENA_SPAWN_PADS)]
	local position = Vector3.new(sign * Config.BaseOffset + sign * 14, 4, pad * 11)
	-- face the middle of the field
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

local function resetAiState(bot: Bot)
	bot.Waypoints = nil
	bot.WpIndex = 1
	bot.Pathing = false
	bot.PathGoal = nil
	bot.PathTime = 0
	bot.PathRefresh = rand(1.5, 3)
	bot.LastPos = nil
	bot.LastPosTime = now()
	bot.Target = nil
	bot.ReactAt = 0
	bot.NextShot = 0
	bot.BurstLeft = 0
	bot.StrafeDir = 1
	bot.StrafeUntil = 0
	bot.WanderAt = 0
	bot.PatrolPoint = nil
	bot.PatrolAt = 0
end

local function respawn(bot: Bot, mode: string, attempt: number?)
	local tries = attempt or 1
	if tries == 1 then
		bot.Generation += 1
	end
	local generation = bot.Generation
	destroyCharacter(bot)
	if isPlaying() then
		mode = "Arena"
	end
	bot.Mode = mode

	local function retry()
		if tries >= 5 then
			warn("BotService: could not create a bot character")
			return
		end
		task.delay(2, function()
			if bot.Generation == generation then
				respawn(bot, mode, tries + 1)
			end
		end)
	end

	if not bot.Team then
		Actors.SetTeam(bot, TeamService.SmallestTeam())
	end

	bot.Class = pickClass()
	bot.Weapon = pickWeapon()
	bot.Role = math.random() < 0.6 and "Attacker" or "Defender"
	resetAiState(bot)

	local description = randomDescription()
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if not ok or not model then
		retry()
		return
	end
	if bot.Generation ~= generation then
		model:Destroy()
		return
	end

	model.Name = bot.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		model:Destroy()
		retry()
		return
	end
	humanoid.DisplayName = bot.Name

	model:PivotTo(spawnCFrame(bot, mode))
	model:SetAttribute("TeamName", bot.Team and bot.Team.Name or "")
	model:SetAttribute("IsBot", true)
	bot.Character = model
	bot.Alive = true
	model.Parent = Workspace

	pcall(function()
		(hrp :: BasePart):SetNetworkOwner(nil)
	end)

	addNameTag(bot, model, humanoid)
	setupAnimation(bot, humanoid)

	pcall(function()
		ClassService.ApplyClass(bot, model)
	end)
	CombatService.WatchCharacter(bot, model)

	local teamColor = bot.Team and Config.TeamColor(bot.Team.Name) or Color3.new(1, 1, 1)
	local toolOk, tool = pcall(function()
		return ClassService.MakeWeaponTool(bot.Weapon, teamColor)
	end)
	if toolOk and tool then
		humanoid:EquipTool(tool)
	end

	humanoid.Died:Connect(function()
		if bot.Generation ~= generation then
			return
		end
		bot.Alive = false
		task.delay(Config.RespawnTime, function()
			if bot.Generation ~= generation then
				return
			end
			if isPlaying() and bot.Mode == "Arena" then
				respawn(bot, "Arena")
			else
				-- not in a live match: back to the lobby
				respawn(bot, "Lobby")
			end
		end)
	end)
end

------------------------------------------------------------------------------------------------
-- Public lifecycle
------------------------------------------------------------------------------------------------

local function removeBot(bot: Bot)
	bot.Generation += 1
	destroyCharacter(bot)
	Actors.UnregisterBot(bot)
end

function BotService.RemoveAll()
	for _, bot in ipairs(Actors.BotList()) do
		removeBot(bot)
	end
end

-- Makes humans + bots equal Config.BotTargetPlayers. Call between rounds only.
local pending = false

local function wantedBots(): number
	local humans = #Actors.Humans()
	if humans > 0 and humans < Config.BotTargetPlayers then
		return Config.BotTargetPlayers - humans
	end
	return 0
end

function BotService.Sync()
	if syncing then
		pending = true
		return
	end
	syncing = true
	local ok, err = pcall(function()
		local list = Actors.BotList()
		-- remove extras, taking them from the bigger team first (humans count too)
		while #list > wantedBots() do
			local victim = nil
			local biggest = -1
			for _, bot in ipairs(list) do
				local size = bot.Team and Actors.CountOnTeam(bot.Team) or 0
				if size > biggest then
					biggest = size
					victim = bot
				end
			end
			victim = victim or list[#list]
			table.remove(list, table.find(list, victim) :: number)
			removeBot(victim)
		end

		while #list < wantedBots() and not isPlaying() do
			local bot = makeBot()
			Actors.RegisterBot(bot)
			Actors.SetTeam(bot, TeamService.SmallestTeam())
			table.insert(list, bot)
			task.spawn(respawn, bot, "Lobby")
			task.wait(0.15)
		end
	end)
	syncing = false
	if not ok then
		warn("BotService sync: " .. tostring(err))
	end
	if pending then
		pending = false
		BotService.Sync()
	end
end

function BotService.GatherInLobby()
	for _, bot in ipairs(Actors.BotList()) do
		task.spawn(respawn, bot, "Lobby")
	end
end

function BotService.EnterArena()
	for _, bot in ipairs(Actors.BotList()) do
		bot.Mode = "Arena"
		task.spawn(respawn, bot, "Arena")
	end
end

------------------------------------------------------------------------------------------------
-- Bot behavior
------------------------------------------------------------------------------------------------

local function aliveParts(actor: any): (Humanoid?, BasePart?)
	local character = actor.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if humanoid and hrp and humanoid.Health > 0 then
		return humanoid, hrp :: BasePart
	end
	return nil, nil
end

local function enemyTeamName(bot: Bot): string?
	local name = Actors.TeamName(bot)
	if name == "Red" then
		return "Blue"
	elseif name == "Blue" then
		return "Red"
	end
	return nil
end

local function hasLineOfSight(bot: Bot, target: any, fromPos: Vector3, toPos: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bot.Character, target.Character }
	return Workspace:Raycast(fromPos, toPos - fromPos, params) == nil
end

local function findTarget(bot: Bot, myPos: Vector3): any
	local candidates = {}
	for _, actor in ipairs(Actors.All()) do
		if actor ~= bot and actor.Team ~= bot.Team then
			local humanoid, hrp = aliveParts(actor)
			if humanoid and hrp and not actor.Character:FindFirstChild("SpawnProtection") then
				local dist = (hrp.Position - myPos).Magnitude
				if dist <= SIGHT_RANGE then
					table.insert(candidates, { actor = actor, dist = dist, pos = hrp.Position })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.dist < b.dist
	end)
	for i = 1, math.min(3, #candidates) do
		local entry = candidates[i]
		if hasLineOfSight(bot, entry.actor, myPos + Vector3.new(0, 1.5, 0), entry.pos) then
			return entry.actor
		end
	end
	return nil
end

-- Walks toward goal using pathfinding, with a direct fallback.
local function navigate(bot: Bot, humanoid: Humanoid, hrp: BasePart, goal: Vector3)
	local t = now()
	local pos = hrp.Position
	local flatDist = (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude

	if flatDist < 6 then
		humanoid:MoveTo(goal)
		return
	end

	-- stuck detection
	if not bot.LastPos or t - bot.LastPosTime >= 2 then
		if bot.LastPos and (pos - bot.LastPos).Magnitude < 1.5 then
			humanoid.Jump = true
			bot.Waypoints = nil
			bot.PathTime = 0
		end
		bot.LastPos = pos
		bot.LastPosTime = t
	end

	local goalMoved = bot.PathGoal and (bot.PathGoal - goal).Magnitude > 15
	local expired = t - bot.PathTime > bot.PathRefresh
	local failWait = t < (bot.PathFailUntil or 0)
	if not bot.Pathing and not failWait and (not bot.Waypoints or goalMoved or expired) then
		bot.Pathing = true
		bot.PathGoal = goal
		local generation = bot.Generation
		task.spawn(function()
			local path = PathfindingService:CreatePath({
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = true,
			})
			local ok = pcall(function()
				path:ComputeAsync(pos, goal)
			end)
			if bot.Generation == generation then
				if ok and path.Status == Enum.PathStatus.Success then
					local points = path:GetWaypoints()
					local first = 2
					for i = 2, #points do
						local p = points[i].Position
						local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
						first = i
						if d > 4 then
							break
						end
					end
					bot.Waypoints = points
					bot.WpIndex = first
				else
					bot.Waypoints = nil
					bot.PathFailUntil = now() + 1.5
				end
				bot.PathTime = now()
				bot.PathRefresh = rand(1.5, 3)
				bot.Pathing = false
			end
		end)
	end

	local waypoints = bot.Waypoints
	if waypoints and bot.WpIndex <= #waypoints then
		local wp = waypoints[bot.WpIndex]
		local flat = (Vector3.new(wp.Position.X, 0, wp.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if flat < 4 then
			bot.WpIndex += 1
			wp = waypoints[bot.WpIndex]
		end
		if wp then
			if wp.Action == Enum.PathWaypointAction.Jump then
				local wpFlat = (Vector3.new(wp.Position.X, 0, wp.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
				if wpFlat < 5 then
					humanoid.Jump = true
				end
			end
			humanoid:MoveTo(wp.Position)
			return
		end
	end
	humanoid:MoveTo(goal)
end

local function lobbyStep(bot: Bot, humanoid: Humanoid, hrp: BasePart)
	local t = now()
	if t < bot.WanderAt then
		return
	end
	bot.WanderAt = t + rand(2, 6)
	if math.random() < 0.3 then
		return -- stand around for a while
	end
	local center = Config.LobbyCenter
	local pos = hrp.Position
	local target = pos + Vector3.new(rand(-14, 14), 0, rand(-14, 14))
	target = Vector3.new(
		math.clamp(target.X, center.X - 34, center.X + 34),
		pos.Y,
		math.clamp(target.Z, center.Z - 32, center.Z + 24)
	)
	humanoid:MoveTo(target)
end

local function objectiveGoal(bot: Bot, hrp: BasePart): Vector3?
	local own = Actors.TeamName(bot)
	local enemy = enemyTeamName(bot)
	if not own or not enemy then
		return nil
	end
	local ownInfo = FlagService.GetFlagInfo(own)
	local enemyInfo = FlagService.GetFlagInfo(enemy)
	if not ownInfo or not enemyInfo then
		return nil
	end
	local t = now()

	if bot.Role == "Attacker" then
		if FlagService.IsCarrier(bot) then
			if Config.RequireOwnFlagHome and ownInfo.State ~= "Home" then
				if ownInfo.State == "Dropped" then
					return ownInfo.Position
				end
				-- wait near the pad until our flag is back
				return ownInfo.Home + Vector3.new(-math.sign(ownInfo.Home.X) * 8, 0, 6)
			end
			return ownInfo.Home
		end
		if enemyInfo.State == "Carried" then
			local carrier = enemyInfo.Carrier
			if carrier and carrier.Team == bot.Team then
				return enemyInfo.Position -- escort our carrier
			end
			return ownInfo.Position
		end
		return enemyInfo.Position
	end

	-- defender
	if ownInfo.State == "Dropped" then
		return ownInfo.Position
	elseif ownInfo.State == "Carried" then
		return ownInfo.Position
	end
	if FlagService.IsCarrier(bot) then
		return ownInfo.Home
	end
	if not bot.PatrolPoint or t > bot.PatrolAt then
		bot.PatrolPoint = ownInfo.Home + Vector3.new(rand(-18, 18), 0, rand(-22, 22))
		bot.PatrolAt = t + rand(4, 7)
	end
	return bot.PatrolPoint
end

local function aimPointFor(bot: Bot, target: any): Vector3?
	local _, hrp = aliveParts(target)
	local _, myHrp = aliveParts(bot)
	if not hrp or not myHrp then
		return nil
	end
	local dist = (hrp.Position - myHrp.Position).Magnitude
	local aim = hrp.Position
	if math.random() < 0.2 then
		aim += Vector3.new(0, 1.5, 0)
	end
	local spread = rand(2, 5) * math.clamp(dist / 50, 0.6, 1.6)
	local dir = Vector3.new(rand(-1, 1), rand(-0.5, 0.5), rand(-1, 1))
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(1, 0, 0)
	end
	aim += dir.Unit * spread
	if math.random() < 0.18 then
		-- a clean miss
		aim += dir.Unit * rand(4, 8)
	end
	return aim
end

local function botStep(bot: Bot)
	if not bot.Alive then
		return
	end
	local humanoid, hrp = aliveParts(bot)
	if not humanoid or not hrp then
		return
	end

	if bot.Mode == "Lobby" or not isPlaying() then
		humanoid.AutoRotate = true
		if bot.Mode == "Lobby" then
			lobbyStep(bot, humanoid, hrp)
		end
		return
	end

	local t = now()
	local myPos = hrp.Position

	-- target selection
	local target = findTarget(bot, myPos)
	if target ~= bot.Target then
		bot.Target = target
		bot.ReactAt = t + rand(0.25, 0.5)
		bot.BurstLeft = 0
	end

	local goal = objectiveGoal(bot, hrp)
	local carrying = FlagService.IsCarrier(bot)

	if target and not carrying then
		local _, targetHrp = aliveParts(target)
		if targetHrp then
			local dist = (targetHrp.Position - myPos).Magnitude
			local close = dist < 40
			-- close fights: stand and strafe; far fights: keep moving toward the objective
			if close and t >= bot.ReactAt then
				bot.LastPos = nil
				humanoid.AutoRotate = false
				local flatLook = Vector3.new(targetHrp.Position.X, myPos.Y, targetHrp.Position.Z)
				hrp.CFrame = hrp.CFrame:Lerp(CFrame.lookAt(myPos, flatLook), 0.6)
				if t > bot.StrafeUntil then
					bot.StrafeDir = math.random() < 0.5 and -1 or 1
					bot.StrafeUntil = t + rand(0.6, 1.4)
				end
				local right = hrp.CFrame.RightVector * bot.StrafeDir
				local back = dist < 14 and -hrp.CFrame.LookVector * 2 or Vector3.zero
				local strafeTo = myPos + right * 7 + back
				humanoid:MoveTo(Vector3.new(
					math.clamp(strafeTo.X, -Config.ArenaLength / 2 + 4, Config.ArenaLength / 2 - 4),
					strafeTo.Y,
					math.clamp(strafeTo.Z, -Config.ArenaWidth / 2 + 4, Config.ArenaWidth / 2 - 4)
				))
				if math.random() < 0.08 then
					humanoid.Jump = true
				end
				return
			end
		end
	end

	humanoid.AutoRotate = true
	if goal then
		navigate(bot, humanoid, hrp, goal)
	end
end

local function shootStep(bot: Bot)
	if not bot.Alive or not bot.Target or bot.Mode ~= "Arena" or not isPlaying() then
		return
	end
	local t = now()
	if t < bot.ReactAt or t < bot.NextShot then
		return
	end
	local humanoid = aliveParts(bot)
	local targetHumanoid = aliveParts(bot.Target)
	if not humanoid or not targetHumanoid then
		bot.Target = nil
		return
	end
	local weapon = Weapons.Defs[bot.Weapon] or Weapons.Defs[Weapons.Default]
	local _, myHrp = aliveParts(bot)
	local _, targetHrp = aliveParts(bot.Target)
	if not myHrp or not targetHrp then
		return
	end
	local offset = targetHrp.Position - myHrp.Position
	local dist = offset.Magnitude
	if dist > (weapon.Range or SIGHT_RANGE) then
		return
	end
	if bot.Target.Character and bot.Target.Character:FindFirstChildOfClass("ForceField") then
		return
	end
	if dist >= 40 and dist > 0.01 and myHrp.CFrame.LookVector:Dot(offset.Unit) <= 0.3 then
		return
	end
	local aim = aimPointFor(bot, bot.Target)
	if not aim then
		return
	end
	CombatService.Shoot(bot, aim)

	local delay = weapon.FireDelay * rand(1.1, 1.5)
	if bot.BurstLeft <= 0 then
		bot.BurstLeft = math.random(3, 7)
	end
	bot.BurstLeft -= 1
	if bot.BurstLeft <= 0 then
		delay += rand(0.35, 0.9)
	end
	bot.NextShot = t + delay
end

function BotService.Init()
	if started then
		return
	end
	started = true

	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, bot in ipairs(Actors.BotList()) do
				local ok, err = pcall(botStep, bot)
				if not ok then
					warn("BotService step: " .. tostring(err))
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.07)
			for _, bot in ipairs(Actors.BotList()) do
				local ok, err = pcall(shootStep, bot)
				if not ok then
					warn("BotService shoot: " .. tostring(err))
				end
			end
		end
	end)

	-- keep the lobby topped up when humans come and go between rounds
	Players.PlayerAdded:Connect(function()
		task.defer(function()
			if not isPlaying() then
				BotService.Sync()
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function()
		task.delay(0.5, function()
			if not isPlaying() then
				BotService.Sync()
			end
		end)
	end)
end

return BotService
