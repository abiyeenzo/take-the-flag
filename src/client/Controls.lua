local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AimService = require(script.Parent.AimService)
local MouseLock = require(script.Parent.MouseLock)

local player = Players.LocalPlayer
local Controls = {}

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

	MouseLock.Init()
	AimService.Init()

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
