local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CombatService = {}

CombatService.Killed = Instance.new("BindableEvent") -- (killer, victim)

local lastShot: { [Player]: number } = {}

local function onFire(player: Player, aimPoint: any)
	if typeof(aimPoint) ~= "Vector3" or aimPoint ~= aimPoint then
		return
	end
	if Workspace:GetAttribute("RoundState") ~= "Playing" then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not character or not humanoid or not head or humanoid.Health <= 0 then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= "Blaster" then
		return
	end

	local def = Classes.Defs[player:GetAttribute("Class")] or Classes.Defs[Classes.Default]
	local now = Workspace:GetServerTimeNow()
	local overcharged = (character:GetAttribute("OverchargeUntil") or 0) > now

	local delay = def.FireDelay * (overcharged and 0.67 or 1)
	local clock = os.clock()
	if lastShot[player] and clock - lastShot[player] < delay * 0.85 then
		return
	end
	lastShot[player] = clock

	local origin = (head :: BasePart).Position
	local offset = aimPoint - origin
	if offset.Magnitude < 1 then
		return
	end
	local direction = offset.Unit * Config.ShotRange

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(origin, direction, params)
	local endpoint = result and result.Position or origin + direction

	local teamColor = player.Team and Config.TeamColor(player.Team.Name) or Color3.new(1, 1, 1)
	Remotes.ShotFx:FireAllClients(origin, endpoint, teamColor)

	if not result then
		return
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
	local victim = model and Players:GetPlayerFromCharacter(model)
	if not targetHumanoid or not victim or victim == player or victim.Team == player.Team then
		return
	end
	if targetHumanoid.Health <= 0 then
		return
	end

	local headshot = result.Instance.Name == "Head"
	local damage = def.Damage * (headshot and Config.HeadshotMultiplier or 1) * (overcharged and 1.6 or 1)

	targetHumanoid:SetAttribute("LastDamager", player.UserId)
	targetHumanoid:SetAttribute("LastDamageTime", os.clock())
	targetHumanoid:TakeDamage(damage)

	Remotes.HitMarker:FireClient(player, headshot, targetHumanoid.Health <= 0)
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local damagerId = humanoid:GetAttribute("LastDamager")
		local damageTime = humanoid:GetAttribute("LastDamageTime")
		if damagerId and damageTime and os.clock() - damageTime <= Config.KillAssistWindow then
			local killer = Players:GetPlayerByUserId(damagerId)
			if killer and killer ~= player then
				CombatService.Killed:Fire(killer, player)
				return
			end
		end
		-- environment or self kill still ends the victim's streak
		CombatService.Killed:Fire(nil, player)
	end)
end

function CombatService.Init()
	Remotes.Fire.OnServerEvent:Connect(onFire)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)
end

return CombatService
