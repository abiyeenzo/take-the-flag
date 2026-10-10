local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(ReplicatedStorage.Shared.Device)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AimService = require(script.Parent.AimService)
local Settings = require(script.Parent.Settings)
local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local New, Label, Colors = UIKit.New, UIKit.Label, UIKit.Colors
local player = Players.LocalPlayer

local Hud = {}
Hud.Buttons = {}
Hud.Root = nil :: any
Hud.Gui = nil :: any
Hud.InsetsApplied = false

-- Layout numbers per device class. Everything on screen is placed from these.
local METRICS = {
	Phone = { Fire = 90, Ability = 64, Margin = 24, JumpW = 120, Feed = 260, Button = 52 },
	Tablet = { Fire = 110, Ability = 80, Margin = 32, JumpW = 150, Feed = 340, Button = 52 },
	Desktop = { Fire = 0, Ability = 86, Margin = 24, JumpW = 0, Feed = 340, Button = 48 },
}

local function ts(size: number): number
	return math.max(size, UIKit.EffectiveMinText())
end

local RED_HIT = Color3.fromRGB(255, 70, 70)
local WHITE = Color3.new(1, 1, 1)

local crosshair: Frame? = nil
local crosshairParts: { Frame } = {}
local fireButton: TextButton? = nil
local inMainMenu = false
local panelOpen = false
local layoutHooked = false
local hudScaleHooked = false

local function fadeOut(instances: { Instance }, delay: number, duration: number)
	task.delay(delay, function()
		local info = TweenInfo.new(duration)
		for _, instance in ipairs(instances) do
			if instance.Parent then
				if instance:IsA("TextLabel") then
					TweenService:Create(instance, info, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 }):Play()
				elseif instance:IsA("GuiObject") then
					TweenService:Create(instance, info, { BackgroundTransparency = 1 }):Play()
				end
			end
		end
		task.wait(duration)
		for _, instance in ipairs(instances) do
			instance:Destroy()
		end
	end)
end

local function buildScoreboard(gui: GuiObject)
	local panel = New("Frame", {
		Name = "Scoreboard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(480, 64),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Active = false,
		Parent = gui,
	}, { UIKit.Corner(12), UIKit.Stroke(Colors.Stroke, 1.5, 0.3) })

	local function scoreBox(teamName: string, left: boolean)
		local box = New("Frame", {
			Size = UDim2.new(0, 110, 1, -12),
			Position = left and UDim2.new(0, 6, 0, 6) or UDim2.new(1, -116, 0, 6),
			BackgroundColor3 = Config.TeamColor(teamName),
			Active = false,
			Parent = panel,
		}, { UIKit.Corner(8) })
		Label({
			Name = "Team",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 4),
			Text = string.upper(teamName),
			TextSize = ts(13),
			TextTransparency = 0.15,
			Parent = box,
		})
		return Label({
			Name = "Score",
			Size = UDim2.new(1, 0, 1, -18),
			Position = UDim2.fromOffset(0, 18),
			Text = "0",
			TextSize = 30,
			Parent = box,
		})
	end

	local redScore = scoreBox("Red", true)
	local blueScore = scoreBox("Blue", false)

	local timer = Label({
		Name = "Timer",
		Size = UDim2.new(0, 240, 0, 34),
		Position = UDim2.new(0.5, -120, 0, 6),
		Text = "--:--",
		TextSize = 28,
		Parent = panel,
	})
	local sub = Label({
		Name = "State",
		Size = UDim2.new(0, 240, 0, 22),
		Position = UDim2.new(0.5, -120, 0, 38),
		Text = "",
		TextSize = ts(13),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Colors.Muted,
		Parent = panel,
	})

	return { Red = redScore, Blue = blueScore, Timer = timer, State = sub }
end

local function buildFlagChips(gui: GuiObject)
	local chips = {}
	local function chip(teamName: string, xOffset: number)
		local label = Label({
			Name = teamName .. "Chip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, xOffset, 0, 80),
			Size = UDim2.fromOffset(214, 26),
			BackgroundTransparency = 0.25,
			BackgroundColor3 = Colors.Panel,
			TextSize = ts(14),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = gui,
		})
		UIKit.Corner(6).Parent = label
		UIKit.Stroke(Config.TeamColor(teamName), 1.5, 0.2).Parent = label
		chips[teamName] = label
	end
	chip("Red", -112)
	chip("Blue", 112)
	return chips
