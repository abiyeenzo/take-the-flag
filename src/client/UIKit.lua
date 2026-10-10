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
		TextSize = 15,
		Text = "",
	}
	for key, value in pairs(props) do
		merged[key] = value
	end
	return UIKit.New("TextButton", merged, { UIKit.Corner(8) })
end

function UIKit.FormatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

return UIKit
