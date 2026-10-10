local UserInputService = game:GetService("UserInputService")

local Controls = require(script.Parent.Controls)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Settings = require(script.Parent.Settings)
local Store = require(script.Parent.Store)
local Tutorial = require(script.Parent.Tutorial)

-- On phones the left bottom corner belongs to the thumbstick and the right
-- bottom corner to the jump button, so the HUD pieces move out of the way.
local function layoutForTouch(gui: GuiObject)
	local ability = gui:FindFirstChild("Ability", true)
	if ability and ability:IsA("GuiObject") then
		ability.AnchorPoint = Vector2.new(1, 1)
		ability.Position = UDim2.new(1, -24, 1, -190)
	end

	local profile = gui:FindFirstChild("ProfileBar", true)
	if profile and profile:IsA("GuiObject") then
		profile.AnchorPoint = Vector2.new(0, 0)
		profile.Position = UDim2.fromOffset(12, 62)
	end

	local toolbar = gui:FindFirstChild("Toolbar", true)
	if toolbar and toolbar:IsA("GuiObject") then
		toolbar.AnchorPoint = Vector2.new(0, 0)
		toolbar.Position = UDim2.fromOffset(12, 130)
		toolbar.Size = UDim2.fromOffset(130, 104)
		local list = toolbar:FindFirstChildOfClass("UIListLayout")
		if list then
			list.FillDirection = Enum.FillDirection.Vertical
		end
		for _, child in ipairs(toolbar:GetChildren()) do
			if child:IsA("GuiButton") then
				child.Size = UDim2.fromOffset(130, 48)
			end
		end
	end
end

Store.Init()
Hud.Init()
Settings.Init(Hud.Root)
Menus.Init(Hud.Root, Hud.Buttons)
Controls.Init()
Tutorial.Init(Hud.Root)

if UserInputService.TouchEnabled then
	layoutForTouch(Hud.Root)
end