end

local function buildProfileBar(gui: GuiObject)
	local bar = New("Frame", {
		Name = "ProfileBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -70),
		Size = UDim2.fromOffset(260, 60),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Active = false,
		Parent = gui,
	}, { UIKit.Corner(12), UIKit.Stroke(Colors.Stroke, 1.5, 0.3) })

	local badge = New("Frame", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Colors.Level,
		Active = false,
		Parent = bar,
	}, { UIKit.Corner(10) })
	local level = Label({
		Size = UDim2.new(1, 0, 1, -10),
		Position = UDim2.fromOffset(0, 12),
		Text = "1",
		TextSize = 24,
		Parent = badge,
	})
	Label({
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 1),
		Text = "LV",
		TextSize = ts(13),
		TextTransparency = 0.3,
		Parent = badge,
	})

	local track = New("Frame", {
		Size = UDim2.new(1, -70, 0, 10),
		Position = UDim2.fromOffset(62, 9),
		BackgroundColor3 = Colors.PanelLight,
		Active = false,
		Parent = bar,
	}, { UIKit.Corner(5) })
	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Colors.Level,
		Active = false,
		Parent = track,
	}, { UIKit.Corner(5) })
	local xp = Label({
		Size = UDim2.new(1, -70, 0, 17),
		Position = UDim2.fromOffset(62, 22),
		Text = "0 / 100 XP",
		TextSize = ts(13),
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})
	local coins = Label({
		Size = UDim2.new(1, -70, 0, 18),
		Position = UDim2.fromOffset(62, 39),
		Text = "0 coins",
		TextSize = ts(14),
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})

	local vip = Label({
		Name = "VipBadge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(40, 20),
		BackgroundColor3 = Colors.Accent,
		BackgroundTransparency = 0,
		Text = "VIP",
		TextSize = ts(13),
		TextColor3 = Color3.fromRGB(30, 24, 6),
		Visible = false,
		Parent = bar,
	})
	UIKit.Corner(6).Parent = vip

	local function render(profile)
		vip.Visible = profile.VIP == true
		level.Text = tostring(profile.Level)
		fill:TweenSize(
			UDim2.fromScale(math.clamp(profile.XP / profile.XpNeeded, 0, 1), 1),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quad,
			0.35,
			true
		)
		xp.Text = ("%d / %d XP"):format(profile.XP, profile.XpNeeded)
		coins.Text = ("%d coins"):format(profile.Coins)
	end
	Store.Changed.Event:Connect(render)
	if Store.Profile then
		render(Store.Profile)
	end
end

local function buildFeeds(gui: GuiObject)
	local feed = New("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 116),
		Size = UDim2.fromOffset(340, 220),
		BackgroundTransparency = 1,
		Active = false,
		Parent = gui,
	}, {
		New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})

	local toasts = New("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
		Active = false,
		Parent = gui,
	}, {
		New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 3),
		}),
	})

	local order = 0
	local function push(container: Frame, text: string, color: Color3, size: number, lifetime: number, maxItems: number)
		order += 1
		local item = Label({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, size + 6),
			Text = text,
			TextSize = size,
			TextColor3 = color,
			TextStrokeTransparency = 0.5,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = container == toasts and Enum.TextXAlignment.Center or Enum.TextXAlignment.Right,
			Parent = container,
		})
		local children = {}
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("TextLabel") then
				table.insert(children, child)
			end
		end
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		while #children > maxItems do
			local oldest = table.remove(children, 1)
			if oldest then
				oldest:Destroy()
			end
		end
		fadeOut({ item }, lifetime, 0.6)
	end

	Remotes:WaitForChild("Announce").OnClientEvent:Connect(function(text, team)
		push(feed, text, team and Config.TeamColor(team) or Colors.Text, ts(15), 6, 6)
	end)

	Remotes:WaitForChild("Toast").OnClientEvent:Connect(function(text, kind)
		local color = Colors.Text
		if kind == "good" then
			color = Colors.Good
		elseif kind == "bad" then
			color = Colors.Bad
		elseif kind == "level" then
			color = Colors.Accent
		end
		push(toasts, text, color, kind == "level" and 22 or ts(16), kind == "level" and 4 or 2.5, 4)
	end)
end

