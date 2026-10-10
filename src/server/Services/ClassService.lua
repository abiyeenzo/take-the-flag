local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Actors = require(script.Parent.Actors)
local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

local ClassService = {}

local lastSwitch: { [Player]: number } = {}

-- Builds the visual tool for a weapon. Used for humans and for bots.
function ClassService.MakeWeaponTool(weaponId: string, color: Color3): Tool
	local def = Weapons.Defs[weaponId] or Weapons.Defs[Weapons.Default]
	local gold = def.Id == "GoldBlaster"

	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.GripPos = Vector3.new(0, -0.1, 0.5)
	tool:SetAttribute("IsWeapon", true)
	tool:SetAttribute("WeaponId", def.Id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = def.HandleSize
	handle.Material = gold and Enum.Material.Metal or Enum.Material.SmoothPlastic
	handle.Color = def.Color
	handle.CanCollide = false
	handle.Parent = tool

	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Size = Vector3.new(def.HandleSize.X + 0.02, 0.25, def.HandleSize.Z * 0.6)
	accent.Material = Enum.Material.Neon
	accent.Color = gold and Color3.fromRGB(255, 225, 120) or color
	accent.CanCollide = false
	accent.Massless = true
	accent.CFrame = handle.CFrame * CFrame.new(0, def.HandleSize.Y / 2 - 0.05, -0.2)
	accent.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = accent
	weld.Parent = accent

	return tool
end

local function teamColorOf(actor: any): Color3
	local team = actor.Team :: Team?
	return team and Config.TeamColor(team.Name) or Color3.new(1, 1, 1)
end

-- weapon a human will actually use, validated against ownership
local function resolveWeapon(player: Player): string
	local data = DataService.Get(player)
	local id = data and data.EquippedWeapon
	if typeof(id) == "string" and Weapons.Defs[id] and DataService.OwnsWeapon(player, id) then
		return id
	end
	return Weapons.Default
end

local function clearWeaponTools(player: Player, character: Model)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ character, backpack }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("IsWeapon") then
					child:Destroy()
				end
			end
		end
	end
end

local function giveTool(player: Player, character: Model, humanoid: Humanoid)
	local weaponId = resolveWeapon(player)
	character:SetAttribute("Weapon", weaponId)
	clearWeaponTools(player, character)
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	local tool = ClassService.MakeWeaponTool(weaponId, teamColorOf(player))
	tool.Parent = backpack
	task.defer(function()
		if humanoid.Parent and humanoid.Health > 0 and tool.Parent == backpack then
			humanoid:EquipTool(tool)
		end
	end)
end

-- rebuilds the weapon tool after an equip change
function ClassService.GiveTool(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	giveTool(player, character, humanoid)
end

function ClassService.ApplyClass(actor: any, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end
	local isBot = Actors.IsBot(actor)
	local classId = if isBot then actor.Class else actor:GetAttribute("Class")
	local def = Classes.Defs[classId] or Classes.Defs[Classes.Default]

	if not isBot and Workspace:GetAttribute("RoundState") ~= "Playing" then
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			character:PivotTo(CFrame.new(MapBuilder.RandomLobbyPoint()))
		end
	end

	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.WalkSpeed = def.Speed

	character:SetAttribute("Class", def.Id)
	actor:SetAttribute("AbilityReadyAt", 0)

	local forceField = Instance.new("ForceField")
	forceField.Name = "SpawnProtection"
	forceField.Visible = true
	forceField.Parent = character
	Debris:AddItem(forceField, Config.SpawnProtection)

	if isBot then
		local weaponId = actor.Weapon
		character:SetAttribute("Weapon", Weapons.Defs[weaponId] and weaponId or Weapons.Default)
	else
		giveTool(actor, character, humanoid)
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

	local def = Classes.Defs[character:GetAttribute("Class") or player:GetAttribute("Class")]
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
		if data.Class == id then
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
			ClassService.ApplyClass(player, character)
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
