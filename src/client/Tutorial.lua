local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(ReplicatedStorage.Shared.Device)
local Settings = require(script.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local New, Label, Colors = UIKit.New, UIKit.Label, UIKit.Colors
local player = Players.LocalPlayer

local Tutorial = {}

local started = false
local card: Frame? = nil

local function getSteps(): { { Title: string, Text: string } }
	local touch = Device.Get() ~= "Desktop"
	return {
		{
			Title = "Move and look",
			Text = touch and "Drag the left side of the screen to run. Drag the right side of the screen to turn and look around."
				or "Use W A S D to run. Move the mouse to put the crosshair on the target. Press Space to jump.",
		},
		{
			Title = "Tag the other team",
			Text = touch and "Put the crosshair in the middle of the screen on an enemy, then hold the FIRE button to shoot. Tag players on the other team."
				or "Move the mouse to put the crosshair on the target, then left click to shoot. Hold the button to keep shooting.",
		},
		{
			Title = "Grab their flag",
			Text = "Run to the flag in the other team's base and touch it. Now you are carrying it!",
		},
		{
			Title = "Bring it home",
			Text = "Carry the flag back to your own base to score. Your own flag must be at home first.",
		},
		{
			Title = "Abilities and shop",
			Text = touch and "Tap the ability button for your special power. Use the SHOP button to get new blasters and trails."
				or "Press Q for your special power. Press B for the shop and C to change class.",
		},
	}
end

local function destroyCard()
	if card then
		card:Destroy()
		card = nil
	end
end

-- Closing also resets `started`, so turning the tips back on shows them again
local function close()
	destroyCard()
	started = false
end

local function show(gui: GuiObject)
	destroyCard()
	local touch = Device.Get() ~= "Desktop"
	local scale = Device.Scale()
	local minText = Device.Get() == "Tablet" and 16 or 14
	local bodySize = math.ceil(minText / scale)
	local titleSize = math.max(math.ceil(18 / scale), 20)
	local buttonH = math.ceil(44 / scale)
	local steps = getSteps()
	local index = 1

	local frame = New("Frame", {
		Name = "Tutorial",
		AnchorPoint = touch and Vector2.new(0, 0) or Vector2.new(0.5, 1),
		-- Touch: top left under the settings button, clear of the thumbstick, the crosshair and the right-side camera drag
		Position = touch and UDim2.fromOffset(12, math.ceil(60 / scale)) or UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.new(touch and 0.46 or 0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.05,
		Active = false,
		ZIndex = 15,
		Parent = gui,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(Colors.Accent, 2, 0.2),
		UIKit.Padding(12),
		New("UISizeConstraint", {
			MaxSize = Vector2.new(touch and 400 or 520, math.huge),
			MinSize = Vector2.new(260, 0),
		}),
		New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	card = frame

	local step = Label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, bodySize + 4),
		TextSize = bodySize,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 16,
		Parent = frame,
	})
	local title = Label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, titleSize + 4),
		TextSize = titleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 16,
		Parent = frame,
	})
	local body = Label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = bodySize,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 16,
		Parent = frame,
	})

	local buttons = New("Frame", {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, buttonH + 4),
		BackgroundTransparency = 1,
		ZIndex = 16,
		Parent = frame,
	})
	local skip = UIKit.Button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.fromOffset(math.ceil(90 / scale), buttonH),
		Text = "Skip",
		TextSize = bodySize,
		ZIndex = 16,
		Parent = buttons,
	})
	local next = UIKit.Button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(math.ceil(120 / scale), buttonH),
		BackgroundColor3 = Colors.Good,
		TextColor3 = Color3.fromRGB(15, 25, 20),
		TextSize = bodySize,
		ZIndex = 16,
		Parent = buttons,
	})

	local function render()
		local current = steps[index]
		step.Text = ("TIP %d OF %d"):format(index, #steps)
		title.Text = current.Title
		body.Text = current.Text
		next.Text = index == #steps and "Let's play!" or "Got it"
	end
	render()

	-- Tips hide by themselves on touch devices so they never sit over the play area
	if touch then
		task.delay(30, function()
			if card == frame then
				close()
			end
		end)
	end

	skip.Activated:Connect(close)
	next.Activated:Connect(function()
		if index >= #steps then
			close()
		else
			index += 1
			render()
		end
	end)
end

function Tutorial.Init(gui: GuiObject)
	local function tryStart()
		if started or player:GetAttribute("InGame") ~= true or not Settings.Get("ShowTutorialHints") then
			return
		end
		started = true
		task.delay(1.5, function()
			if Settings.Get("ShowTutorialHints") and gui.Parent then
				show(gui)
			else
				started = false
			end
		end)
	end

	Settings.Changed.Event:Connect(function(key, value)
		if key ~= "ShowTutorialHints" then
			return
		end
		if value then
			tryStart()
		else
			close()
		end
	end)

	local function check()
		if player:GetAttribute("InGame") == true then
			tryStart()
		else
			destroyCard()
		end
	end
	player:GetAttributeChangedSignal("InGame"):Connect(check)
	check()
end

return Tutorial
