local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local New, Label, Colors = UIKit.New, UIKit.Label, UIKit.Colors

local Menus = {}

local panels: { [string]: Frame } = {}
local refreshers: { [string]: () -> () } = {}

local function buildPanel(gui: ScreenGui, name: string, title: string, size: Vector2)
	local panel = New("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(Colors.Stroke, 2, 0.2),
		New("UISizeConstraint", { MaxSize = Vector2.new(size.X, size.Y) }),
	})

	Label({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -80, 0, 32),
		Text = title,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = panel,
	})
	local close = UIKit.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(40, 32),
		Text = "X",
		ZIndex = 11,
		Parent = panel,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	panels[name] = panel
	return panel
end

local function buildClassMenu(gui: ScreenGui)
	local panel = buildPanel(gui, "Classes", "CHOOSE YOUR CLASS", Vector2.new(660, 360))
	local cards = {}

	for index, id in ipairs(Classes.Order) do
		local def = Classes.Defs[id]
		local card = New("Frame", {
			Position = UDim2.new(0, 20 + (index - 1) * 208, 0, 66),
			Size = UDim2.fromOffset(196, 270),
			BackgroundColor3 = Colors.PanelLight,
			ZIndex = 11,
			Parent = panel,
		}, { UIKit.Corner(10) })
		local stroke = UIKit.Stroke(Colors.Stroke, 2, 0.4)
		stroke.Parent = card

		Label({
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -24, 0, 28),
			Text = string.upper(def.Name),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = card,
		})
		Label({
			Position = UDim2.fromOffset(12, 40),
			Size = UDim2.new(1, -24, 0, 18),
			Text = "ABILITY: " .. string.upper(def.Ability),
			TextSize = 12,
			TextColor3 = Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = card,
		})
		Label({
			Position = UDim2.fromOffset(12, 62),
			Size = UDim2.new(1, -24, 0, 70),
			Text = def.Description,
			TextSize = 13,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			ZIndex = 12,
			Parent = card,
		})
		Label({
			Position = UDim2.fromOffset(12, 140),
			Size = UDim2.new(1, -24, 0, 60),
			Text = ("Health  %d\nSpeed  %.1f\nDamage  %d"):format(def.Health, def.Speed, def.Damage),
			TextSize = 14,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = card,
		})
		local button = UIKit.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -24, 0, 36),
			ZIndex = 12,
			Parent = card,
		})
		button.Activated:Connect(function()
			Remotes.SelectClass:FireServer(id)
		end)
		cards[id] = { Button = button, Stroke = stroke }
	end

	refreshers.Classes = function()
		local profile = Store.Profile
		if not profile then
			return
		end
		for id, card in pairs(cards) do
			local def = Classes.Defs[id]
			if profile.Class == id then
				card.Button.Text = "SELECTED"
				card.Button.BackgroundColor3 = Colors.Good
				card.Button.TextColor3 = Color3.fromRGB(10, 30, 20)
				card.Stroke.Color = Colors.Good
			elseif profile.Level < def.Level then
				card.Button.Text = "UNLOCKS AT LEVEL " .. def.Level
				card.Button.BackgroundColor3 = Colors.Panel
				card.Button.TextColor3 = Colors.Muted
				card.Stroke.Color = Colors.Stroke
			else
				card.Button.Text = "SELECT"
				card.Button.BackgroundColor3 = Colors.Accent
				card.Button.TextColor3 = Color3.fromRGB(30, 24, 6)
				card.Stroke.Color = Colors.Stroke
			end
		end
	end
end

