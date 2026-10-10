local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Device = require(ReplicatedStorage.Shared.Device)
local Hud = require(script.Parent.Hud)
local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local New, Label, Colors = UIKit.New, UIKit.Label, UIKit.Colors

local Menus = {}

local panels: { [string]: Frame } = {}
local refreshers: { [string]: () -> () } = {}

-- Effective sizes: the panels are scaled by Device.Scale(), so the unscaled
-- numbers are raised until text and buttons reach the minima on screen.
local SCALE = Device.Scale()
local MIN_TEXT = Device.Get() == "Tablet" and 16 or 14
local function fs(size: number?): number
	return math.max(size or 0, math.ceil(MIN_TEXT / SCALE))
end
local function titleSize(size: number?): number
	return math.max(size or 0, math.ceil(18 / SCALE))
end
local function hit(size: number?): number
	return math.max(size or 0, math.ceil(44 / SCALE))
end
local function line(): number
	return fs() + 4
end

local function buildPanel(gui: GuiObject, name: string, title: string, size: Vector2)
	local panel = New("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Active = true,
		ZIndex = 10,
		Parent = gui,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(Colors.Stroke, 2, 0.2),
		New("UISizeConstraint", { MaxSize = size }),
	})

	Label({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(0.6, -20, 0, hit(32)),
		Text = title,
		TextSize = titleSize(24),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = panel,
	})
	local close = UIKit.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(hit(48), hit(44)),
		Text = "X",
		TextSize = fs(16),
		ZIndex = 11,
		Parent = panel,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	panels[name] = panel
	return panel
end

local DARK_TEXT = Color3.fromRGB(30, 24, 6)

local function styleButton(button: TextButton, text: string, kind: string, enabled: boolean?)
	local usable = enabled ~= false
	button.Text = text
	button.AutoButtonColor = usable
	button.BackgroundTransparency = usable and 0 or 0.45
	button.TextTransparency = usable and 0 or 0.35
	if kind == "good" then
		button.BackgroundColor3 = Colors.Good
		button.TextColor3 = Color3.fromRGB(10, 30, 20)
	elseif kind == "accent" then
		button.BackgroundColor3 = Colors.Accent
		button.TextColor3 = DARK_TEXT
	elseif kind == "level" then
		button.BackgroundColor3 = Colors.Level
		button.TextColor3 = Colors.Text
	else
		button.BackgroundColor3 = Colors.Panel
		button.TextColor3 = Colors.Muted
	end
end

