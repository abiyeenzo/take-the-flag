local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Actors = require(script.Parent.Actors)
local BotService = require(script.Parent.BotService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local FlagService = require(script.Parent.FlagService)
local MapBuilder = require(script.Parent.MapBuilder)
local TeamService = require(script.Parent.TeamService)

local RoundService = {}

type Stats = { Name: string, Captures: number, Kills: number, Returns: number }

local scores = { Red = 0, Blue = 0 }
local stats: { [number]: Stats } = {}
local streaks: { [any]: number } = {}
local winner: string? = nil
local overtime = false
local participants: { [number]: boolean } = {}

local function setState(state: string, duration: number?)
	Workspace:SetAttribute("RoundState", state)
	Workspace:SetAttribute("TimerEnd", duration and (Workspace:GetServerTimeNow() + duration) or 0)
end

local function announce(text: string, team: string?)
	Remotes.Announce:FireAllClients(text, team)
end

local function humanCount(): number
	return #Actors.Humans()
end

local function statsOf(actor: any): Stats
	local entry = stats[actor.UserId]
	if not entry then
		entry = { Name = actor.Name, Captures = 0, Kills = 0, Returns = 0 }
		stats[actor.UserId] = entry
	end
	return entry
end

-- Coins and XP are only for humans. Bots earn nothing.
local function reward(actor: any, kind: string, label: string)
	if Actors.IsBot(actor) then
		return
	end
	local amount = Config.Rewards[kind]
	DataService.AddCoins(actor, amount.Coins)
	DataService.AddXP(actor, amount.XP)
	Remotes.Toast:FireClient(actor, ("+%d coins  %s"):format(amount.Coins, label), "good")
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
	FlagService.PickedUp.Event:Connect(function(actor: any, flagTeam: string)
		if isPlaying() then
			announce(actor.Name .. " grabbed the " .. flagTeam .. " flag!", Actors.TeamName(actor))
		end
	end)

	FlagService.Dropped.Event:Connect(function(actor: any, flagTeam: string)
		if isPlaying() then
			announce(actor.Name .. " dropped the " .. flagTeam .. " flag", nil)
		end
	end)

	FlagService.Returned.Event:Connect(function(actor: any, flagTeam: string)
		if not isPlaying() then
			return
		end
		if actor then
			statsOf(actor).Returns += 1
			reward(actor, "Return", "Flag returned")
			announce(actor.Name .. " returned the " .. flagTeam .. " flag", flagTeam)
		else
			announce("The " .. flagTeam .. " flag is back at base", flagTeam)
		end
	end)

	FlagService.Captured.Event:Connect(function(actor: any, flagTeam: string)
		if not isPlaying() or winner then
			return
		end
		local team = Actors.TeamName(actor)
		if not team then
			return
		end
		scores[team] += 1
		Workspace:SetAttribute(team .. "Score", scores[team])
		statsOf(actor).Captures += 1
		if not Actors.IsBot(actor) then
			DataService.Increment(actor, "Captures", 1)
		end
		reward(actor, "Capture", "Flag captured")
		announce(actor.Name .. " captured the " .. flagTeam .. " flag!", team)

		if scores[team] >= Config.CapsToWin or overtime then
			winner = team
		end
	end)

	CombatService.Killed.Event:Connect(function(killer: any, victim: any)
		streaks[victim] = 0
		if not killer or not isPlaying() then
			return
		end
		statsOf(killer).Kills += 1
		if not Actors.IsBot(killer) then
			DataService.Increment(killer, "Kills", 1)
		end
		reward(killer, Actors.IsBot(victim) and "BotKill" or "Kill", "Eliminated " .. victim.Name)

		streaks[killer] = (streaks[killer] or 0) + 1
		local streak = streaks[killer]
		if streak >= 3 and streak % 2 == 1 then
			if not Actors.IsBot(killer) then
				local bonus = Config.Rewards.StreakBonus
				local steps = math.min(streak, 5)
				DataService.AddCoins(killer, bonus.Coins * steps)
				DataService.AddXP(killer, bonus.XP * steps)
			end
			announce(killer.Name .. " is on a " .. streak .. " tag streak!", Actors.TeamName(killer))
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

local function setSign(text: string)
	MapBuilder.SetLobbySign(text)
end

local function formatClock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function loadHumans()
	for _, player in ipairs(Actors.Humans()) do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

-- Runs the 3,2,1 countdown. Returns false if everybody left.
local function countdown(): boolean
	for n = Config.CountdownSeconds, 1, -1 do
		Remotes.Countdown:FireAllClients(n)
		setSign("Starting in " .. n)
		task.wait(1)
		if humanCount() == 0 then
			return false
		end
	end
	return true
end

local function playRound()
	resetScores()
	setSign("Go!")
	Remotes.Countdown:FireAllClients("GO")
	Remotes.Flash:FireAllClients()

	-- Playing is set before respawning so characters appear at their team base
	setState("Playing", Config.RoundTime)
	local deadline = os.clock() + Config.RoundTime

	TeamService.Rebalance()
	FlagService.Reset()
	participants = {}
	for _, actor in ipairs(Actors.All()) do
		participants[actor.UserId] = true
	end
	loadHumans()
	BotService.EnterArena()
	task.wait(1)

	FlagService.Active = true
	setSign("Match in progress")
	announce("Round start! First team to " .. Config.CapsToWin .. " captures wins", nil)

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
		if humanCount() == 0 then
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

	for _, player in ipairs(Actors.Humans()) do
		-- only players who were there at the start and actually did something earn the bonuses
		local entry = stats[player.UserId]
		local active = entry ~= nil and (entry.Captures + entry.Kills + entry.Returns) > 0
		if participants[player.UserId] and active then
			reward(player, "Play", "Match played")
			if Actors.TeamName(player) == result then
				DataService.Increment(player, "Wins", 1)
				reward(player, "Win", "Victory")
			end
		end
	end

	local mvpName, mvpScore = bestPlayer()
	setState("Ended", Config.EndScreenTime)
	setSign("Great match!")
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

	-- back to the lobby: humans respawn there, bots gather too
	setState("Intermission", Config.IntermissionTime)
	loadHumans()
	BotService.Sync()
	BotService.GatherInLobby()
end

function RoundService.Run()
	connectEvents()
	Workspace:SetAttribute("CapsToWin", Config.CapsToWin)
	Workspace:SetAttribute("RedScore", 0)
	Workspace:SetAttribute("BlueScore", 0)

	while true do
		if humanCount() < math.max(1, Config.MinPlayers) then
			setState("Waiting")
			setSign("Waiting for players")
			BotService.RemoveAll()
			while humanCount() < math.max(1, Config.MinPlayers) do
				task.wait(1)
			end
		end

		if Workspace:GetAttribute("RoundState") ~= "Intermission" then
			setState("Intermission", Config.IntermissionTime)
			BotService.Sync()
			BotService.GatherInLobby()
		end

		local timerEnd = Workspace:GetAttribute("TimerEnd") or 0
		while Workspace:GetServerTimeNow() < timerEnd and humanCount() >= Config.MinPlayers do
			setSign("Match starts in " .. formatClock(timerEnd - Workspace:GetServerTimeNow()))
			task.wait(0.5)
		end

		if humanCount() >= Config.MinPlayers and countdown() then
			playRound()
		elseif humanCount() < Config.MinPlayers then
			Workspace:SetAttribute("RoundState", "Waiting")
		end
	end
end

return RoundService