local function buildAbilityButton(gui: GuiObject)
	local touch = UIKit.IsTouch()
	local button = New("TextButton", {
		Name = "Ability",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -110),
		Size = UDim2.fromOffset(86, 86),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Active = true,
		Text = "",
		Parent = gui,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), UIKit.Stroke(Colors.Accent, 3, 0.1) })
	local press = New("UIScale", { Name = "Press", Scale = 1, Parent = button })

	local name
	if touch then
		-- The circle is small, so the ability name sits under it
		name = Label({
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(120, 20),
			Position = UDim2.new(0.5, 0, 1, 2),
			Text = "",
			TextSize = ts(14),
			TextStrokeTransparency = 0.5,
			Parent = button,
		})
		New("Frame", {
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(20, 20),
			Rotation = 45,
			BackgroundColor3 = Colors.Accent,
			Active = false,
			Parent = button,
		}, { UIKit.Corner(3) })
	else
		name = Label({
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 0.5, -20),
			Text = "",
			TextSize = ts(13),
			Parent = button,
		})
	end
	local key = Label({
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0.5, 2),
		Text = "Q",
		TextSize = 18,
		TextColor3 = Colors.Accent,
		Visible = not touch,
		Parent = button,
	})
	local cooldown = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		Active = false,
		Parent = button,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local counter = Label({ Size = UDim2.fromScale(1, 1), TextSize = 26, Parent = cooldown })

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(press, TweenInfo.new(0.08), { Scale = 0.92 }):Play()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(press, TweenInfo.new(0.1), { Scale = 1 }):Play()
		end
	end)
	button.Activated:Connect(function()
		Remotes.UseAbility:FireServer()
	end)

	return function()
		local character = player.Character
		local def = Classes.Defs[character and character:GetAttribute("Class") or player:GetAttribute("Class")]
		name.Text = def and string.upper(def.Ability) or ""
		local remaining = (player:GetAttribute("AbilityReadyAt") or 0) - Workspace:GetServerTimeNow()
		cooldown.Visible = remaining > 0
		counter.Text = remaining > 0 and tostring(math.ceil(remaining)) or ""
		key.Visible = remaining <= 0 and not touch
	end
end

local function buildToolbar(gui: GuiObject)
	local touch = UIKit.IsTouch()
	local bar = New("Frame", {
		Name = "Toolbar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(250, 48),
		BackgroundTransparency = 1,
		Active = false,
		Parent = gui,
	}, {
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local function button(name: string, text: string)
		local b = UIKit.Button({
			Name = name,
			Size = UDim2.fromOffset(121, 48),
			Text = text,
			BackgroundColor3 = Colors.Panel,
			Parent = bar,
		})
		UIKit.Stroke(Colors.Stroke, 1.5, 0.3).Parent = b
		Hud.Buttons[name] = b
	end
	if touch then
		button("Classes", "CLASSES")
		button("Shop", "SHOP")
	else
		button("Classes", "CLASSES  [C]")
		button("Shop", "SHOP  [B]")
	end
end

-- Screen center crosshair. Built for every device. White, red while the aim ray
-- is on an enemy (AimService sets the "OnEnemy" attribute on this frame).
local function buildCrosshair(gui: GuiObject)
	local frame = New("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		Parent = gui,
	})
	local function part(name: string, anchor: Vector2, position: UDim2)
		local piece = New("Frame", {
			Name = name,
			AnchorPoint = anchor,
			Position = position,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Active = false,
			Parent = frame,
		}, { UIKit.Stroke(Color3.new(0, 0, 0), 1, 0.5) })
		table.insert(crosshairParts, piece)
		return piece
	end
	part("Top", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0))
	part("Bottom", Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1))
	part("Left", Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5))
	part("Right", Vector2.new(1, 0.5), UDim2.fromScale(1, 0.5))
	local dot = part("Dot", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
	dot.Size = UDim2.fromOffset(4, 4)
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })

	local function recolor()
		local color = frame:GetAttribute("OnEnemy") == true and RED_HIT or WHITE
		for _, piece in ipairs(crosshairParts) do
			piece.BackgroundColor3 = color
		end
	end
	frame:GetAttributeChangedSignal("OnEnemy"):Connect(recolor)
	recolor()
	crosshair = frame
end