local function buildClassMenu(gui: GuiObject)
	local panel = buildPanel(gui, "Classes", "CHOOSE YOUR CLASS", Vector2.new(720, 440))
	local cards = {}

	local row = New("ScrollingFrame", {
		Position = UDim2.fromOffset(16, hit(32) + 24),
		Size = UDim2.new(1, -32, 1, -(hit(32) + 38)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollingDirection = Enum.ScrollingDirection.XY,
		ZIndex = 11,
		Parent = panel,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for index, id in ipairs(Classes.Order) do
		local def = Classes.Defs[id]
		local card = New("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(220, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Colors.PanelLight,
			ClipsDescendants = true,
			ZIndex = 11,
			Parent = row,
		}, {
			UIKit.Corner(10),
			UIKit.Padding(12),
			New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local stroke = UIKit.Stroke(Colors.Stroke, 2, 0.4)
		stroke.Parent = card

		Label({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, titleSize(22) + 4),
			Text = string.upper(def.Name),
			TextSize = titleSize(22),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = card,
		})
		Label({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, line()),
			Text = "ABILITY: " .. string.upper(def.Ability),
			TextSize = fs(),
			TextColor3 = Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = card,
		})
		Label({
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = def.Description,
			TextSize = fs(),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			ZIndex = 12,
			Parent = card,
		})
		Label({
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, line() * 3),
			Text = ("Health  %d\nSpeed  %.1f\nDamage  x%.1f"):format(def.Health, def.Speed, def.DamageMult),
			TextSize = fs(),
			TextYAlignment = Enum.TextYAlignment.Top,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = card,
		})
		local button = UIKit.Button({
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, hit(44)),
			TextSize = fs(),
			TextWrapped = true,
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
			card.Stroke.Color = Colors.Stroke
			if profile.Class == id then
				styleButton(card.Button, "SELECTED", "good")
				card.Stroke.Color = Colors.Good
			elseif profile.Level < def.Level then
				styleButton(card.Button, "UNLOCKS AT LEVEL " .. def.Level, "muted")
			else
				styleButton(card.Button, "SELECT", "accent")
			end
		end
	end
end

local function buildShop(gui: GuiObject)
	local panel = buildPanel(gui, "Shop", "SHOP", Vector2.new(780, 560))
	local TAB_Y = hit(32) + 26
	local PAGE_Y = TAB_Y + hit(44) + 10
	local coins = Label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(hit(48) + 24), 0, 18),
		Size = UDim2.new(0.4, 0, 0, hit(26)),
		Text = "",
		TextSize = titleSize(18),
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 11,
		Parent = panel,
	})

	local tabBar = New("Frame", {
		Position = UDim2.fromOffset(20, TAB_Y),
		Size = UDim2.new(1, -40, 0, hit(44)),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = panel,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local activeTab = "Weapons"

	local function showTab(name: string)
		activeTab = name
		for id, page in pairs(pages) do
			page.Visible = id == name
			tabButtons[id].BackgroundColor3 = id == name and Colors.Accent or Colors.PanelLight
			tabButtons[id].TextColor3 = id == name and DARK_TEXT or Colors.Text
		end
	end

	local function addTab(name: string, text: string, order: number, cellSize: Vector2)
		local tab = UIKit.Button({
			LayoutOrder = order,
			Size = UDim2.new(0.3, 0, 1, 0),
			TextSize = fs(),
			Text = text,
			ZIndex = 12,
			Parent = tabBar,
		})
		tab.Activated:Connect(function()
			showTab(name)
		end)
		tabButtons[name] = tab

		pages[name] = New("ScrollingFrame", {
			Position = UDim2.fromOffset(20, PAGE_Y),
			Size = UDim2.new(1, -40, 1, -(PAGE_Y + 14)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			ZIndex = 11,
			Parent = panel,
		}, {
			New("UIGridLayout", {
				CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		return pages[name]
	end

	local function newCard(parent: Instance, order: number)
		local card = New("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = Colors.PanelLight,
			ZIndex = 12,
			Parent = parent,
		}, { UIKit.Corner(10) })
		local stroke = UIKit.Stroke(Colors.Stroke, 2, 0.4)
		stroke.Parent = card
		return card, stroke
	end

	local function cardText(card: Frame, y: number, height: number, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
		return Label({
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.new(1, -20, 0, height),
			Text = text,
			TextSize = size,
			TextColor3 = color or Colors.Text,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = font or Enum.Font.GothamBold,
			ZIndex = 13,
			Parent = card,
		})
	end

	local updaters: { () -> () } = {}

	-- WEAPONS tab
	local LH = line()
	local BH = hit(44)
	local weaponDescY = 8 + titleSize(18) + 10
	local weaponStatsY = weaponDescY + LH * 3 + 4
	local weaponH = weaponStatsY + LH * 4 + 6 + BH * 2 + 6 + 10
	local weaponPage = addTab("Weapons", "WEAPONS", 1, Vector2.new(230, weaponH))
	for index, id in ipairs(Weapons.Order) do
		local def = Weapons.Defs[id]
		local card, stroke = newCard(weaponPage, index)
		cardText(card, 8, titleSize(18) + 4, def.Name, titleSize(18))
		cardText(card, weaponDescY, LH * 3, def.Description, fs(), Colors.Muted, Enum.Font.Gotham)
		cardText(
			card,
			weaponStatsY,
			LH * 4,
			("Damage  %d\nFire rate  %.1f / sec\nPellets  %d\nRange  %d"):format(def.Damage, 1 / def.FireDelay, def.Pellets, def.Range),
			fs()
		)

		local main = UIKit.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, BH),
			TextSize = fs(),
			ZIndex = 13,
			Parent = card,
		})
		local robux = UIKit.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -(10 + BH + 6)),
			Size = UDim2.new(1, -20, 0, BH),
			TextSize = fs(),
			ZIndex = 13,
			Parent = card,
		})
		local product = def.RobuxKey and Monetization.Products[def.RobuxKey]

		main.Activated:Connect(function()
			local profile = Store.Profile
			if not profile then
				return
			end
			if Store.OwnsWeapon(id) then
				Remotes.ShopAction:FireServer("EquipWeapon", id)
			elseif def.VipOnly then
				if Monetization.IsAvailable(Monetization.GamePasses.VIP) then
					Remotes.Purchase:FireServer("Pass", "VIP")
				end
			else
				Remotes.ShopAction:FireServer("BuyWeapon", id)
			end
		end)
		robux.Activated:Connect(function()
			if def.RobuxKey and product and Monetization.IsAvailable(product) then
				Remotes.Purchase:FireServer("Product", def.RobuxKey)
			end
		end)

		table.insert(updaters, function()
			local profile = Store.Profile
			if not profile then
				return
			end
			local owned = Store.OwnsWeapon(id)
			local equipped = profile.EquippedWeapon == id
			stroke.Color = equipped and Colors.Good or Colors.Stroke
			robux.Visible = false
			if equipped then
				styleButton(main, "EQUIPPED", "good")
			elseif owned then
				styleButton(main, "EQUIP", "level")
			elseif def.VipOnly then
				if Monetization.IsAvailable(Monetization.GamePasses.VIP) then
					styleButton(main, "VIP ONLY", "accent")
				else
					styleButton(main, "R$ Soon", "muted", false)
				end
			else
				local price = def.CoinPrice or 0
				local afford = profile.Coins >= price
				styleButton(main, ("%d coins"):format(price), afford and "accent" or "muted")
				robux.Visible = true
				if product and Monetization.IsAvailable(product) then
					styleButton(robux, ("R$ %d"):format(product.Robux), "level")
				else
					styleButton(robux, "R$ Soon", "muted", false)
				end
			end
		end)
	end

	-- TRAILS tab
	local trailH = 12 + hit(44) + 8 + LH + 6 + BH + 10
	local trailPage = addTab("Trails", "TRAILS", 2, Vector2.new(170, trailH))
	local function addTrail(id: string, name: string, price: number, swatch: Color3?, order: number)
		local card, stroke = newCard(trailPage, order)
		local trail = Cosmetics.ById[id]
		local sw = New("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.new(1, -24, 0, hit(44)),
			BackgroundColor3 = swatch or Colors.Panel,
			ZIndex = 13,
			Parent = card,
		}, { UIKit.Corner(8) })
		if trail and #trail.Color.Keypoints > 1 then
			New("UIGradient", { Color = trail.Color, Parent = sw })
		end
		Label({
			Position = UDim2.fromOffset(8, 12 + hit(44) + 8),
			Size = UDim2.new(1, -16, 0, LH),
			Text = name,
			TextSize = fs(16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 13,
			Parent = card,
		})
		local button = UIKit.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, BH),
			TextSize = fs(),
			ZIndex = 13,
			Parent = card,
		})
		local vipOnly = trail ~= nil and trail.VipOnly == true
		button.Activated:Connect(function()
			local profile = Store.Profile
			if not profile then
				return
			end
			if id == "" then
				Remotes.ShopAction:FireServer("Equip", "")
			elseif Store.Owns(id) or (vipOnly and profile.VIP) then
				Remotes.ShopAction:FireServer("Equip", profile.Equipped == id and "" or id)
			elseif vipOnly then
				if Monetization.IsAvailable(Monetization.GamePasses.VIP) then
					Remotes.Purchase:FireServer("Pass", "VIP")
				end
			else
				Remotes.ShopAction:FireServer("Buy", id)
			end
		end)
		table.insert(updaters, function()
			local profile = Store.Profile
			if not profile then
				return
			end
			local equipped = profile.Equipped == id
			local owned = id == "" or Store.Owns(id) or (vipOnly and profile.VIP == true)
			stroke.Color = equipped and Colors.Good or Colors.Stroke
			if equipped then
				styleButton(button, "EQUIPPED", "good")
			elseif owned then
				styleButton(button, "EQUIP", "level")
			elseif vipOnly then
				if Monetization.IsAvailable(Monetization.GamePasses.VIP) then
					styleButton(button, "VIP ONLY", "accent")
				else
					styleButton(button, "R$ Soon", "muted", false)
				end
			else
				styleButton(button, ("%d coins"):format(price), profile.Coins >= price and "accent" or "muted")
			end
		end)
	end

	addTrail("", "No trail", 0, nil, 0)
	for index, trail in ipairs(Cosmetics.Trails) do
		addTrail(trail.Id, trail.Name, trail.Price, trail.Swatch, index)
	end

	-- STORE tab (Robux)
	local storeH = 8 + titleSize(18) + 10 + LH * 5 + 6 + BH + 10
	local storePage = addTab("Store", "STORE", 3, Vector2.new(230, storeH))

	local vipDef = Monetization.GamePasses.VIP
	local vipCard, vipStroke = newCard(storePage, 0)
	vipStroke.Color = Colors.Accent
	cardText(vipCard, 8, titleSize(18) + 4, "VIP PASS", titleSize(18), Colors.Accent)
	cardText(vipCard, 8 + titleSize(18) + 10, LH * 5, vipDef.Description, fs(), Colors.Muted, Enum.Font.Gotham)
	local vipButton = UIKit.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, BH),
		TextSize = fs(),
		ZIndex = 13,
		Parent = vipCard,
	})
	vipButton.Activated:Connect(function()
		local profile = Store.Profile
		if profile and not profile.VIP and Monetization.IsAvailable(vipDef) then
			Remotes.Purchase:FireServer("Pass", "VIP")
		end
	end)
	table.insert(updaters, function()
		local profile = Store.Profile
		if not profile then
			return
		end
		if profile.VIP then
			styleButton(vipButton, "OWNED", "good")
		elseif Monetization.IsAvailable(vipDef) then
			styleButton(vipButton, ("R$ %d"):format(vipDef.Robux), "accent")
		else
			styleButton(vipButton, "R$ Soon", "muted", false)
		end
	end)

	for index, key in ipairs(Monetization.CoinPackOrder) do
		local product = Monetization.Products[key]
		local card = newCard(storePage, index)
		cardText(card, 8, titleSize(18) + 4, product.Name, titleSize(18))
		cardText(card, 8 + titleSize(18) + 10, LH * 5, "Instant coins for the weapon and trail shops.", fs(), Colors.Muted, Enum.Font.Gotham)
		local button = UIKit.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, BH),
			TextSize = fs(),
			ZIndex = 13,
			Parent = card,
		})
		button.Activated:Connect(function()
			if Monetization.IsAvailable(product) then
				Remotes.Purchase:FireServer("Product", key)
			end
		end)
		table.insert(updaters, function()
			if Monetization.IsAvailable(product) then
				styleButton(button, ("R$ %d"):format(product.Robux), "level")
			else
				styleButton(button, "R$ Soon", "muted", false)
			end
		end)
	end

	showTab(activeTab)

	refreshers.Shop = function()
		local profile = Store.Profile
		if not profile then
			return
		end
		coins.Text = ("%d coins"):format(profile.Coins)
		for _, update in ipairs(updaters) do
			update()
		end
	end
