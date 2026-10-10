local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local ClassService = {}

local lastSwitch: { [Player]: number } = {}

local function makeBlaster(color: Color3): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Blaster"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.GripPos = Vector3.new(0, -0.1, 0.5)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.9, 2.4)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(40, 44, 60)
	handle.CanCollide = false
	handle.Parent = tool

	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Size = Vector3.new(0.62, 0.25, 1.4)
	accent.Material = Enum.Material.Neon
	accent.Color = color
	accent.CanCollide = false
	accent.Massless = true
	accent.CFrame = handle.CFrame * CFrame.new(0, 0.3, -0.2)
	accent.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = accent
	weld.Parent = accent

	return tool
end

local function applyClass(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end
	local def = Classes.Defs[player:GetAttribute("Class")] or Classes.Defs[Classes.Default]

	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.WalkSpeed = def.Speed

	player:SetAttribute("AbilityReadyAt", 0)

	local forceField = Instance.new("ForceField")
	forceField.Name = "SpawnProtection"
	forceField.Visible = true
	forceField.Parent = character
	Debris:AddItem(forceField, Config.SpawnProtection)

	local teamColor = player.Team and Config.TeamColor(player.Team.Name) or Color3.new(1, 1, 1)
	local backpack = player:WaitForChild("Backpack", 5)
	if backpack then
		local tool = makeBlaster(teamColor)
		tool.Parent = backpack
		task.defer(function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid:EquipTool(tool)
			end
		end)
	end
end

local function highlightFor(character: Model, color: Color3, seconds: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = color
	highlight.Parent = character
	Debris:AddItem(highlight, seconds)
end

local function useAbility(player: Player)
	if Workspace:GetAttribute("RoundState") ~= "Playing" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	local def = Classes.Defs[player:GetAttribute("Class")]
	local now = Workspace:GetServerTimeNow()
	if not def or now < (player:GetAttribute("AbilityReadyAt") or 0) then
		return
	end
	player:SetAttribute("AbilityReadyAt", now + def.Cooldown)

	if def.Ability == "Dash" then
		Remotes.AbilityFx:FireClient(player, "Dash")
	elseif def.Ability == "Shield" then
		local shield = Instance.new("ForceField")
		shield.Name = "AbilityShield"
		shield.Visible = true
		shield.Parent = character
		Debris:AddItem(shield, def.AbilityDuration)
	elseif def.Ability == "Overcharge" then
		character:SetAttribute("OverchargeUntil", now + def.AbilityDuration)
		highlightFor(character, Color3.fromRGB(255, 170, 40), def.AbilityDuration)
	end
end

function ClassService.Init()
	Remotes.UseAbility.OnServerEvent:Connect(useAbility)

	Remotes.SelectClass.OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" then
			return
		end
		local def = Classes.Defs[id]
		local data = DataService.Get(player)
		if not def or not data then
			return
		end
		if data.Level < def.Level then
			Remotes.Toast:FireClient(player, def.Name .. " unlocks at level " .. def.Level, "bad")
			return
		end
		local now = os.clock()
		if lastSwitch[player] and now - lastSwitch[player] < 2 then
			return
		end
		lastSwitch[player] = now

		data.Class = id
		player:SetAttribute("Class", id)
		DataService.Push(player)

		if Workspace:GetAttribute("RoundState") == "Playing" then
			Remotes.Toast:FireClient(player, def.Name .. " will be active when you respawn", "good")
		else
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end)

	local function hook(player: Player)
		player:SetAttribute("Class", Classes.Default)
		player.CharacterAdded:Connect(function(character)
			-- wait for the saved profile so the right class is applied on the very first spawn
			for _ = 1, 20 do
				if DataService.Get(player) then
					break
				end
				task.wait(0.25)
			end
			applyClass(player, character)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwitch[player] = nil
	end)
end

return ClassService
