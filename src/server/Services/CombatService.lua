local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Actors = require(script.Parent.Actors)

local CombatService = {}

CombatService.Killed = Instance.new("BindableEvent") -- (killerActor?, victimActor)

local MAX_FX_PER_SHOT = 3
local OVERCHARGE_DAMAGE = 1.6
local OVERCHARGE_RATE = 0.67

local lastShot: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function findWeaponTool(character: Model): Tool?
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("IsWeapon") then
			return child
		end
	end
	return nil
end

-- random direction inside a cone of spreadDeg around dir
local function spreadDirection(dir: Vector3, spreadDeg: number): Vector3
	if spreadDeg <= 0 then
		return dir
	end
	local base = CFrame.lookAt(Vector3.zero, dir)
	local roll = math.random() * math.pi * 2
	local tilt = math.rad(spreadDeg) * math.sqrt(math.random())
	return (base * CFrame.Angles(0, 0, roll) * CFrame.Angles(tilt, 0, 0)).LookVector
end

-- single entry point for every shot, humans and bots
function CombatService.Shoot(actor: any, aimPoint: Vector3)
	if typeof(aimPoint) ~= "Vector3" then
		return
	end
	local magnitude = aimPoint.Magnitude
	if magnitude ~= magnitude or magnitude > 1e5 then
		return
	end
	if Workspace:GetAttribute("RoundState") ~= "Playing" then
		return
	end

	local character = actor and actor.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not character or not humanoid or not head or humanoid.Health <= 0 then
		return
	end
	local isBot = Actors.IsBot(actor)
	if not isBot and not findWeaponTool(character) then
		return
	end

	local weapon = Weapons.Defs[character:GetAttribute("Weapon")] or Weapons.Defs[Weapons.Default]
	local class = Classes.Defs[character:GetAttribute("Class")] or Classes.Defs[Classes.Default]
	local now = Workspace:GetServerTimeNow()
	local overcharged = (character:GetAttribute("OverchargeUntil") or 0) > now

	local delay = weapon.FireDelay * (overcharged and OVERCHARGE_RATE or 1)
	local clock = os.clock()
	local last = lastShot[actor]
	if last and clock - last < delay * 0.92 then
		return
	end
	lastShot[actor] = clock

	local origin = (head :: BasePart).Position
	local offset = aimPoint - origin
	if offset.Magnitude < 1 then
		return
	end
	local aimDir = offset.Unit

	local team = actor.Team :: Team?
	local teamColor = team and Config.TeamColor(team.Name) or Color3.new(1, 1, 1)
	local damageBase = weapon.Damage * class.DamageMult * (overcharged and OVERCHARGE_DAMAGE or 1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local anyHit, anyHead, anyKill = false, false, false

	for pellet = 1, weapon.Pellets do
		local direction = spreadDirection(aimDir, weapon.SpreadDeg) * weapon.Range
		local exclude = { character }
		local result
		for _ = 1, 4 do
			params.FilterDescendantsInstances = exclude
			result = Workspace:Raycast(origin, direction, params)
			if not result then
				break
			end
			local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
			local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
			if hitModel and hitHumanoid and hitHumanoid.Health <= 0 then
				table.insert(exclude, hitModel)
			else
				break
			end
		end
		local endpoint = result and result.Position or origin + direction

		if pellet <= MAX_FX_PER_SHOT then
			Remotes.ShotFx:FireAllClients(origin, endpoint, teamColor)
		end

		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
			local victim = model and Actors.FromCharacter(model)
			if
				targetHumanoid
				and victim
				and victim ~= actor
				and victim.Team ~= actor.Team
				and targetHumanoid.Health > 0
				and not (model :: Model):FindFirstChildOfClass("ForceField")
			then
				local headshot = result.Instance.Name == "Head"
				local damage = damageBase * (headshot and Config.HeadshotMultiplier or 1)

				targetHumanoid:SetAttribute("LastDamager", actor.UserId)
				targetHumanoid:SetAttribute("LastDamageTime", os.clock())
				targetHumanoid:TakeDamage(damage)

				anyHit = true
				anyHead = anyHead or headshot
				anyKill = anyKill or targetHumanoid.Health <= 0
			end
		end
	end

	if anyHit and not isBot then
		Remotes.HitMarker:FireClient(actor, anyHead, anyKill)
	end
end

local function onFire(player: Player, aimPoint: any)
	CombatService.Shoot(player, aimPoint)
end

-- hooks the death of a character (humans and bots)
function CombatService.WatchCharacter(actor: any, character: Model)
	if watched[character] then
		return
	end
	watched[character] = true
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local damagerId = humanoid:GetAttribute("LastDamager")
		local damageTime = humanoid:GetAttribute("LastDamageTime")
		if damagerId and damageTime and os.clock() - damageTime <= Config.KillAssistWindow then
			local killer = Actors.ByUserId(damagerId)
			if killer and killer ~= actor and killer.Team ~= actor.Team then
				CombatService.Killed:Fire(killer, actor)
				return
			end
		end
		-- environment or self kill still ends the victim's streak
		CombatService.Killed:Fire(nil, actor)
	end)
end

function CombatService.Init()
	Remotes.Fire.OnServerEvent:Connect(onFire)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			CombatService.WatchCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
		if player.Character then
			task.spawn(CombatService.WatchCharacter, player, player.Character)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)
end

return CombatService
