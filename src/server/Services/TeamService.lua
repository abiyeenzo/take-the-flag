local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Actors = require(script.Parent.Actors)

local TeamService = {}

local function smallestTeam(): Team
	local best, bestCount = nil, math.huge
	for _, team in ipairs(Teams:GetTeams()) do
		local count = Actors.CountOnTeam(team)
		if count < bestCount or (count == bestCount and math.random() < 0.5) then
			best, bestCount = team, count
		end
	end
	return best
end

function TeamService.SmallestTeam(): Team
	return smallestTeam()
end

function TeamService.Assign(player: Player)
	Actors.SetTeam(player, smallestTeam())
end

-- Reshuffles everybody (humans and bots) so teams are even and different from the last round.
function TeamService.Rebalance()
	local list = Actors.All()
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	local teams = Teams:GetTeams()
	local offset = math.random(0, #teams - 1)
	for i, actor in ipairs(list) do
		Actors.SetTeam(actor, teams[(i + offset) % #teams + 1])
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
end

return TeamService
