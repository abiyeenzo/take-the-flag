local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FlagService = {}

FlagService.Active = false
FlagService.PickedUp = Instance.new("BindableEvent") -- (player, flagTeam)
FlagService.Dropped = Instance.new("BindableEvent") -- (player, flagTeam)
FlagService.Returned = Instance.new("BindableEvent") -- (player or nil, flagTeam)
FlagService.Captured = Instance.new("BindableEvent") -- (player, flagTeam)

type Flag = {
	Team: string,
	Home: Vector3,
	Model: Model,
	Pole: Part,
	Banner: Part,
	State: string,
	Carrier: Player?,
	Token: number,
	Highlight: Highlight?,
	DiedConnection: RBXScriptConnection?,
	OldSpeed: number,
	Welds: { WeldConstraint },
}

local flags: { [string]: Flag } = {}
local carrying: { [Player]: Flag } = {}
local lastWarning: { [Player]: number } = {}

local function teamOf(player: Player): string?
	return player.Team and player.Team.Name or nil
end

local function isAlive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and hrp and humanoid.Health > 0 then
		return humanoid, hrp :: BasePart
	end
	return nil, nil
end

local function layout(flag: Flag, cf: CFrame)
	flag.Pole.CFrame = cf * CFrame.new(0, 4.5, 0)
	flag.Banner.CFrame = cf * CFrame.new(0.1, 6.6, 2.7)
end

local function setState(flag: Flag, state: string, carrier: Player?)
	flag.State = state
	flag.Carrier = carrier
	Workspace:SetAttribute(flag.Team .. "Flag", state)
	Workspace:SetAttribute(flag.Team .. "Carrier", carrier and carrier.Name or "")
end

local function buildModel(teamName: string)
	local color = Config.TeamColor(teamName)
	local model = Instance.new("Model")
	model.Name = teamName .. "Flag"

	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Size = Vector3.new(0.6, 9, 0.6)
	pole.Material = Enum.Material.Metal
	pole.Color = Color3.fromRGB(215, 220, 235)
	pole.Anchored = true
	pole.CanCollide = false
	pole.CanQuery = false
	pole.Massless = true
	pole.Parent = model

	local banner = Instance.new("Part")
	banner.Name = "Banner"
	banner.Size = Vector3.new(0.2, 3.6, 5)
	banner.Material = Enum.Material.Neon
	banner.Color = color
	banner.Anchored = true
	banner.CanCollide = false
	banner.CanQuery = false
	banner.Massless = true
	banner.Parent = model

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 22
	light.Brightness = 2
	light.Parent = banner

	model.PrimaryPart = pole
	return model, pole, banner
end

local function cleanupCarry(flag: Flag)
	if flag.DiedConnection then
		flag.DiedConnection:Disconnect()
		flag.DiedConnection = nil
	end
	if flag.Highlight then
		flag.Highlight:Destroy()
		flag.Highlight = nil
	end
	for _, weld in ipairs(flag.Welds) do
		weld:Destroy()
	end
	flag.Welds = {}

	local player = flag.Carrier
	if player then
		carrying[player] = nil
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and flag.OldSpeed > 0 then
			humanoid.WalkSpeed = flag.OldSpeed
		end
	end
end

local function anchorFlag(flag: Flag)
	for _, part in ipairs({ flag.Pole, flag.Banner }) do
		part.Anchored = true
		part.CanTouch = true
	end
end

local function returnHome(flag: Flag, byPlayer: Player?, silent: boolean?)
	flag.Token += 1
	cleanupCarry(flag)
	anchorFlag(flag)
	layout(flag, CFrame.new(flag.Home))
	setState(flag, "Home", nil)
	if not silent then
		FlagService.Returned:Fire(byPlayer, flag.Team)
	end
end

local function drop(flag: Flag)
	local player = flag.Carrier
	if not player then
		return
	end
	local _, hrp = isAlive(player)
	local position = hrp and hrp.Position or (player.Character and player.Character:GetPivot().Position) or flag.Home

	cleanupCarry(flag)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if player.Character then
		params.FilterDescendantsInstances = { player.Character }
	end
	local result = Workspace:Raycast(position, Vector3.new(0, -60, 0), params)
	local ground = result and result.Position or position

	anchorFlag(flag)
	layout(flag, CFrame.new(ground))
	setState(flag, "Dropped", nil)
	FlagService.Dropped:Fire(player, flag.Team)

	flag.Token += 1
	local token = flag.Token
	task.delay(Config.FlagAutoReturnTime, function()
		if flag.Token == token and flag.State == "Dropped" then
			returnHome(flag, nil)
		end
	end)
