local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent.UIKit)

local New, Label, Colors = UIKit.New, UIKit.Label, UIKit.Colors
local player = Players.LocalPlayer

-- Settings live for the current session only (Roblox has no local storage
-- for client scripts). They reset when the player rejoins the game.
local Settings = {}
Settings.Changed = Instance.new("BindableEvent")

local values: { [string]: any } = {
	ReduceFlashes = false,
	ShowTutorialHints = true,
	LargeText = false,
	ColorBlindMarks = false,
}

local OPTIONS = {
	{ Key = "ReduceFlashes", Title = "Reduce flashes", Hint = "Skips the white screen flash when a match starts" },
	{ Key = "ShowTutorialHints", Title = "Show tutorial tips", Hint = "Short help messages for new players" },
	{ Key = "LargeText", Title = "Large interface", Hint = "Makes the whole screen bigger" },
	{ Key = "ColorBlindMarks", Title = "Team letters", Hint = "Adds R and B letters next to team colors" },
}

local gui: Frame? = nil
local uiScale: UIScale? = nil
local panel: Frame? = nil
local toggles: { [string]: TextButton } = {}

function Settings.Get(key: string): any
	return values[key]
end

local function updateScale()
	if not uiScale then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize.X or 1000
	-- Never scale below 1, so 44px touch targets and 14px text keep their size.
	-- The scaled root is sized 1/scale, so it still fills the screen and
	-- edge anchored elements stay on their edges.
	local scale = 1
	if values.LargeText then
		scale = viewport < 700 and 1.1 or 1.25
	end
	uiScale.Scale = scale
	if gui then
		gui.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
end

local function refreshToggle(key: string)
	local button = toggles[key]
	if not button then
		return
	end
	local on = values[key] == true
	button.Text = on and "ON" or "OFF"
	button.BackgroundColor3 = on and Colors.Good or Colors.PanelLight
	button.TextColor3 = on and Color3.fromRGB(15, 25, 20) or Colors.Text
end

-- Letter marks so teams are not told apart by color alone
local function applyMarks()
	if not gui then
		return
	end
	local enabled = values.ColorBlindMarks == true
	local marks = { Red = "R", Blue = "B" }
	for _, descendant in ipairs(gui:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			local teamName: string? = nil
			if descendant.Name == "Team" and descendant.Parent and descendant.Parent.Parent
				and descendant.Parent.Parent.Name == "Scoreboard" then
				local upper = string.upper(descendant.Text)
				if string.find(upper, "RED", 1, true) then
					teamName = "Red"
				elseif string.find(upper, "BLUE", 1, true) then
					teamName = "Blue"
				end
				if teamName then
					descendant.Text = enabled and (marks[teamName] .. "  " .. string.upper(teamName)) or string.upper(teamName)
				end
			elseif descendant.Name == "RedChip" or descendant.Name == "BlueChip" then
				local existing = descendant:FindFirstChild("TeamMark")
				if existing then
					existing:Destroy()
				end
				if enabled then
					local letter = descendant.Name == "RedChip" and "R" or "B"
					Label({
						Name = "TeamMark",
						Size = UDim2.fromOffset(22, 22),
						Position = UDim2.fromOffset(2, 1),
						Text = letter,
						TextSize = 15,
						TextColor3 = Colors.Accent,
						Parent = descendant,
					})
				end
			end
		end
	end
end

function Settings.Set(key: string, value: any)
	if values[key] == nil or typeof(value) ~= "boolean" or values[key] == value then
		return
	end
	values[key] = value
	player:SetAttribute("Setting_" .. key, value)
	refreshToggle(key)
	if key == "LargeText" then
		updateScale()
	elseif key == "ColorBlindMarks" then
		applyMarks()
	end
	Settings.Changed:Fire(key, value)
end

function Settings.Toggle()
	if panel then
		panel.Visible = not panel.Visible
	end
end

local function buildPanel(parent: GuiObject)
	local frame = New("Frame", {
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Active = true,
		ZIndex = 20,
		Parent = parent,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(Colors.Stroke, 2, 0.2),
		New("UISizeConstraint", { MaxSize = Vector2.new(420, 120 + #OPTIONS * 68) }),
	})
	panel = frame

	Label({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -80, 0, 32),
		Text = "SETTINGS",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = frame,
	})
	local close = UIKit.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(44, 44),
		Text = "X",
		ZIndex = 21,
		Parent = frame,
	})
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	local list = New("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 1, -96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 21,
		Parent = frame,
	}, {
		New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	for index, option in ipairs(OPTIONS) do
		local row = New("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -10, 0, 64),
			BackgroundColor3 = Colors.PanelLight,
			ZIndex = 21,
			Parent = list,
		}, { UIKit.Corner(10) })
		Label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -100, 0, 22),
			Text = option.Title,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
			Parent = row,
		})
		Label({
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -100, 0, 34),
			Text = option.Hint,
			TextSize = 13,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Colors.Muted,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ZIndex = 22,
			Parent = row,
		})
		local toggle = UIKit.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(68, 44),
			ZIndex = 22,
			Parent = row,
		})
		toggles[option.Key] = toggle
		refreshToggle(option.Key)
		toggle.Activated:Connect(function()
			Settings.Set(option.Key, not values[option.Key])
		end)
	end

	Label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "Settings are kept until you leave the game.",
		TextSize = 13,
		TextColor3 = Colors.Muted,
		Font = Enum.Font.Gotham,
		ZIndex = 21,
		Parent = frame,
	})
end

function Settings.Init(hudGui: Frame)
	gui = hudGui
	uiScale = New("UIScale", { Name = "HudScale", Scale = 1, Parent = hudGui })

	for key, value in pairs(values) do
		player:SetAttribute("Setting_" .. key, value)
	end

	buildPanel(hudGui)

	local gear = UIKit.Button({
		Name = "SettingsButton",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(48, 44),
		Text = "G",
		TextSize = 20,
		BackgroundColor3 = Colors.Panel,
		Parent = hudGui,
	})
	UIKit.Stroke(Colors.Stroke, 1.5, 0.3).Parent = gear
	gear.Activated:Connect(Settings.Toggle)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			Settings.Toggle()
		end
	end)

	-- Scale from the viewport width, so phones get a smaller, fitting layout
	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	-- Team letters need to follow labels that the HUD creates or rewrites
	hudGui.DescendantAdded:Connect(function(descendant)
		if values.ColorBlindMarks and descendant:IsA("TextLabel")
			and (descendant.Name == "RedChip" or descendant.Name == "BlueChip" or descendant.Name == "Team") then
			task.defer(applyMarks)
		end
	end)
end

return Settings