local function buildShop(gui: ScreenGui)
	local panel = buildPanel(gui, "Shop", "TRAIL SHOP", Vector2.new(660, 420))
	local coins = Label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -64, 0, 18),
		Size = UDim2.fromOffset(220, 26),
		Text = "",
		TextSize = 18,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 11,
		Parent = panel,
	})

	local scroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 1, -82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 11,
		Parent = panel,
	}, {
		New("UIGridLayout", {
			CellSize = UDim2.fromOffset(140, 150),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local entries = {}
	local function addCard(id: string, name: string, price: number, swatch: Color3?, order: number)
		local card = New("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = Colors.PanelLight,
			ZIndex = 12,
			Parent = scroll,
		}, { UIKit.Corner(10) })
		local stroke = UIKit.Stroke(Colors.Stroke, 2, 0.4)
		stroke.Parent = card

		local sw = New("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.new(1, -24, 0, 44),
			BackgroundColor3 = swatch or Colors.Panel,
			ZIndex = 13,
			Parent = card,
		}, { UIKit.Corner(8) })
		if id == "ember" or id == "frost" or id == "rainbow" then
			local def = Cosmetics.ById[id]
			New("UIGradient", { Color = def.Color, Parent = sw })
		end
		Label({
			Position = UDim2.fromOffset(8, 62),
			Size = UDim2.new(1, -16, 0, 22),
			Text = name,
			TextSize = 16,
			ZIndex = 13,
			Parent = card,
		})
		local button = UIKit.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 34),
			TextSize = 14,
			ZIndex = 13,
			Parent = card,
		})
		button.Activated:Connect(function()
			local profile = Store.Profile
			if not profile then
				return
			end
			if id == "" then
				Remotes.ShopAction:FireServer("Equip", "")
			elseif Store.Owns(id) then
				Remotes.ShopAction:FireServer("Equip", profile.Equipped == id and "" or id)
			else
				Remotes.ShopAction:FireServer("Buy", id)
			end
		end)
		entries[id] = { Button = button, Stroke = stroke, Price = price }
	end

	addCard("", "No trail", 0, nil, 0)
	for index, trail in ipairs(Cosmetics.Trails) do
		addCard(trail.Id, trail.Name, trail.Price, trail.Swatch, index)
	end

	refreshers.Shop = function()
		local profile = Store.Profile
		if not profile then
			return
		end
		coins.Text = ("%d coins"):format(profile.Coins)
		for id, entry in pairs(entries) do
			local equipped = profile.Equipped == id
			local owned = id == "" or Store.Owns(id)
			entry.Stroke.Color = equipped and Colors.Good or Colors.Stroke
			if equipped then
				entry.Button.Text = "EQUIPPED"
				entry.Button.BackgroundColor3 = Colors.Good
				entry.Button.TextColor3 = Color3.fromRGB(10, 30, 20)
			elseif owned then
				entry.Button.Text = "EQUIP"
				entry.Button.BackgroundColor3 = Colors.Panel
				entry.Button.TextColor3 = Colors.Text
			else
				entry.Button.Text = ("%d coins"):format(entry.Price)
				entry.Button.BackgroundColor3 = profile.Coins >= entry.Price and Colors.Accent or Colors.Panel
				entry.Button.TextColor3 = profile.Coins >= entry.Price and Color3.fromRGB(30, 24, 6) or Colors.Muted
			end
		end
	end
end

function Menus.Toggle(name: string)
	local panel = panels[name]
	if not panel then
		return
	end
	local show = not panel.Visible
	for _, other in pairs(panels) do
		other.Visible = false
	end
	panel.Visible = show
	if show and refreshers[name] then
		refreshers[name]()
	end
end

function Menus.Init(gui: ScreenGui, buttons: { [string]: TextButton })
	buildClassMenu(gui)
	buildShop(gui)

	Store.Changed.Event:Connect(function()
		for name, panel in pairs(panels) do
			if panel.Visible then
				refreshers[name]()
			end
		end
	end)

	buttons.Classes.Activated:Connect(function()
		Menus.Toggle("Classes")
	end)
	buttons.Shop.Activated:Connect(function()
		Menus.Toggle("Shop")
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			Menus.Toggle("Classes")
		elseif input.KeyCode == Enum.KeyCode.B then
			Menus.Toggle("Shop")
		end
	end)
end

return Menus