end

local function pickup(flag: Flag, player: Player)
	local humanoid, hrp = isAlive(player)
	if not humanoid or not hrp then
		return
	end

	flag.Token += 1
	setState(flag, "Carried", player)
	carrying[player] = flag

	for _, part in ipairs({ flag.Pole, flag.Banner }) do
		part.Anchored = false
		part.CanTouch = false
	end
	layout(flag, hrp.CFrame * CFrame.new(0, -2.5, 1.6))

	local toPole = Instance.new("WeldConstraint")
	toPole.Part0 = flag.Pole
	toPole.Part1 = hrp
	toPole.Parent = flag.Pole
	local toBanner = Instance.new("WeldConstraint")
	toBanner.Part0 = flag.Banner
	toBanner.Part1 = flag.Pole
	toBanner.Parent = flag.Banner
	flag.Welds = { toPole, toBanner }

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Config.TeamColor(flag.Team)
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = player.Character
	flag.Highlight = highlight

	flag.OldSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = humanoid.WalkSpeed * Config.CarrierSpeedFactor

	flag.DiedConnection = humanoid.Died:Connect(function()
		if flag.Carrier == player then
			drop(flag)
		end
	end)

	FlagService.PickedUp:Fire(player, flag.Team)
end

local function onFlagTouched(flag: Flag, hit: BasePart)
	if not FlagService.Active or flag.State == "Carried" then
		return
	end
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or not isAlive(player) then
		return
	end
	local team = teamOf(player)
	if not team then
		return
	end

	if team ~= flag.Team then
		if not carrying[player] then
			pickup(flag, player)
		end
	elseif flag.State == "Dropped" then
		returnHome(flag, player)
	end
end

local function onPadTouched(padTeam: string, hit: BasePart)
	if not FlagService.Active then
		return
	end
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or teamOf(player) ~= padTeam then
		return
	end
	local enemyFlag = carrying[player]
	if not enemyFlag or not isAlive(player) then
		return
	end

	local ownFlag = flags[padTeam]
	if Config.RequireOwnFlagHome and ownFlag.State ~= "Home" then
		local now = os.clock()
		if not lastWarning[player] or now - lastWarning[player] > 3 then
			lastWarning[player] = now
			Remotes.Toast:FireClient(player, "Your flag must be at base to capture. Return it first!", "bad")
		end
		return
	end

	returnHome(enemyFlag, nil, true)
	FlagService.Captured:Fire(player, enemyFlag.Team)
end

function FlagService.IsCarrier(player: Player): boolean
	return carrying[player] ~= nil
end

function FlagService.Reset()
	for _, flag in pairs(flags) do
		returnHome(flag, nil, true)
	end
end

function FlagService.Init(mapInfo: any)
	for _, def in ipairs(Config.Teams) do
		local info = mapInfo[def.Name]
		local model, pole, banner = buildModel(def.Name)
		local flag: Flag = {
			Team = def.Name,
			Home = info.FlagPosition,
			Model = model,
			Pole = pole,
			Banner = banner,
			State = "Home",
			Carrier = nil,
			Token = 0,
			Highlight = nil,
			DiedConnection = nil,
			OldSpeed = 0,
			Welds = {},
		}
		flags[def.Name] = flag
		layout(flag, CFrame.new(flag.Home))
		model.Parent = Workspace
		setState(flag, "Home", nil)

		pole.Touched:Connect(function(hit)
			onFlagTouched(flag, hit)
		end)
		banner.Touched:Connect(function(hit)
			onFlagTouched(flag, hit)
		end)
		info.Trigger.Touched:Connect(function(hit)
			onPadTouched(def.Name, hit)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local flag = carrying[player]
		if flag then
			drop(flag)
		end
		lastWarning[player] = nil
	end)
end

return FlagService
