local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = {}

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
}

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles: { [Player]: { Data: any, CanSave: boolean, Saving: boolean? } } = {}
local pendingSaves = 0

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

local function snapshot(data: any)
	local owned = {}
	for id in pairs(data.OwnedTrails) do
		table.insert(owned, id)
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

local function save(player: Player, final: boolean?)
	local profile = profiles[player]
	if not profile or not profile.CanSave then
		return
	end
	if profile.Saving then
		if not final then
			return
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
	profiles[player] = { Data = data, CanSave = canSave }
	makeLeaderstats(player)
	player:SetAttribute("Class", data.Class)
	updateLeaderstats(player, data)
	DataService.Push(player)
	if not canSave and not RunService:IsStudio() then
		Remotes.Toast:FireClient(player, "Data service unavailable: progress will not be saved this session", "bad")
	end
end

function DataService.Get(player: Player): any?
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.Push(player: Player)
	local data = DataService.Get(player)
	if data then
		updateLeaderstats(player, data)
		Remotes.Profile:FireClient(player, snapshot(data))
	end
end

function DataService.AddCoins(player: Player, amount: number)
	local data = DataService.Get(player)
	if data then
		data.Coins = math.max(0, data.Coins + amount)
		DataService.Push(player)
	end
end

function DataService.AddXP(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
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

function DataService.Increment(player: Player, stat: string, amount: number)
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

	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
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
		DataService.Push(player)
	end)
end

return DataService
