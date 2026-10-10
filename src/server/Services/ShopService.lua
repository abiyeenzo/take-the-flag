local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local function clearTrail(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	for _, name in ipairs({ "CosmeticTrail", "TrailTop", "TrailBottom" }) do
		local old = hrp:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

function ShopService.ApplyTrail(player: Player)
	local character = player.Character
	local data = DataService.Get(player)
	if not character or not data then
		return
	end
	clearTrail(character)
	local def = Cosmetics.ById[data.EquippedTrail]
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not def or not hrp then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 1.2, 0)
	top.Parent = hrp
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1.5, 0)
	bottom.Parent = hrp

	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = def.Color
	trail.Lifetime = 0.7
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = hrp
end

local function onAction(player: Player, action: any, id: any)
	if typeof(action) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end

	if action == "Buy" then
		local def = Cosmetics.ById[id]
		if not def or data.OwnedTrails[id] then
			return
		end
		if data.Coins < def.Price then
			Remotes.Toast:FireClient(player, "Not enough coins for " .. def.Name, "bad")
			return
		end
		data.Coins -= def.Price
		data.OwnedTrails[id] = true
		data.EquippedTrail = id
		Remotes.Toast:FireClient(player, def.Name .. " trail unlocked!", "good")
	elseif action == "Equip" then
		if id == "" then
			data.EquippedTrail = ""
		elseif data.OwnedTrails[id] then
			data.EquippedTrail = id
		else
			return
		end
	else
		return
	end

	DataService.Push(player)
	ShopService.ApplyTrail(player)
end

function ShopService.Init()
	Remotes.ShopAction.OnServerEvent:Connect(onAction)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			-- profile may still be loading on the very first spawn
			for _ = 1, 20 do
				if DataService.Get(player) then
					break
				end
				task.wait(0.25)
			end
			ShopService.ApplyTrail(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
end

return ShopService
