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
local Device = require(ReplicatedStorage.Shared.Device)
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

-- Panels are scaled by Device.Scale(), so unscaled sizes are raised until text
-- and buttons reach the minima on screen (14 phone, 16 tablet, 18 titles, 44 hit).
local SCALE = Device.Scale()
local MIN_TEXT = Device.Get() == "Tablet" and 16 or 14
local function fs(size: number?): number
	return math.max(size or 0, math.ceil(MIN_TEXT / SCALE))
end
local function hit(size: number?): number
	return math.max(size or 0, math.ceil(44 / SCALE))
end

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

	local content = New("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = fade,
	}, {
		New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	UIKit.ApplyDeviceScale(content)

	-- Two columns: stacked on portrait and desktop, side by side on phone landscape
	local function newColumn(name: string, layoutOrder: number): Frame
		return New("Frame", {
			Name = name,
			LayoutOrder = layoutOrder,
			Size = UDim2.fromOffset(380, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = content,
		}, {
			New("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
			}),
		})
	end
	local columnA = newColumn("ColumnA", 1)
	local columnB = newColumn("ColumnB", 2)

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
		Parent = columnA,
	})
	local accent = New("Frame", {
		Name = "Accent",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(0.8, 0, 0, 5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = columnA,
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
		Size = UDim2.new(1, 0, 0, 28),
		Text = "Neon capture the flag",
		TextSize = math.max(18, math.ceil(18 / SCALE)),
		Font = Enum.Font.Gotham,
		TextColor3 = Colors.Muted,
		Parent = columnA,
	})

	-- Buttons
	local play = UIKit.Button({
		Name = "Play",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, hit(60)),
		Text = "PLAY",
		TextSize = 28,
		BackgroundColor3 = Colors.Accent,
		TextColor3 = Color3.fromRGB(30, 24, 6),
		Selectable = true,
		Parent = columnB,
	})
	UIKit.Stroke(Color3.new(1, 1, 1), 2, 0.5).Parent = play

	local row = New("Frame", {
		Name = "Row",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, hit(46)),
		BackgroundTransparency = 1,
		Parent = columnB,
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
			TextSize = fs(16),
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
	local LH = fs() + 4
	local badgeSize = LH + 28
	local cardHeight = math.max(64, badgeSize + 18)
	local card = New("Frame", {
		Name = "ProfileCard",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, cardHeight),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = columnA,
	}, { UIKit.Corner(12), UIKit.Stroke(Colors.Stroke, 1.5, 0.3) })
	local badge = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(badgeSize, badgeSize),
		BackgroundColor3 = Colors.Level,
		Parent = card,
	}, { UIKit.Corner(10) })
	local levelLabel = Label({
		Position = UDim2.fromOffset(0, LH - 2),
		Size = UDim2.new(1, 0, 1, -(LH - 2)),
		Text = "1",
		TextSize = 24,
		Parent = badge,
	})
	Label({
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, 0, 0, LH),
		Text = "LV",
		TextSize = fs(),
		TextTransparency = 0.3,
		Parent = badge,
	})
	local textX = badgeSize + 18
	local coinsLabel = Label({
		Position = UDim2.new(0, textX, 0.5, -LH - 1),
		Size = UDim2.new(1, -(textX + 56 + 8), 0, LH),
		Text = "-- coins",
		TextSize = fs(17),
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local loadoutLabel = Label({
		Position = UDim2.new(0, textX, 0.5, 1),
		Size = UDim2.new(1, -(textX + 10), 0, LH),
		Text = "Loading your profile...",
		TextSize = fs(),
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
		Size = UDim2.fromOffset(fs() * 3, LH),
		BackgroundTransparency = 0,
		BackgroundColor3 = Colors.Accent,
		Text = "VIP",
		TextSize = fs(),
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
		Size = UDim2.new(1, 0, 0, LH),
		Text = "",
		TextSize = fs(16),
		TextColor3 = Colors.Good,
		Parent = columnB,
	})
	Label({
		Name = "Footer",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, LH),
		Text = "Follow abiye_enzo on YouTube",
		TextSize = fs(),
		Font = Enum.Font.Gotham,
		TextColor3 = Colors.Muted,
		Parent = columnB,
	})

	-- Phone landscape is too short for one column: put the two columns side by side
	local camera = Workspace.CurrentCamera
	local layout = content:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local function updateLayout()
		local cam = Workspace.CurrentCamera
		local view = cam and cam.ViewportSize or Vector2.new(1000, 700)
		local wide = view.Y / SCALE < 480 and view.X / SCALE >= 720
		layout.FillDirection = wide and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, wide and 24 or 10)
		local width = wide and 340 or 380
		columnA.Size = UDim2.fromOffset(width, 0)
		columnB.Size = UDim2.fromOffset(width, 0)
	end
	updateLayout()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
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