local function sizeCrosshair(size: number)
	local frame = crosshair
	if not frame then
		return
	end
	local length = size / 2 - 6
	frame.Size = UDim2.fromOffset(size, size)
	for _, piece in ipairs(crosshairParts) do
		if piece.Name == "Top" or piece.Name == "Bottom" then
			piece.Size = UDim2.fromOffset(2, length)
		elseif piece.Name == "Left" or piece.Name == "Right" then
			piece.Size = UDim2.fromOffset(length, 2)
		end
	end
end

-- Touch only. Hold to fire: AimService.SetFiring(true) on press, false on release.
local function buildFireButton(gui: GuiObject)
	local button = New("TextButton", {
		Name = "Fire",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -144, 1, -24),
		Size = UDim2.fromOffset(90, 90),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.2,
		AutoButtonColor = false,
		Active = true,
		Text = "",
		Visible = false,
		Parent = gui,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UIKit.Stroke(RED_HIT, 3, 0.1).Parent = button
	local press = New("UIScale", { Name = "Press", Scale = 1, Parent = button })

	-- Reticle glyph drawn with frames
	local ring = New("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.36, 0.36),
		BackgroundTransparency = 1,
		Active = false,
		Parent = button,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), UIKit.Stroke(WHITE, 3, 0) })
	New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = RED_HIT,
		BorderSizePixel = 0,
		Active = false,
		Parent = ring,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Label({
		Name = "Caption",
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.26),
		Text = "FIRE",
		TextSize = ts(16),
		Parent = button,
	})

	local held: InputObject? = nil
	local firing = false
	local function setFiring(on: boolean)
		if firing == on then
			return
		end
		firing = on
		AimService.SetFiring(on)
		TweenService:Create(press, TweenInfo.new(0.08), { Scale = on and 0.9 or 1 }):Play()
		button.BackgroundTransparency = on and 0 or 0.2
		button.BackgroundColor3 = on and Color3.fromRGB(120, 30, 40) or Colors.Panel
	end
	local function release(input: InputObject?)
		if input == nil or input == held then
			held = nil
			setFiring(false)
		end
	end

	button.InputBegan:Connect(function(input)
		if held then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			held = input
			setFiring(true)
			local connection: RBXScriptConnection? = nil
			connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
					if connection then
						connection:Disconnect()
					end
					release(input)
				end
			end)
		end
	end)
	button.InputEnded:Connect(function(input)
		release(input)
	end)
	-- Hidden (menu opened, died, left the match) means stop firing
	button:GetPropertyChangedSignal("Visible"):Connect(function()
		if not button.Visible then
			release(nil)
		end
	end)

	fireButton = button
end

local function buildHitMarker(gui: GuiObject)
	local marker = New("Frame", {
		Name = "HitMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Rotation = 45,
		Visible = false,
		Active = false,
		Parent = gui,
	})
	local bars = {}
	for _, props in ipairs({
		{ UDim2.new(0.5, -1.5, 0, 0), UDim2.fromOffset(3, 30) },
		{ UDim2.new(0, 0, 0.5, -1.5), UDim2.fromOffset(30, 3) },
	}) do
		table.insert(bars, New("Frame", {
			Position = props[1],
			Size = props[2],
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Active = false,
			Parent = marker,
		}))
	end

	local token = 0
	Remotes:WaitForChild("HitMarker").OnClientEvent:Connect(function(headshot, killed)
		token += 1
		local mine = token
		local color = killed and Colors.Bad or (headshot and Colors.Accent or Color3.new(1, 1, 1))
		for _, bar in ipairs(bars) do
			bar.BackgroundColor3 = color
		end
		marker.Visible = true
		marker.Size = UDim2.fromOffset(killed and 44 or 30, killed and 44 or 30)
		task.delay(0.18, function()
			if token == mine then
				marker.Visible = false
			end
		end)
	end)
end

