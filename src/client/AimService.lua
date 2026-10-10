-- Single source of the aim point: a ray through the screen-center crosshair.
-- Also owns the hold-to-fire loop (mouse, gamepad trigger and the HUD FIRE button)
-- and the touch-only aim assist.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(ReplicatedStorage.Shared.Device)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local MouseLock = require(script.Parent.MouseLock)

local player = Players.LocalPlayer
local AimService = {}

local FIRE_ACTION = "TakeTheFlagFire"
local CROSSHAIR_RETRY = 1
local CROSSHAIR_INTERVAL = 1 / 30
local EQUIP_TIMEOUT = 0.5

local hooked: { [Tool]: boolean } = {}
local equipped: Tool? = nil
local firing = false
local looping = false
local started = false
local pendingShot = false
local nextShotAt = 0

local crosshair: GuiObject? = nil
local crosshairNextLookup = 0
local lastOnEnemy: boolean? = nil
local crosshairNextCheck = 0

local function findCrosshair(): GuiObject?
	if crosshair and crosshair.Parent then
		return crosshair
	end
	crosshair = nil
	local now = os.clock()
	if now < crosshairNextLookup then
		return nil
	end
	crosshairNextLookup = now + CROSSHAIR_RETRY
	local gui = player:FindFirstChildOfClass("PlayerGui")
	local hud = gui and gui:FindFirstChild("TakeTheFlagHud", true)
	local found = hud and hud:FindFirstChild("Crosshair", true)
	if found and found:IsA("GuiObject") then
		crosshair = found
		lastOnEnemy = nil
		return found
	end
	return nil
end

local function crosshairShown(frame: GuiObject): boolean
	local node: Instance? = frame
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local function centerRay(): Ray
	local camera = Workspace.CurrentCamera
	local frame = findCrosshair()
	if frame then
		-- AbsolutePosition is relative to the ScreenGui origin: with IgnoreGuiInset = true that is the viewport origin, the same space as ViewportPointToRay; otherwise add the top inset back.
		local center = frame.AbsolutePosition + frame.AbsoluteSize / 2
		local screenGui = frame:FindFirstAncestorWhichIsA("ScreenGui")
		if screenGui and not screenGui.IgnoreGuiInset then
			center += GuiService:GetGuiInset()
		end
		return camera:ViewportPointToRay(center.X, center.Y)
	end
	local viewport = camera.ViewportSize
	return camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
end