end

local modalGui: GuiObject? = nil
local modalButton: TextButton? = nil

-- Every panel that can hold the mouse: Shop, Classes and Settings. The count
-- is derived from the Visible flags, so no close path can leave MenuOpen stuck.
local tracked: { Frame } = {}
local menuOpen = false
local syncQueued = false

-- A Modal button frees the mouse in first person and shift lock while a menu is open
local function syncNow()
	syncQueued = false
	local count = 0
	for _, panel in ipairs(tracked) do
		if panel.Visible then
			count += 1
		end
	end
	local anyOpen = count > 0
	if anyOpen ~= menuOpen then
		menuOpen = anyOpen
		Hud.SetMenuOpen(anyOpen)
	end
	if anyOpen and not modalButton and modalGui then
		modalButton = New("TextButton", {
			Name = "MenuModal",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			Modal = true,
			AutoButtonColor = false,
			ZIndex = 0,
			Parent = modalGui,
		})
	elseif not anyOpen and modalButton then
		modalButton:Destroy()
		modalButton = nil
	end
end

-- Coalesced, so closing one panel while opening another never flickers MenuOpen
local function syncModal()
	if syncQueued then
		return
	end
	syncQueued = true
	task.defer(syncNow)
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

function Menus.Init(gui: GuiObject, buttons: { [string]: TextButton })
	modalGui = gui
	buildClassMenu(gui)
	buildShop(gui)
	for _, panel in pairs(panels) do
		table.insert(tracked, panel)
	end
	local settingsPanel = gui:FindFirstChild("Settings")
	if settingsPanel and settingsPanel:IsA("Frame") then
		table.insert(tracked, settingsPanel)
	end
	for _, panel in ipairs(tracked) do
		panel:GetPropertyChangedSignal("Visible"):Connect(syncModal)
	end

	-- entering the game closes any shop, class or settings panel left open on the main menu
	Players.LocalPlayer:GetAttributeChangedSignal("InGame"):Connect(function()
		if Players.LocalPlayer:GetAttribute("InGame") == true then
			for _, panel in ipairs(tracked) do
				panel.Visible = false
			end
		end
	end)

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
