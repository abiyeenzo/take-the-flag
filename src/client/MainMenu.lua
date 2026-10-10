-- The main menu. Shown until the player presses PLAY, and again after
-- "Back to main menu". The camera slowly circles the neon lobby behind it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Hud = require(script.Parent.Hud)
local Settings = require(script.Parent.Settings)
local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local New, Label, Colors = UIKit.New, UIKit.Label, UIKit.Colors
local player = Players.LocalPlayer

local ORBIT_RADIUS = 70
local ORBIT_HEIGHT = 35
local ORBIT_SPEED = 0.07 -- radians per second
local ORBIT_BIND = "TakeTheFlagMenuOrbit"
local PLAY_TIMEOUT = 5

local MainMenu = {}
MainMenu.Visible = false

local function inGame(): boolean
	return player:GetAttribute("InGame") == true
end

local function panelOpen(): boolean
	local root = Hud.Root
	if not root then
		return false
	end
	for _, name in ipairs({ "Shop", "Classes", "Settings" }) do
		local panel = root:FindFirstChild(name)
		if panel and panel:IsA("GuiObject") and panel.Visible then
			return true
		end
	end
	return false
end

function MainMenu.Init(Menus: { Toggle: (string) -> () })
	local screenGui = New("ScreenGui", {
		Name = "TakeTheFlagMenu",
		DisplayOrder = 5,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local fade = New("CanvasGroup", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 0,
		Parent = screenGui,
	})

	New("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = fade,
	}, {
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(8, 10, 22), Color3.fromRGB(22, 14, 44)),
		}),
	})

	local scale = New("UIScale", { Scale = 1 })
	local content = New("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = fade,
	}, {
		scale,
		New("UISizeConstraint", { MaxSize = Vector2.new(380, math.huge) }),
		New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Title and team color accent line
	Label({
		Name = "Title",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 76),
		Text = "TAKE THE FLAG\nIF YOU CAN",
		TextSize = 32,
		TextWrapped = true,
		TextStrokeTransparency = 0.5,
		Parent = content,
	})
	local accent = New("Frame", {
		Name = "Accent",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(0.8, 0, 0, 5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = content,
	}, {
		UIKit.Corner(3),
		New("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Config.TeamColor("Red")),
				ColorSequenceKeypoint.new(1, Config.TeamColor("Blue")),
			}),
		}),
	})
	local _ = accent
	Label({
		Name = "Subtitle",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Neon capture the flag",
		TextSize = 18,
		Font = Enum.Font.Gotham,
		TextColor3 = Colors.Muted,
		Parent = content,
	})

	-- Buttons
	local play = UIKit.Button({
		Name = "Play",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 60),
		Text = "PLAY",
		TextSize = 28,
		BackgroundColor3 = Colors.Accent,
		TextColor3 = Color3.fromRGB(30, 24, 6),
		Selectable = true,
		Parent = content,
	})
	UIKit.Stroke(Color3.new(1, 1, 1), 2, 0.5).Parent = play

	local row = New("Frame", {
		Name = "Row",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local function smallButton(name: string, text: string, index: number): TextButton
		local button = UIKit.Button({
			Name = name,
			LayoutOrder = index,
			Size = UDim2.new(1 / 3, -6, 1, 0),
			Text = text,
			TextSize = 16,
			Selectable = true,
			Parent = row,
		})
		UIKit.Stroke(Colors.Stroke, 1.5, 0.3).Parent = button
		return button
	end
	local shop = smallButton("Shop", "SHOP", 1)
	local classes = smallButton("Classes", "CLASSES", 2)
	local settings = smallButton("Settings", "SETTINGS", 3)

	-- Profile card
	local card = New("Frame", {
		Name = "ProfileCard",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = content,
	}, { UIKit.Corner(12), UIKit.Stroke(Colors.Stroke, 1.5, 0.3) })
	local badge = New("Frame", {
		Position = UDim2.fromOffset(8, 9),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Colors.Level,
		Parent = card,
	}, { UIKit.Corner(10) })
	local levelLabel = Label({
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 1, -10),
		Text = "1",
		TextSize = 24,
		Parent = badge,
	})
	Label({
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "LV",
		TextSize = 13,
		TextTransparency = 0.3,
		Parent = badge,
	})
	local coinsLabel = Label({
		Position = UDim2.fromOffset(64, 8),
		Size = UDim2.new(1, -130, 0, 22),
		Text = "-- coins",
		TextSize = 17,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local loadoutLabel = Label({
		Position = UDim2.fromOffset(64, 32),
		Size = UDim2.new(1, -74, 0, 22),
		Text = "Loading your profile...",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	local vip = Label({
		Name = "VipBadge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(40, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = Colors.Accent,
		Text = "VIP",
		TextSize = 13,
		TextColor3 = Color3.fromRGB(30, 24, 6),
		Visible = false,
		Parent = card,
	})
	UIKit.Corner(6).Parent = vip

	local function renderProfile(profile: any)
		if not profile then
			return
		end
		levelLabel.Text = tostring(profile.Level or 1)
		coinsLabel.Text = ("%d coins"):format(profile.Coins or 0)
		local classDef = Classes.Defs[profile.Class]
		local weaponDef = Weapons.Defs[profile.EquippedWeapon]
		loadoutLabel.Text = ("%s  -  %s"):format(
			classDef and classDef.Name or "Striker",
			weaponDef and weaponDef.Name or "Blaster"
		)
		vip.Visible = profile.VIP == true
	end
	Store.Changed.Event:Connect(renderProfile)
	renderProfile(Store.Profile)

	-- Status line
	local status = Label({
		Name = "Status",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextSize = 16,
		TextColor3 = Colors.Good,
		Parent = content,
	})
	Label({
		Name = "Footer",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Follow abiye_enzo on YouTube",
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextColor3 = Colors.Muted,
		Parent = content,
	})

	-- Fit small screens: shrink the whole column, never below readable
	local camera = Workspace.CurrentCamera
	local function updateScale()
		local cam = Workspace.CurrentCamera
		local view = cam and cam.ViewportSize or Vector2.new(1000, 700)
		scale.Scale = math.clamp(math.min(view.Y / 560, view.X / 400), 0.6, 1.15)
	end
	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	-- Camera orbit around the lobby
	local orbitAngle = 0
	local orbiting = false
	local function stopOrbit()
		if orbiting then
			orbiting = false
			RunService:UnbindFromRenderStep(ORBIT_BIND)
		end
	end
	local function startOrbit()
		if orbiting then
			return
		end
		orbiting = true
		RunService:BindToRenderStep(ORBIT_BIND, Enum.RenderPriority.Camera.Value + 1, function(dt)
			local cam = Workspace.CurrentCamera
			if not cam then
				return
			end
			cam.CameraType = Enum.CameraType.Scriptable
			orbitAngle += dt * ORBIT_SPEED
			local center = Config.LobbyCenter
			local position = center + Vector3.new(math.cos(orbitAngle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(orbitAngle) * ORBIT_RADIUS)
			cam.CFrame = CFrame.lookAt(position, center)
		end)
	end

	local function restoreCamera()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		cam.CameraType = Enum.CameraType.Custom
		local function attach(character: Model)
			local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
			if humanoid and inGame() then
				cam.CameraType = Enum.CameraType.Custom
				cam.CameraSubject = humanoid
			end
		end
		if player.Character then
			task.spawn(attach, player.Character)
		else
			player.CharacterAdded:Once(attach)
		end
	end

	-- PLAY handling
	local playing = false
	local playToken = 0
	local function resetPlay()
		playing = false
		play.Text = "PLAY"
		play.Active = true
		play.AutoButtonColor = true
		play.BackgroundColor3 = Colors.Accent
	end

	local function pressPlay()
		if playing or inGame() then
			return
		end
		playing = true
		playToken += 1
		local mine = playToken
		play.Text = "Loading..."
		play.AutoButtonColor = false
		play.BackgroundColor3 = Colors.PanelLight
		Remotes:WaitForChild("EnterGame"):FireServer()
		task.delay(PLAY_TIMEOUT, function()
			if playToken == mine and playing and not inGame() then
				resetPlay()
			end
		end)
	end
	play.Activated:Connect(pressPlay)
	shop.Activated:Connect(function()
		Menus.Toggle("Shop")
	end)
	classes.Activated:Connect(function()
		Menus.Toggle("Classes")
	end)
	settings.Activated:Connect(function()
		Settings.Toggle()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not MainMenu.Visible or panelOpen() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space then
			pressPlay()
		end
	end)

	-- Show and hide
	local fadeTween: Tween? = nil
	local function setShown(shown: boolean, instant: boolean?)
		MainMenu.Visible = shown
		Hud.SetInMenu(shown)
		if fadeTween then
			fadeTween:Cancel()
			fadeTween = nil
		end
		if shown then
			screenGui.Enabled = true
			fade.Visible = true
			fade.GroupTransparency = 0
			resetPlay()
			startOrbit()
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = play
			end
		else
			stopOrbit()
			restoreCamera()
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(screenGui) then
				GuiService.SelectedObject = nil
			end
			if instant then
				fade.Visible = false
				screenGui.Enabled = false
				return
			end
			local tween = TweenService:Create(fade, TweenInfo.new(0.4), { GroupTransparency = 1 })
			fadeTween = tween
			tween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not MainMenu.Visible then
					fade.Visible = false
					screenGui.Enabled = false
				end
			end)
			tween:Play()
		end
	end

	player:GetAttributeChangedSignal("InGame"):Connect(function()
		setShown(not inGame())
	end)
	setShown(not inGame(), inGame())

	-- Live status line
	RunService.Heartbeat:Connect(function()
		if not MainMenu.Visible then
			return
		end
		local state = Workspace:GetAttribute("RoundState") or "Waiting"
		if state == "Playing" then
			status.Text = "Match in progress: jump in!"
		elseif state == "Intermission" then
			local remaining = (Workspace:GetAttribute("TimerEnd") or 0) - Workspace:GetServerTimeNow()
			status.Text = "Next match in " .. UIKit.FormatTime(remaining)
		else
			status.Text = "Bots will keep you company"
		end
	end)
end

return MainMenu
