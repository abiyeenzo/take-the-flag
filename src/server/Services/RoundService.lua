local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local FlagService = require(script.Parent.FlagService)
local TeamService = require(script.Parent.TeamService)

local RoundService = {}

type Stats = { Name: string, Captures: number, Kills: number, Returns: number }

local scores = { Red = 0, Blue = 0 }
local stats: { [number]: Stats } = {}
local streaks: { [Player]: number } = {}
local winner: string? = nil
local overtime = false

local function setState(state: string, duration: number?)
	Workspace:SetAttribute("RoundState", state)
	Workspace:SetAttribute("TimerEnd", duration and (Workspace:GetServerTimeNow() + duration) or 0)
end

local function announce(text: string, team: string?)
	Remotes.Announce:FireAllClients(text, team)
end

local function statsOf(player: Player): Stats
	local entry = stats[player.UserId]
	if not entry then
		entry = { Name = player.Name, Captures = 0, Kills = 0, Returns = 0 }
		stats[player.UserId] = entry
	end
	return entry
end

local function reward(player: Player, kind: string, label: string)
	local amount = Config.Rewards[kind]
	DataService.AddCoins(player, amount.Coins)
	DataService.AddXP(player, amount.XP)
	Remotes.Toast:FireClient(player, ("+%d coins  %s"):format(amount.Coins, label), "good")
end

local function resetScores()
	scores.Red, scores.Blue = 0, 0
	Workspace:SetAttribute("RedScore", 0)
	Workspace:SetAttribute("BlueScore", 0)
	Workspace:SetAttribute("CapsToWin", Config.CapsToWin)
	Workspace:SetAttribute("Overtime", false)
	stats = {}
	streaks = {}
	winner = nil
	overtime = false
end

local function isPlaying(): boolean
	return Workspace:GetAttribute("RoundState") == "Playing"
end

local function connectEvents()
	FlagService.PickedUp.Event:Connect(function(player: Player, flagTeam: string)
		if isPlaying() then
			announce(player.Name .. " grabbed the " .. flagTeam .. " flag!", player.Team and player.Team.Name)
		end
	end)

	FlagService.Dropped.Event:Connect(function(player: Player, flagTeam: string)
		if isPlaying() then
			announce(player.Name .. " dropped the " .. flagTeam .. " flag", nil)
		end
	end)

	FlagService.Returned.Event:Connect(function(player: Player?, flagTeam: string)
		if not isPlaying() then
			return
		end
		if player then
			statsOf(player).Returns += 1
			reward(player, "Return", "Flag returned")
			announce(player.Name .. " returned the " .. flagTeam .. " flag", flagTeam)
		else
			announce("The " .. flagTeam .. " flag is back at base", flagTeam)
		end
	end)

	FlagService.Captured.Event:Connect(function(player: Player, flagTeam: string)
		if not isPlaying() or winner then
			return
		end
		local team = player.Team and player.Team.Name
		if not team then
			return
		end
		scores[team] += 1
		Workspace:SetAttribute(team .. "Score", scores[team])
		statsOf(player).Captures += 1
		DataService.Increment(player, "Captures", 1)
		reward(player, "Capture", "Flag captured")
		announce(player.Name .. " captured the " .. flagTeam .. " flag!", team)

		if scores[team] >= Config.CapsToWin or overtime then
			winner = team
		end
	end)

	CombatService.Killed.Event:Connect(function(killer: Player?, victim: Player)
		streaks[victim] = 0
		if not killer or not isPlaying() then
			return
		end
		statsOf(killer).Kills += 1
		DataService.Increment(killer, "Kills", 1)
		reward(killer, "Kill", "Eliminated " .. victim.Name)

		streaks[killer] = (streaks[killer] or 0) + 1
		local streak = streaks[killer]
		if streak >= 3 and streak % 2 == 1 then
			local bonus = Config.Rewards.StreakBonus
			DataService.AddCoins(killer, bonus.Coins * streak)
			DataService.AddXP(killer, bonus.XP * streak)
			announce(killer.Name .. " is on a " .. streak .. " kill streak!", killer.Team and killer.Team.Name)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		streaks[player] = nil
	end)
end

local function bestPlayer(): (string?, number)
	local bestName, bestScore = nil, 0
	for _, entry in pairs(stats) do
		local score = entry.Captures * 5 + entry.Returns * 2 + entry.Kills
		if score > bestScore then
			bestName, bestScore = entry.Name, score
		end
	end
	return bestName, bestScore
end

local function playRound()
	resetScores()
	TeamService.Rebalance()
	FlagService.Reset()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
	task.wait(1)

	FlagService.Active = true
	setState("Playing", Config.RoundTime)
	announce("Round start! First team to " .. Config.CapsToWin .. " captures wins", nil)

	local deadline = os.clock() + Config.RoundTime
	while not winner do
		if os.clock() >= deadline then
			if not overtime and scores.Red == scores.Blue then
				overtime = true
				deadline = os.clock() + Config.OvertimeTime
				Workspace:SetAttribute("Overtime", true)
				setState("Playing", Config.OvertimeTime)
				announce("OVERTIME! The next capture wins the match", nil)
			else
				break
			end
		end
		if #Players:GetPlayers() == 0 then
			break
		end
		task.wait(0.25)
	end

	FlagService.Active = false
	local result = winner
	if not result then
		if scores.Red > scores.Blue then
			result = "Red"
		elseif scores.Blue > scores.Red then
			result = "Blue"
		else
			result = "Draw"
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if stats[player.UserId] or player.Team then
			reward(player, "Play", "Match played")
			if player.Team and player.Team.Name == result then
				DataService.Increment(player, "Wins", 1)
				reward(player, "Win", "Victory")
			end
		end
	end

	local mvpName, mvpScore = bestPlayer()
	setState("Ended", Config.EndScreenTime)
	Remotes.RoundEnd:FireAllClients({
		Winner = result,
		Red = scores.Red,
		Blue = scores.Blue,
		MVP = mvpName,
		MVPScore = mvpScore,
		Duration = Config.EndScreenTime,
	})
	task.wait(Config.EndScreenTime)
	FlagService.Reset()
end

function RoundService.Run()
	connectEvents()
	Workspace:SetAttribute("CapsToWin", Config.CapsToWin)
	Workspace:SetAttribute("RedScore", 0)
	Workspace:SetAttribute("BlueScore", 0)

	while true do
		setState("Waiting")
		while #Players:GetPlayers() < Config.MinPlayers do
			task.wait(1)
		end

		setState("Intermission", Config.IntermissionTime)
		local endsAt = os.clock() + Config.IntermissionTime
		while os.clock() < endsAt and #Players:GetPlayers() >= Config.MinPlayers do
			task.wait(0.5)
		end

		if #Players:GetPlayers() >= Config.MinPlayers then
			playRound()
		end
	end
end

return RoundService
