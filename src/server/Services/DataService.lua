local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Monetization = require(ReplicatedStorage.Shared.Monetization)

local DataService = {}

-- fired with the player when VIP flips while they are alive; ShopService re-applies tool and trail
DataService.VipChanged = Instance.new("BindableEvent")

local DEFAULTS = {
	Coins = 0,
	XP = 0,
	Level = 1,
	Wins = 0,
	Captures = 0,
	Kills = 0,
	Class = Classes.Default,
	OwnedTrails = {},
	EquippedTrail = "",
	OwnedWeapons = { [Weapons.Default] = true },
	EquippedWeapon = Weapons.Default,
	Receipts = {},
}

local MAX_RECEIPTS = 200

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles: { [Player]: { Data: any, CanSave: boolean, Saving: boolean?, VIP: boolean?, VipChecked: number? } } = {}
local pendingSaves = 0
local VIP_RECHECK_INTERVAL = 300
local REQUEST_COOLDOWN = 0.3
local lastRequest: { [Player]: number } = {}

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function mergeDefaults(saved: any): any
	local data = {}
	for key, default in pairs(DEFAULTS) do
		if typeof(default) == "table" then
			data[key] = {}
			if typeof(saved) == "table" and typeof(saved[key]) == "table" then
				for k, v in pairs(saved[key]) do
					data[key][k] = v
				end
			end
		elseif typeof(saved) == "table" and typeof(saved[key]) == typeof(default) then
			data[key] = saved[key]
		else
			data[key] = default
		end
	end
	return data
end

local function isPlayer(x: any): boolean
	return typeof(x) == "Instance" and x:IsA("Player")
end

local function snapshot(profile: any)
	local data = profile.Data
	local vip = profile.VIP == true
	local owned = {}
	for id in pairs(data.OwnedTrails) do
		if not (vip and Cosmetics.ById[id] and Cosmetics.ById[id].VipOnly) then
			table.insert(owned, id)
		end
	end
	if vip then
		for _, trail in ipairs(Cosmetics.Trails) do
			if trail.VipOnly then
				table.insert(owned, trail.Id)
			end
		end
	end
	local ownedWeapons = {}
	for id in pairs(data.OwnedWeapons) do
		if Weapons.Defs[id] and not (vip and Weapons.Defs[id].VipOnly) then
			table.insert(ownedWeapons, id)
		end
	end
	if vip then
		for _, id in ipairs(Weapons.Order) do
			if Weapons.Defs[id].VipOnly then
				table.insert(ownedWeapons, id)
			end
		end
	end
	return {
		Coins = data.Coins,
		XP = data.XP,
		XpNeeded = Config.XpForLevel(data.Level),
		Level = data.Level,
		Wins = data.Wins,
		Captures = data.Captures,
		Kills = data.Kills,
		Class = data.Class,
		Owned = owned,
		Equipped = data.EquippedTrail,
		OwnedWeapons = ownedWeapons,
		EquippedWeapon = data.EquippedWeapon,
		VIP = vip,
	}
end

local function updateLeaderstats(player: Player, data: any)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	stats.Level.Value = data.Level
	stats.Captures.Value = data.Captures
	stats.Kills.Value = data.Kills
end