local function buildEndScreen(gui: GuiObject)
	local overlay = New("Frame", {
		Name = "EndScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Active = false,
		ZIndex = 20,
		Parent = gui,
	})
	local title = Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.new(1, -24, 0, 70),
		TextSize = 54,
		ZIndex = 21,
		Parent = overlay,
	})
	local score = Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.49),
		Size = UDim2.new(1, -24, 0, 50),
		TextSize = 36,
		ZIndex = 21,
		Parent = overlay,
	})
	local mvp = Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(1, -24, 0, 30),
		TextSize = 20,
		TextColor3 = Colors.Accent,
		ZIndex = 21,
		Parent = overlay,
	})
	Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "Teams will be reshuffled for the next match",
		TextSize = ts(15),
		TextColor3 = Colors.Muted,
		ZIndex = 21,
		Parent = overlay,
	})

	Remotes:WaitForChild("RoundEnd").OnClientEvent:Connect(function(result)
		if result.Winner == "Draw" then
			title.Text = "DRAW"
			title.TextColor3 = Colors.Text
		else
			title.Text = string.upper(result.Winner) .. " TEAM WINS"
			title.TextColor3 = Config.TeamColor(result.Winner)
		end
		score.Text = ("%d  -  %d"):format(result.Red, result.Blue)
		mvp.Text = result.MVP and ("MVP: %s"):format(result.MVP) or ""

		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		TweenService:Create(overlay, TweenInfo.new(0.5), { BackgroundTransparency = 0.45 }):Play()
		task.delay(math.max(1, result.Duration - 0.6), function()
			TweenService:Create(overlay, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			task.wait(0.5)
			overlay.Visible = false
		end)
	end)
end

local function buildCountdown(gui: GuiObject)
	local number = Label({
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(400, 200),
		TextSize = 150,
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(10, 12, 24),
		ZIndex = 30,
		Parent = gui,
	})
	local scale = New("UIScale", { Scale = 1, Parent = number })

	local flash = New("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 40,
		Parent = gui,
	})

	local token = 0
	Remotes:WaitForChild("Countdown").OnClientEvent:Connect(function(value)
		token += 1
		local mine = token
		local isGo = value == "GO"
		number.Text = isGo and "GO!" or tostring(value)
		number.TextColor3 = isGo and Colors.Good or Colors.Text
		number.TextTransparency = 0
		number.TextStrokeTransparency = 0.3
		scale.Scale = 1.6
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(isGo and 0.9 or 0.75, function()
			if token == mine then
				TweenService:Create(number, TweenInfo.new(0.25), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end)

	Remotes:WaitForChild("Flash").OnClientEvent:Connect(function()
		-- Never a full white screen: start at 0.45 and fade quickly. Skipped entirely
		-- when the player asked for fewer flashes.
		if Settings.Get("ReduceFlashes") == true then
			return
		end
		flash.BackgroundTransparency = 0.45
		TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	end)
end

local function showHint(gui: GuiObject)
	local controls = UIKit.IsTouch() and "Hold FIRE to shoot  -  drag the right side to turn  -  ability button"
		or "Move the mouse to aim  -  left click to shoot  -  Q ability  -  C classes  -  B shop"
	local hint = Label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.new(1, -24, 0, 52),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.2,
		Text = "Grab the enemy flag and bring it to your base.\n" .. controls,
		TextSize = ts(14),
		TextWrapped = true,
		Parent = gui,
	})
	UIKit.Corner(8).Parent = hint
	New("UISizeConstraint", { MaxSize = Vector2.new(620, 52), Parent = hint })
	fadeOut({ hint }, 14, 1)
end

-- Hides the match pieces while the main menu is open. Toasts, the countdown
-- and the panels stay available. Crosshair and FIRE are handled by refreshState.
local MENU_HIDDEN = { "Scoreboard", "Feed", "Ability", "Toolbar", "Hint", "ProfileBar", "SettingsButton" }

-- Crosshair and FIRE show only in a match with no menu or panel open
local function refreshState()
	local show = player:GetAttribute("InGame") == true and player:GetAttribute("MenuOpen") ~= true and not inMainMenu
	if crosshair then
		crosshair.Visible = show
	end
	if fireButton then
		fireButton.Visible = show and UIKit.IsTouch()
	end
end

-- The only writer of the Player attribute "MenuOpen". Panels call it with true on
-- open and false on close. The main menu keeps it true through SetInMenu.
function Hud.SetMenuOpen(open: boolean)
	panelOpen = open
	player:SetAttribute("MenuOpen", inMainMenu or panelOpen)
	refreshState()
end

-- The single device scale of the HUD tree (applied once, on the Scaled wrapper)
function Hud.GetDeviceScale(): number
	return Device.Scale()
end

