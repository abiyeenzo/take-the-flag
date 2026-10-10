local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TeamService = {}

local function smallestTeam(): Team
	local best, bestCount = nil, math.huge
	for _, team in ipairs(Teams:GetTeams()) do
		local count = #team:GetPlayers()
		if count < bestCount or (count == bestCount and math.random() < 0.5) then
			best, bestCount = team, count
		end
	end
	return best
end

function TeamService.Assign(player: Player)
	player.Team = smallestTeam()
end

-- Reshuffles everybody so teams are even and different from the last round.
function TeamService.Rebalance()
	local list = Players:GetPlayers()
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	local teams = Teams:GetTeams()
	local offset = math.random(0, #teams - 1)
	for i, player in ipairs(list) do
		player.Team = teams[(i + offset) % #teams + 1]
	end
end

function TeamService.Init()
	for _, def in ipairs(Config.Teams) do
		local team = Instance.new("Team")
		team.Name = def.Name
		team.TeamColor = def.BrickColor
		team.AutoAssignable = false
		team.Parent = Teams
	end

	Players.PlayerAdded:Connect(TeamService.Assign)
	for _, player in ipairs(Players:GetPlayers()) do
		TeamService.Assign(player)
	end
end

return TeamService