local function excludeParams(extra: Instance?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list: { Instance } = {}
	if player.Character then
		table.insert(list, player.Character)
	end
	if extra then
		table.insert(list, extra)
	end
	params.FilterDescendantsInstances = list
	return params
end

local function myTeamName(): string?
	local team = player.Team
	return team and team.Name or nil
end

-- Enemy = living character of another team. Players use Player.Team, bots are
-- Workspace models with a Humanoid, no Player, and the TeamName attribute set by
-- BotService / Actors.SetTeam.
local function enemyHumanoid(model: Instance?): Humanoid?
	if not model or not model:IsA("Model") or model == player.Character then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local mine = myTeamName()
	if not mine then
		return nil
	end
	local owner = Players:GetPlayerFromCharacter(model)
	local theirs: string?
	if owner then
		if owner == player then
			return nil
		end
		theirs = owner.Team and owner.Team.Name or nil
	else
		local value = model:GetAttribute("TeamName")
		theirs = if type(value) == "string" and value ~= "" then value else nil
	end
	if not theirs or theirs == mine then
		return nil
	end
	return humanoid
end

local function modelOf(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

local function touchAim(): boolean
	if not Device.IsTouchPrimary() then
		return false
	end
	local last = UserInputService:GetLastInputType()
	return last.Name:sub(1, 7) ~= "Gamepad"
end

local function candidateModels(): { Model }
	local list: { Model } = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			table.insert(list, other.Character)
		end
	end
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsBot") == true then
			table.insert(list, child)
		end
	end
	return list
end

local function assistTarget(ray: Ray): BasePart?
	local origin = ray.Origin
	local look = ray.Direction.Unit
	local maxCos = math.cos(math.rad(Config.AimAssistAngle))
	local best: BasePart? = nil
	local bestCos = maxCos
	for _, model in ipairs(candidateModels()) do
		if enemyHumanoid(model) then
			local head = model:FindFirstChild("Head") :: BasePart?
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if head and root then
				local offset = head.Position - origin
				local distance = offset.Magnitude
				if distance > 0 and distance <= Config.ShotRange then
					local cos = look:Dot(offset / distance)
					if cos >= bestCos then
						local blocked = Workspace:Raycast(origin, offset, excludeParams(model))
						if not blocked then
							best = root
							bestCos = cos
						end
					end
				end
			end
		end
	end
	return best
end

function AimService.GetAimPoint(): Vector3
	local ray = centerRay()
	local direction = ray.Direction.Unit
	local result = Workspace:Raycast(ray.Origin, direction * Config.ShotRange, excludeParams(nil))
	local point = if result then result.Position else ray.Origin + direction * Config.ShotRange

	if touchAim() then
		local target = assistTarget(ray)
		if target then
			local depth = (target.Position - ray.Origin).Magnitude
			local along = ray.Origin + direction * depth
			point = along:Lerp(target.Position, Config.AimAssistLerp)
		end
	end
	return point
end

local function updateCrosshair()
	local now = os.clock()
	if now < crosshairNextCheck then
		return
	end
	crosshairNextCheck = now + CROSSHAIR_INTERVAL
	local frame = findCrosshair()
	if not frame then
		return
	end
	local onEnemy = false
	local camera = Workspace.CurrentCamera
	if camera and player:GetAttribute("InGame") == true and crosshairShown(frame) then
		local ray = centerRay()
		local result = Workspace:Raycast(ray.Origin, ray.Direction.Unit * Config.ShotRange, excludeParams(nil))
		if result then
			onEnemy = enemyHumanoid(modelOf(result.Instance)) ~= nil
		end
	end
	if onEnemy ~= lastOnEnemy then
		lastOnEnemy = onEnemy
		frame:SetAttribute("OnEnemy", onEnemy)
	end
end

local function aliveHumanoid(): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function canFire(): boolean
	if player:GetAttribute("InGame") ~= true or player:GetAttribute("MenuOpen") == true then
		return false
	end
	if not aliveHumanoid() then
		return false
	end
	return equipped ~= nil and equipped.Parent == player.Character
end

-- If no weapon is in hand, take the weapon tool from the backpack so the FIRE
-- button and the trigger work without tapping the toolbar first. Yields until the
-- tool is really parented to the character (short timeout). Returns true when held.
local function ensureEquipped(): boolean
	local character = player.Character
	if equipped and equipped.Parent == character then
		return true
	end
	local humanoid = aliveHumanoid()
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or not backpack or not character then
		return false
	end
	local tool: Tool? = nil
	for _, item in ipairs(backpack:GetChildren()) do
		if item:IsA("Tool") and item:GetAttribute("IsWeapon") then
			tool = item
			break
		end
	end
	if not tool then
		return false
	end
	humanoid:EquipTool(tool)
	local deadline = os.clock() + EQUIP_TIMEOUT
	while tool.Parent ~= character and os.clock() < deadline do
		task.wait()
	end
	if tool.Parent == character then
		equipped = tool
		return true
	end
	return false
end

local function fireDelay(): number
	local character = player.Character
	local weaponId = character and character:GetAttribute("Weapon") or Weapons.Default
	local def = Weapons.Defs[weaponId] or Weapons.Defs[Weapons.Default]
	local overcharged = (character and character:GetAttribute("OverchargeUntil") or 0) > Workspace:GetServerTimeNow()
	return def.FireDelay * (overcharged and 0.67 or 1)
end

function AimService.SetFiring(on: boolean)
	if not on then
		firing = false
		return
	end
	if player:GetAttribute("MenuOpen") == true or player:GetAttribute("InGame") ~= true then
		return
	end
	firing = true
	-- a tap always gets one shot attempt, even if released during the equip wait
	pendingShot = true
	if looping then
		return
	end
	looping = true
	task.spawn(function()
		local reequipped = false
		if not ensureEquipped() then
			reequipped = true
		end
		while firing or pendingShot do
			if not canFire() then
				-- the backpack toggle can unequip while the trigger is still held: try once
				if reequipped or not ensureEquipped() or not canFire() then
					break
				end
				reequipped = true
			end
			local waitFor = nextShotAt - os.clock()
			if waitFor > 0 then
				task.wait(waitFor)
				if not canFire() then
					break
				end
			end
			pendingShot = false
			Remotes.Fire:FireServer(AimService.GetAimPoint())
			nextShotAt = os.clock() + fireDelay()
			if firing then
				task.wait(fireDelay())
			end
		end
		firing = false
		pendingShot = false
		looping = false
	end)
end

function AimService.IsFiring(): boolean
	return firing
end

local function hookTool(tool: Tool)
	if hooked[tool] or not tool:GetAttribute("IsWeapon") then
		return
	end
	hooked[tool] = true
	tool.Equipped:Connect(function()
		equipped = tool
	end)
	tool.Unequipped:Connect(function()
		if equipped == tool then
			equipped = nil
		end
	end)
	tool.Destroying:Connect(function()
		hooked[tool] = nil
		if equipped == tool then
			equipped = nil
			AimService.SetFiring(false)
		end
	end)
	if tool.Parent == player.Character then
		equipped = tool
	end
end

local function watchCharacter(character: Model)
	equipped = nil
	AimService.SetFiring(false)
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
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			AimService.SetFiring(false)
		end)
	end
end

local function onFireAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		AimService.SetFiring(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		AimService.SetFiring(false)
	end
	return Enum.ContextActionResult.Sink
end

function AimService.Init()
	if started then
		return
	end
	started = true

	player.CharacterAdded:Connect(function(character)
		task.spawn(watchCharacter, character)
	end)
	player.CharacterRemoving:Connect(function()
		equipped = nil
		AimService.SetFiring(false)
	end)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end

	player:GetAttributeChangedSignal("MenuOpen"):Connect(function()
		if player:GetAttribute("MenuOpen") == true then
			AimService.SetFiring(false)
		end
	end)
	player:GetAttributeChangedSignal("InGame"):Connect(function()
		if player:GetAttribute("InGame") ~= true then
			AimService.SetFiring(false)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if MouseLock.IsLocked() and player:GetAttribute("MenuOpen") ~= true then
			AimService.SetFiring(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			AimService.SetFiring(false)
		end
	end)

	ContextActionService:BindAction(FIRE_ACTION, onFireAction, false, Enum.KeyCode.ButtonR2)

	RunService.RenderStepped:Connect(updateCrosshair)
end

return AimService
