local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Device = require(ReplicatedStorage.Shared.Device)

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(18, 21, 34),
	PanelLight = Color3.fromRGB(30, 35, 56),
	Stroke = Color3.fromRGB(70, 80, 120),
	Text = Color3.fromRGB(240, 243, 255),
	Muted = Color3.fromRGB(150, 160, 195),
	Accent = Color3.fromRGB(255, 205, 70),
	Good = Color3.fromRGB(90, 230, 140),
	Bad = Color3.fromRGB(255, 100, 100),
	Level = Color3.fromRGB(190, 120, 255),
}

function UIKit.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

function UIKit.Corner(radius: number): UICorner
	return UIKit.New("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function UIKit.Stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return UIKit.New("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.Padding(amount: number): UIPadding
	local pad = UDim.new(0, amount)
	return UIKit.New("UIPadding", { PaddingLeft = pad, PaddingRight = pad, PaddingTop = pad, PaddingBottom = pad })
end

function UIKit.Label(props: { [string]: any }): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UIKit.Colors.Text,
		TextSize = 16,
		Text = "",
	}
	for key, value in pairs(props) do
		merged[key] = value
	end
	return UIKit.New("TextLabel", merged)
end

function UIKit.Button(props: { [string]: any }): TextButton
	local merged = {
		AutoButtonColor = true,
		BackgroundColor3 = UIKit.Colors.PanelLight,
		Font = Enum.Font.GothamBold,
		TextColor3 = UIKit.Colors.Text,
		TextSize = math.max(15, UIKit.EffectiveMinText()),
		Text = "",
	}
	for key, value in pairs(props) do
		merged[key] = value
	end
	return UIKit.New("TextButton", merged, { UIKit.Corner(8) })
end

-- Smallest readable text size for the current device class.
function UIKit.MinTextSize(): number
	local class = Device.Get()
	if class == "Tablet" then
		return 16
	end
	return 14
end

-- Text size to author inside the scaled HUD tree so it renders at MinTextSize
function UIKit.EffectiveMinText(): number
	return math.ceil(UIKit.MinTextSize() / Device.Scale())
end

UIKit.TitleSize = 18
UIKit.MinHitTarget = 44

-- Returns "Phone", "Tablet" or "Desktop".
function UIKit.DeviceClass(): string
	return Device.Get()
end

-- True when the device uses touch controls (phone or tablet).
function UIKit.IsTouch(): boolean
	return Device.IsTouchPrimary()
end

-- Adds (or reuses) a UIScale named "DeviceScale" on a full screen root and keeps
-- it in sync with Device.Scale(). The root size is divided by the scale, so a root
-- that filled the screen still fills it. Returns the UIScale.
function UIKit.ApplyDeviceScale(root: GuiObject): UIScale
	-- Inside the HUD tree the wrapper already scales everything: do nothing
	local wrapper = root:FindFirstAncestor("Scaled")
	if wrapper then
		local outer = wrapper:FindFirstChild("DeviceScale")
		if outer and outer:IsA("UIScale") then
			return outer
		end
	end
	local existing = root:FindFirstChild("DeviceScale")
	local scale: UIScale
	if existing and existing:IsA("UIScale") then
		scale = existing
	else
		scale = UIKit.New("UIScale", { Name = "DeviceScale", Parent = root })
	end
	local base = root.Size
	local function update()
		local value = Device.Scale()
		scale.Scale = value
		root.Size = UDim2.new(base.X.Scale / value, base.X.Offset, base.Y.Scale / value, base.Y.Offset)
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

function UIKit.FormatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

return UIKit