local function makeLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in ipairs({ "Level", "Captures", "Kills" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
end

local function save(player: Player, final: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave then
		return false
	end
	if profile.Saving then
		if not final then
			return false
		end
		-- an autosave is in flight: let it finish, then write the latest data
		while profile.Saving do
			task.wait()
		end
	end
	profile.Saving = true
	pendingSaves += 1
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return profile.Data
		end)
	end)
	profile.Saving = false
	pendingSaves -= 1
	if not ok then
		warn("[TakeTheFlag] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

local function load(player: Player)
	local data, canSave = nil, false
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			data, canSave = mergeDefaults(result), true
			break
		end
		if attempt < 3 then
			task.wait(0.5 * attempt)
		end
	end
	if not data then
		-- Studio without API access, or Roblox outage: play with a temporary profile.
		data = mergeDefaults(nil)
	end
	if not Classes.Defs[data.Class] or data.Level < Classes.Defs[data.Class].Level then
		data.Class = Classes.Default
	end
	if not player.Parent then
		return
	end
	if not Weapons.Defs[data.EquippedWeapon] then
		data.EquippedWeapon = Weapons.Default
	end
	data.OwnedWeapons[Weapons.Default] = true
	-- the aurora and golden blaster are VIP perks, never stored as owned
	for id in pairs(data.OwnedWeapons) do
		if not Weapons.Defs[id] or Weapons.Defs[id].VipOnly then
			data.OwnedWeapons[id] = nil
		end
	end
	local profile = { Data = data, CanSave = canSave, VIP = false }
	profiles[player] = profile
	makeLeaderstats(player)
	player:SetAttribute("Class", data.Class)
	updateLeaderstats(player, data)
	DataService.Push(player)
	task.spawn(DataService.RecheckVIP, player, true)
	if not canSave and not RunService:IsStudio() then
		Remotes.Toast:FireClient(player, "Data service unavailable: progress will not be saved this session", "bad")
	end
end

-- Asks Roblox whether the VIP pass is owned (at most once per 5 minutes unless forced),
-- so a pass bought on the website or refunded is picked up.
function DataService.RecheckVIP(player: Player, force: boolean?)
	local profile = profiles[player]
	local passId = Monetization.GamePasses.VIP.Id
	if not profile or passId == 0 then
		return
	end
	local now = os.clock()
	if not force and profile.VipChecked and now - profile.VipChecked < VIP_RECHECK_INTERVAL then
		return
	end
	profile.VipChecked = now
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and profiles[player] == profile and (owns == true) ~= (profile.VIP == true) then
		DataService.SetVIP(player, owns == true)
	end
end

function DataService.Get(player: any): any?
	if not isPlayer(player) then
		return nil
	end
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.Push(player: any)
	if not isPlayer(player) then
		return
	end
	local profile = profiles[player]
	if profile then
		updateLeaderstats(player, profile.Data)
		Remotes.Profile:FireClient(player, snapshot(profile))
	end
end

function DataService.IsVIP(player: any): boolean
	if not isPlayer(player) then
		return false
	end
	local profile = profiles[player]
	return profile ~= nil and profile.VIP == true
end

function DataService.SetVIP(player: any, value: boolean)
	if not isPlayer(player) then
		return
	end
	local profile = profiles[player]
	if profile then
		local changed = profile.VIP ~= value
		profile.VIP = value
		player:SetAttribute("VIP", value)
		DataService.Push(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if changed and humanoid and humanoid.Health > 0 then
			-- VIP resolves asynchronously: refresh the weapon and trail of the living character
			DataService.VipChanged:Fire(player)
		end
	end
end

-- Owned either through purchase or through VIP
function DataService.OwnsWeapon(player: any, id: string): boolean
	local data = DataService.Get(player)
	local def = Weapons.Defs[id]
	if not data or not def then
		return false
	end
	if def.VipOnly then
		return DataService.IsVIP(player)
	end
	return def.CoinPrice == nil and def.RobuxKey == nil or data.OwnedWeapons[id] == true
end

function DataService.OwnsTrail(player: any, id: string): boolean
	local data = DataService.Get(player)
	local def = Cosmetics.ById[id]
	if not data or not def then
		return false
	end
	if def.VipOnly then
		return DataService.IsVIP(player)
	end
	return data.OwnedTrails[id] == true
end

-- Records a purchase id. Returns false if it was already recorded.
function DataService.AddReceipt(player: any, purchaseId: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	for _, id in ipairs(data.Receipts) do
		if id == purchaseId then
			return false
		end
	end
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	return true
end

function DataService.HasReceipt(player: any, purchaseId: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	return table.find(data.Receipts, purchaseId) ~= nil
end

function DataService.SaveNow(player: any): boolean
	if not isPlayer(player) then
		return false
	end
	return save(player, true)
end

function DataService.AddCoins(player: any, amount: number, noBoost: boolean?)
	local data = DataService.Get(player)
	if data then
		if amount > 0 and not noBoost and DataService.IsVIP(player) then
			amount = math.floor(amount * Config.VipCoinMultiplier + 0.5)
		end
		data.Coins = math.max(0, data.Coins + amount)
		DataService.Push(player)
	end
end

function DataService.AddXP(player: any, amount: number, noBoost: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if amount > 0 and not noBoost and DataService.IsVIP(player) then
		amount = math.floor(amount * Config.VipXpMultiplier + 0.5)
	end
	data.XP += amount
	while data.Level < Config.MaxLevel and data.XP >= Config.XpForLevel(data.Level) do
		data.XP -= Config.XpForLevel(data.Level)
		data.Level += 1
		Remotes.Toast:FireClient(player, "Level up! You are now level " .. data.Level, "level")
		for _, def in pairs(Classes.Defs) do
			if def.Level == data.Level then
				Remotes.Toast:FireClient(player, def.Name .. " class unlocked!", "level")
			end
		end
	end
	if data.Level >= Config.MaxLevel then
		data.XP = 0
	end
	DataService.Push(player)
end

function DataService.Increment(player: any, stat: string, amount: number)
	local data = DataService.Get(player)
	if data and typeof(data[stat]) == "number" then
		data[stat] += amount
		DataService.Push(player)
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end

	local function hookVip(player: Player)
		player.CharacterAdded:Connect(function()
			DataService.RecheckVIP(player)
		end)
	end
	Players.PlayerAdded:Connect(hookVip)
	for _, player in ipairs(Players:GetPlayers()) do
		hookVip(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
		lastRequest[player] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(save, player, true)
		end
		local waited = 0
		while pendingSaves > 0 and waited < 25 do
			task.wait(0.25)
			waited += 0.25
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(save, player)
			end
		end
	end)

	Remotes.RequestProfile.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
			return
		end
		lastRequest[player] = now
		DataService.Push(player)
	end)
end

return DataService
