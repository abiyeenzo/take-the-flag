local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Settings = require(script.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local New, Label, Colors = UIKit.New, UIKit.Label, UIKit.Colors
local player = Players.LocalPlayer

local Tutorial = {}

local started = false
local card: Frame? = nil

local function getSteps(): { { Title: string, Text: string } }
	local touch = UserInputService.TouchEnabled
	return {
		{
			Title = "Move and look",
			Text = touch and "Drag the left side of the screen to run. Drag the right side to look around."
				or "Use W A S D to run. Move the mouse to look around. Press Space to jump.",
		},
		{
			Title = "Tag the other team",
			Text = touch and "Tap the screen to shoot your blaster. Tag players on the other team to eliminate them."
				or "Click to shoot your blaster. Hold the button to keep shooting. Tag players on the other team.",
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
			Text = touch and "Tap the round ability button for a special power. Use the SHOP button to get new blasters and trails."
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
	local touch = UserInputService.TouchEnabled
	local steps = getSteps()
	local index = 1

	local frame = New("Frame", {
		Name = "Tutorial",
		AnchorPoint = touch and Vector2.new(0.5, 0) or Vector2.new(0.5, 1),
		-- On phones: top center under the scoreboard, clear of the thumbstick and the toasts
		Position = touch and UDim2.new(0.5, 0, 0, 164) or UDim2.new(0.5, 0, 1, -130),
		Size = touch and UDim2.new(0.7, 0, 0, 110) or UDim2.fromOffset(460, 150),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.05,
		ZIndex = 15,
		Parent = gui,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(Colors.Accent, 2, 0.2),
		New("UISizeConstraint", {
			MaxSize = Vector2.new(460, touch and 110 or 150),
			MinSize = Vector2.new(280, touch and 110 or 150),
		}),
	})
	card = frame

	local step = Label({
		Position = touch and UDim2.fromOffset(16, 6) or UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 18),
		TextSize = 13,
		TextColor3 = Colors.Accent,
		TextXAlignment = touch and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
		ZIndex = 16,
		Parent = frame,
	})
	local title = Label({
		Position = touch and UDim2.fromOffset(16, 4) or UDim2.fromOffset(16, 26),
		Size = UDim2.new(1, -32, 0, 24),
		TextSize = touch and 18 or 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 16,
		Parent = frame,
	})
	local body = Label({
		Position = touch and UDim2.fromOffset(16, 28) or UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, touch and 34 or 50),
		TextSize = 15,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 16,
		Parent = frame,
	})

	local skip = UIKit.Button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, touch and -4 or -10),
		Size = UDim2.fromOffset(90, 44),
		Text = "Skip",
		ZIndex = 16,
		Parent = frame,
	})
	local next = UIKit.Button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, touch and -4 or -10),
		Size = UDim2.fromOffset(120, 44),
		BackgroundColor3 = Colors.Good,
		TextColor3 = Color3.fromRGB(15, 25, 20),
		ZIndex = 16,
		Parent = frame,
	})

	local function render()
		local current = steps[index]
		step.Text = ("TIP %d OF %d"):format(index, #steps)
		title.Text = current.Title
		body.Text = current.Text
		next.Text = index == #steps and "Let's play!" or "Got it"
	end
	render()

	-- Tips hide by themselves on phones so they never sit over the play area
	if touch then
		task.delay(20, function()
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
		if started or not Settings.Get("ShowTutorialHints") then
			return
		end
		started = true
		task.delay(2, function()
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

	if player.Character then
		tryStart()
	else
		player.CharacterAdded:Once(tryStart)
	end
end

return Tutorial
