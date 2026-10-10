local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local Controls = {}

local hooked: { [Tool]: boolean } = {}

local function aimPoint(): Vector3
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local screen
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		screen = Vector2.new(viewport.X / 2, viewport.Y / 2)
	else
		screen = UserInputService:GetMouseLocation()
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * Config.ShotRange, params)
	return result and result.Position or ray.Origin + ray.Direction * Config.ShotRange
end

local function hookTool(tool: Tool)
	if hooked[tool] or tool.Name ~= "Blaster" then
		return
	end
	hooked[tool] = true

	local holding = false
	local looping = false

	tool.Activated:Connect(function()
		holding = true
		if looping then
			return
		end
		looping = true
		task.spawn(function()
			while holding and tool.Parent == player.Character do
				Remotes.Fire:FireServer(aimPoint())
				local def = Classes.Defs[player:GetAttribute("Class")] or Classes.Defs[Classes.Default]
				local overcharged = (player.Character and player.Character:GetAttribute("OverchargeUntil") or 0)
					> Workspace:GetServerTimeNow()
				task.wait(def.FireDelay * (overcharged and 0.67 or 1))
			end
			looping = false
		end)
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
	tool.Unequipped:Connect(function()
		holding = false
	end)
end

local function watchCharacter(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			hookTool(child)
		end
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			hookTool(child)
		end
	end)
end

local function drawShot(origin: Vector3, endpoint: Vector3, color: Color3)
	local distance = (endpoint - origin).Magnitude
	if distance < 0.5 then
		return
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.18, 0.18, distance)
	beam.CFrame = CFrame.lookAt(origin, endpoint) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = Workspace
	TweenService:Create(beam, TweenInfo.new(0.18), { Transparency = 1, Size = Vector3.new(0.02, 0.02, distance) }):Play()
	Debris:AddItem(beam, 0.25)
end

local function onAbilityFx(effect: string, extra: Vector3?)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	if effect == "Dash" then
		local look = hrp.CFrame.LookVector
		hrp.AssemblyLinearVelocity = Vector3.new(look.X * 95, 12, look.Z * 95)
	elseif effect == "Bounce" then
		local push = extra or Vector3.zero
		hrp.AssemblyLinearVelocity = Vector3.new(push.X, 85, push.Z)
	end
end

function Controls.Init()
	Remotes:WaitForChild("ShotFx").OnClientEvent:Connect(drawShot)
	Remotes:WaitForChild("AbilityFx").OnClientEvent:Connect(onAbilityFx)

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			Remotes.UseAbility:FireServer()
		end
	end)
end

return Controls
