-- Client-only device helper. Server requires get neutral defaults.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Device = {}

local FALLBACK = Vector2.new(1280, 720)

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
		return camera.ViewportSize
	end
	return FALLBACK
end

-- True on touch devices without a mouse. Touch laptops with a mouse count as desktop.
function Device.IsTouchPrimary(): boolean
	if not RunService:IsClient() then
		return false
	end
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

function Device.Get(): string
	if not Device.IsTouchPrimary() then
		return "Desktop"
	end
	local vp = viewport()
	if math.min(vp.X, vp.Y) >= 600 then
		return "Tablet"
	end
	return "Phone"
end

function Device.Scale(): number
	if not RunService:IsClient() then
		return 1
	end
	local vp = viewport()
	local short = math.min(vp.X, vp.Y)
	if short >= 1080 then
		return 1.15
	end
	if Device.Get() == "Phone" and short < 700 then
		return 0.85
	end
	return 1
end

function Device.SafeInsets(): { Top: number, Left: number, Right: number, Bottom: number }
	local insets = { Top = 0, Left = 0, Right = 0, Bottom = 0 }
	if not RunService:IsClient() then
		return insets
	end
	local ok, topLeft, bottomRight = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok then
		insets.Top = topLeft.Y
		insets.Left = topLeft.X
		insets.Right = bottomRight.X
		insets.Bottom = bottomRight.Y
	end
	local okSafe, safe = pcall(function()
		return (GuiService :: any):GetSafeZoneOffsets()
	end)
	if okSafe and type(safe) == "table" then
		insets.Top = math.max(insets.Top, safe.top or 0)
		insets.Left = math.max(insets.Left, safe.left or 0)
		insets.Right = math.max(insets.Right, safe.right or 0)
		insets.Bottom = math.max(insets.Bottom, safe.bottom or 0)
	end
	return insets
end

return Device
