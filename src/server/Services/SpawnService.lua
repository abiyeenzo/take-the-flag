-- Controls when a player's character exists. Players join on the main menu (InGame = false),
-- press Play to enter, and can go back to the menu from the settings panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BotService = require(script.Parent.BotService)
local FlagService = require(script.Parent.FlagService)
local TeamService = require(script.Parent.TeamService)

local SpawnService = {}

local lastEnter: { [Player]: number } = {}
local lastLeave: { [Player]: number } = {}

local function throttled(log: { [Player]: number }, player: Player): boolean
	local now = os.clock()
	if log[player] and now - log[player] < 1 then
		return true
	end
	log[player] = now
	return false
end

local function resyncBots()
	task.spawn(function()
		pcall(BotService.Sync)
	end)
end

function SpawnService.IsInGame(player: Player): boolean
	return player:GetAttribute("InGame") == true
end

function SpawnService.Enter(player: Player)
	if SpawnService.IsInGame(player) or not player.Parent then
		return
	end
	player:SetAttribute("InGame", true)
	TeamService.Assign(player)
	task.spawn(function()
		(player :: any):LoadCharacter()
	end)
	resyncBots()
end

function SpawnService.Leave(player: Player)
	if not SpawnService.IsInGame(player) then
		return
	end
	FlagService.DropIfCarrying(player)
	player:SetAttribute("InGame", false)
	local untyped: any = player
	untyped.Team = nil
	local character = player.Character
	if character then
		character:Destroy()
	end
	resyncBots()
end

local function watchRespawn(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			task.delay(Config.RespawnTime, function()
				-- skip if the player left the game or already has a newer character
				if player.Parent and SpawnService.IsInGame(player) and player.Character == character then
					(player :: any):LoadCharacter()
				end
			end)
		end)
	end)
end

function SpawnService.Init()
	Remotes.EnterGame.OnServerEvent:Connect(function(player)
		if not throttled(lastEnter, player) then
			SpawnService.Enter(player)
		end
	end)
	Remotes.LeaveToMenu.OnServerEvent:Connect(function(player)
		if not throttled(lastLeave, player) then
			SpawnService.Leave(player)
		end
	end)

	local function hook(player: Player)
		if player:GetAttribute("InGame") == nil then
			player:SetAttribute("InGame", false)
		end
		watchRespawn(player)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastEnter[player] = nil
		lastLeave[player] = nil
	end)
end

return SpawnService