-- The Settings "Large interface" scale on Root (1 when absent)
function Hud.GetHudScale(): number
	local root = Hud.Root
	local scale = root and root:FindFirstChild("HudScale")
	if scale and scale:IsA("UIScale") then
		return scale.Scale
	end
	return 1
end

-- Main menu mode: hides the in-game HUD and counts as a menu being open.
function Hud.SetInMenu(value: boolean)
	inMainMenu = value
	local root = Hud.Root
	if root then
		for _, name in ipairs(MENU_HIDDEN) do
			local item = root:FindFirstChild(name)
			if item and item:IsA("GuiObject") then
				item.Visible = not value
			end
		end
	end
	player:SetAttribute("MenuOpen", inMainMenu or panelOpen)
	refreshState()
end

-- Places every piece by device class. Safe to call again (Main calls it once the
-- Settings gear exists, and it reruns when the viewport changes).
function Hud.Layout()
	local root = Hud.Root
	if not root then
		return
	end
	local class = Device.Get()
	local m = METRICS[class]
	local touch = class ~= "Desktop"
	local scale = Device.Scale() * Hud.GetHudScale()
	local insets = Device.SafeInsets()

	root:SetAttribute("DeviceClass", class)
	root:SetAttribute("SafeTop", insets.Top)
	root:SetAttribute("SafeLeft", insets.Left)
	root:SetAttribute("SafeRight", insets.Right)
	root:SetAttribute("SafeBottom", insets.Bottom)

	-- The ScreenGui starts at the screen edge, so the top bar and, when
	-- ScreenInsets could not be set, the device edges are added here.
	local top = insets.Top / scale
	local left, right, bottom = 0, 0, 0
	if not Hud.InsetsApplied then
		left, right, bottom = insets.Left / scale, insets.Right / scale, insets.Bottom / scale
	end

	local gearSize = touch and 52 or 48
	local gear = root:FindFirstChild("SettingsButton")
	if gear and gear:IsA("GuiObject") then
		gear.Position = UDim2.fromOffset(12 + left, top + 6)
		gear.Size = UDim2.fromOffset(gearSize, gearSize)
	end

	local profile = root:FindFirstChild("ProfileBar")
	local toolbar = root:FindFirstChild("Toolbar")
	if profile and profile:IsA("GuiObject") and toolbar and toolbar:IsA("GuiObject") then
		if touch then
			-- The left bottom corner belongs to the thumbstick, so these stack
			-- under the top bar
			profile.AnchorPoint = Vector2.new(0, 0)
			profile.Position = UDim2.fromOffset(12 + left, top + 6 + gearSize + 8)
			toolbar.AnchorPoint = Vector2.new(0, 0)
			toolbar.Position = UDim2.fromOffset(12 + left, top + 6 + gearSize + 8 + 60 + 8)
			toolbar.Size = UDim2.fromOffset(248, m.Button)
		else
			profile.AnchorPoint = Vector2.new(0, 1)
			profile.Position = UDim2.new(0, 12 + left, 1, -(70 + bottom))
			toolbar.AnchorPoint = Vector2.new(0, 1)
			toolbar.Position = UDim2.new(0, 12 + left, 1, -(12 + bottom))
			toolbar.Size = UDim2.fromOffset(250, m.Button)
		end
		for _, child in ipairs(toolbar:GetChildren()) do
			if child:IsA("GuiButton") then
				child.Size = UDim2.fromOffset(touch and 120 or 121, m.Button)
			end
		end
	end

	local feed = root:FindFirstChild("Feed")
	if feed and feed:IsA("GuiObject") then
		feed.Position = UDim2.new(1, -(12 + right), 0, 116)
		feed.Size = UDim2.fromOffset(m.Feed, 220)
	end
	local toasts = root:FindFirstChild("Toasts")
	if toasts and toasts:IsA("GuiObject") then
		toasts.Position = UDim2.new(0.5, 0, 1, -(150 + bottom))
	end

	local ability = root:FindFirstChild("Ability")
	if ability and ability:IsA("GuiObject") then
		ability.AnchorPoint = Vector2.new(1, 1)
		ability.Size = UDim2.fromOffset(m.Ability, m.Ability)
		if touch then
			-- Left of and above FIRE, inside the thumb arc
			ability.Position = UDim2.new(1, -(right + m.JumpW + m.Fire + 12), 1, -(bottom + m.Margin + 56))
		else
			ability.Position = UDim2.new(1, -(m.Margin + right), 1, -(110 + bottom))
		end
	end

	local fire = fireButton
	if fire then
		-- Sits left of the jump button zone (JumpW wide, bottom 150/190 tall) so
		-- that corner stays free for the Roblox jump button
		fire.Size = UDim2.fromOffset(m.Fire, m.Fire)
		fire.Position = UDim2.new(1, -(right + m.JumpW), 1, -(bottom + m.Margin))
	end

	if not hudScaleHooked then
		local hudScale = root:FindFirstChild("HudScale")
		if hudScale and hudScale:IsA("UIScale") then
			hudScaleHooked = true
			hudScale:GetPropertyChangedSignal("Scale"):Connect(Hud.Layout)
		end
	end

	sizeCrosshair(touch and 32 or 24)
	refreshState()
