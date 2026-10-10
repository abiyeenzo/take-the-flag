local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local New, Label, Colors = UIKit.New, UIKit.Label, UIKit.Colors
local player = Players.LocalPlayer

local Hud = {}
Hud.Buttons = {}

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

local function buildScoreboard(gui: ScreenGui)
	local panel = New("Frame", {
		Name = "Scoreboard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(440, 64),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { UIKit.Corner(12), UIKit.Stroke(Colors.Stroke, 1.5, 0.3) })

	local function scoreBox(teamName: string, left: boolean)
		local box = New("Frame", {
			Size = UDim2.new(0, 110, 1, -12),
			Position = left and UDim2.new(0, 6, 0, 6) or UDim2.new(1, -116, 0, 6),
			BackgroundColor3 = Config.TeamColor(teamName),
			Parent = panel,
		}, { UIKit.Corner(8) })
		Label({
			Name = "Team",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 4),
			Text = string.upper(teamName),
			TextSize = 13,
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
		Size = UDim2.new(0, 190, 0, 34),
		Position = UDim2.new(0.5, -95, 0, 6),
		Text = "--:--",
		TextSize = 28,
		Parent = panel,
	})
	local sub = Label({
		Name = "State",
		Size = UDim2.new(0, 190, 0, 20),
		Position = UDim2.new(0.5, -95, 0, 38),
		Text = "",
		TextSize = 13,
		TextColor3 = Colors.Muted,
		Parent = panel,
	})

	return { Red = redScore, Blue = blueScore, Timer = timer, State = sub }
end

local function buildFlagChips(gui: ScreenGui)
	local chips = {}
	local function chip(teamName: string, xOffset: number)
		local label = Label({
			Name = teamName .. "Chip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, xOffset, 0, 80),
			Size = UDim2.fromOffset(214, 24),
			BackgroundTransparency = 0.25,
			BackgroundColor3 = Colors.Panel,
			TextSize = 13,
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

local function buildProfileBar(gui: ScreenGui)
	local bar = New("Frame", {
		Name = "ProfileBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -70),
		Size = UDim2.fromOffset(250, 60),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { UIKit.Corner(12), UIKit.Stroke(Colors.Stroke, 1.5, 0.3) })

	local badge = New("Frame", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Colors.Level,
		Parent = bar,
	}, { UIKit.Corner(10) })
	local level = Label({ Size = UDim2.fromScale(1, 1), Text = "1", TextSize = 24, Parent = badge })
	Label({
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, 2),
		Text = "LV",
		TextSize = 10,
		TextTransparency = 0.3,
		Parent = badge,
	})

	local track = New("Frame", {
		Size = UDim2.new(1, -70, 0, 10),
		Position = UDim2.fromOffset(62, 12),
		BackgroundColor3 = Colors.PanelLight,
		Parent = bar,
	}, { UIKit.Corner(5) })
	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Colors.Level,
		Parent = track,
	}, { UIKit.Corner(5) })
	local xp = Label({
		Size = UDim2.new(1, -70, 0, 14),
		Position = UDim2.fromOffset(62, 25),
		Text = "0 / 100 XP",
		TextSize = 11,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})
	local coins = Label({
		Size = UDim2.new(1, -70, 0, 16),
		Position = UDim2.fromOffset(62, 39),
		Text = "0 coins",
		TextSize = 14,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})

	Store.Changed.Event:Connect(function(profile)
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
	end)
end

local function buildFeeds(gui: ScreenGui)
	local feed = New("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 100),
		Size = UDim2.fromOffset(340, 220),
		BackgroundTransparency = 1,
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
		push(feed, text, team and Config.TeamColor(team) or Colors.Text, 15, 6, 6)
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
		push(toasts, text, color, kind == "level" and 22 or 16, kind == "level" and 4 or 2.5, 4)
	end)
end

local function buildAbilityButton(gui: ScreenGui)
	local button = New("TextButton", {
		Name = "Ability",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -110),
		Size = UDim2.fromOffset(86, 86),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		Parent = gui,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), UIKit.Stroke(Colors.Accent, 3, 0.1) })

	local name = Label({
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0.5, -20),
		Text = "",
		TextSize = 12,
		Parent = button,
	})
	local key = Label({
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0.5, 2),
		Text = "Q",
		TextSize = 18,
		TextColor3 = Colors.Accent,
		Parent = button,
	})
	local cooldown = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = button,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local counter = Label({ Size = UDim2.fromScale(1, 1), TextSize = 26, Parent = cooldown })

	button.Activated:Connect(function()
		Remotes.UseAbility:FireServer()
	end)

	return function()
		local def = Classes.Defs[player:GetAttribute("Class")]
		name.Text = def and string.upper(def.Ability) or ""
		local remaining = (player:GetAttribute("AbilityReadyAt") or 0) - Workspace:GetServerTimeNow()
		cooldown.Visible = remaining > 0
		counter.Text = remaining > 0 and tostring(math.ceil(remaining)) or ""
		key.Visible = remaining <= 0
	end
end

local function buildToolbar(gui: ScreenGui)
	local bar = New("Frame", {
		Name = "Toolbar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(250, 48),
		BackgroundTransparency = 1,
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
	button("Classes", "CLASSES  [C]")
	button("Shop", "SHOP  [B]")
end

local function buildHitMarker(gui: ScreenGui)
	local marker = New("Frame", {
		Name = "HitMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Rotation = 45,
		Visible = false,
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

local function buildEndScreen(gui: ScreenGui)
	local overlay = New("Frame", {
		Name = "EndScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local title = Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(700, 70),
		TextSize = 54,
		ZIndex = 21,
		Parent = overlay,
	})
	local score = Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.49),
		Size = UDim2.fromOffset(500, 50),
		TextSize = 36,
		ZIndex = 21,
		Parent = overlay,
	})
	local mvp = Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromOffset(600, 30),
		TextSize = 20,
		TextColor3 = Colors.Accent,
		ZIndex = 21,
		Parent = overlay,
	})
	local nextUp = Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromOffset(600, 24),
		Text = "Teams will be reshuffled for the next match",
		TextSize = 15,
		TextColor3 = Colors.Muted,
		ZIndex = 21,
		Parent = overlay,
	})
	nextUp.Visible = true

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

local function showHint(gui: ScreenGui)
	local hint = Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(560, 44),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.2,
		Text = "Grab the enemy flag and bring it to your base.\nClick to shoot  -  Q ability  -  C classes  -  B shop",
		TextSize = 14,
		Parent = gui,
	})
	UIKit.Corner(8).Parent = hint
	fadeOut({ hint }, 14, 1)
end

function Hud.Init()
	local gui = New("ScreenGui", {
		Name = "TakeTheFlagHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Hud.Gui = gui

	local board = buildScoreboard(gui)
	local chips = buildFlagChips(gui)
	buildProfileBar(gui)
	buildFeeds(gui)
	local updateAbility = buildAbilityButton(gui)
	buildToolbar(gui)
	buildHitMarker(gui)
	buildEndScreen(gui)
	showHint(gui)

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
			board.State.Text = "MATCH STARTS SOON"
		elseif state == "Playing" then
			board.Timer.Text = UIKit.FormatTime(remaining)
			if Workspace:GetAttribute("Overtime") then
				board.State.Text = "OVERTIME - NEXT CAPTURE WINS"
			else
				board.State.Text = ("FIRST TO %d CAPTURES"):format(Workspace:GetAttribute("CapsToWin") or Config.CapsToWin)
			end
		else
			board.Timer.Text = "0:00"
			board.State.Text = "MATCH OVER"
		end

		for teamName, chip in pairs(chips) do
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