end

function Hud.Init()
	local screenGui = New("ScreenGui", {
		Name = "TakeTheFlagHud",
		DisplayOrder = 10,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Hud.InsetsApplied = pcall(function()
		screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	Hud.Gui = screenGui

	-- The device scale lives on a wrapper so Settings can keep its own UIScale on
	-- Root. Neither frame is Active, so touches fall through to the camera drag.
	local scaled = New("Frame", {
		Name = "Scaled",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = screenGui,
	})
	UIKit.ApplyDeviceScale(scaled)

	-- Everything lives in one full-size root so Settings can scale the HUD
	-- without breaking edge anchoring (see Settings.updateScale)
	local gui = New("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = scaled,
	})
	Hud.Root = gui

	local board = buildScoreboard(gui)
	local chips = buildFlagChips(gui)
	buildProfileBar(gui)
	buildFeeds(gui)
	local updateAbility = buildAbilityButton(gui)
	buildToolbar(gui)
	buildCrosshair(gui)
	buildFireButton(gui)
	buildHitMarker(gui)
	buildEndScreen(gui)
	buildCountdown(gui)
	showHint(gui)

	player:GetAttributeChangedSignal("InGame"):Connect(refreshState)
	player:GetAttributeChangedSignal("MenuOpen"):Connect(refreshState)

	Hud.Layout()
	Hud.SetInMenu(inMainMenu)

	if not layoutHooked then
		layoutHooked = true
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(Hud.Layout)
		end
	end

	RunService.Heartbeat:Connect(function()
		local state = Workspace:GetAttribute("RoundState") or "Waiting"
		local timerEnd = Workspace:GetAttribute("TimerEnd") or 0
		local remaining = timerEnd - Workspace:GetServerTimeNow()

		board.Red.Text = tostring(Workspace:GetAttribute("RedScore") or 0)
		board.Blue.Text = tostring(Workspace:GetAttribute("BlueScore") or 0)

		if state == "Waiting" then
			board.Timer.Text = "--:--"
			board.State.Text = "WAITING FOR PLAYERS"
		elseif state == "Intermission" then
			board.Timer.Text = UIKit.FormatTime(remaining)
			board.State.Text = "GET READY"
		elseif state == "Playing" then
			board.Timer.Text = UIKit.FormatTime(remaining)
			if Workspace:GetAttribute("Overtime") then
				board.State.Text = "OVERTIME - NEXT CAP WINS"
			else
				board.State.Text = ("FIRST TO %d CAPTURES"):format(Workspace:GetAttribute("CapsToWin") or Config.CapsToWin)
			end
		else
			board.Timer.Text = "0:00"
			board.State.Text = "MATCH OVER"
		end

		for teamName, chip in pairs(chips) do
			chip.Visible = not inMainMenu and state ~= "Waiting" and state ~= "Intermission"
			local flagState = Workspace:GetAttribute(teamName .. "Flag") or "Home"
			local carrier = Workspace:GetAttribute(teamName .. "Carrier") or ""
			if flagState == "Carried" then
				chip.Text = (string.upper(teamName) .. " FLAG: " .. carrier)
				chip.TextColor3 = Colors.Accent
			elseif flagState == "Dropped" then
				chip.Text = string.upper(teamName) .. " FLAG: DROPPED"
				chip.TextColor3 = Colors.Bad
			else
				chip.Text = string.upper(teamName) .. " FLAG: AT BASE"
				chip.TextColor3 = Colors.Text
			end
		end

		updateAbility()
	end)
end

return Hud
