-- An actor is a Player or a Bot table. Gameplay code talks to actors so bots and
-- humans behave the same way. Bots use negative user ids and are never saved.
local Players = game:GetService("Players")

local Actors = {}

export type Actor = any

local bots: { [number]: any } = {}
local botOrder: { any } = {}

function Actors.IsBot(actor: Actor): boolean
	return type(actor) == "table" and actor.IsBot == true
end

function Actors.RegisterBot(bot: any)
	if bots[bot.UserId] then
		return
	end
	bots[bot.UserId] = bot
	table.insert(botOrder, bot)
end

function Actors.UnregisterBot(bot: any)
	bots[bot.UserId] = nil
	local index = table.find(botOrder, bot)
	if index then
		table.remove(botOrder, index)
	end
end

function Actors.BotList(): { any }
	return table.clone(botOrder)
end

-- Only players who pressed Play (InGame) take part in matches. Players sitting on the
-- main menu are connected but are not counted for teams, bots, rounds or rewards.
function Actors.Humans(): { Player }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("InGame") == true then
			table.insert(list, player)
		end
	end
	return list
end

function Actors.All(): { Actor }
	local list: { Actor } = {}
	for _, player in ipairs(Actors.Humans()) do
		table.insert(list, player)
	end
	for _, bot in ipairs(botOrder) do
		table.insert(list, bot)
	end
	return list
end

function Actors.FromCharacter(model: Instance?): Actor?
	if not model then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return player
	end
	for _, bot in ipairs(botOrder) do
		if bot.Character == model then
			return bot
		end
	end
	return nil
end

function Actors.ByUserId(id: number): Actor?
	local bot = bots[id]
	if bot then
		return bot
	end
	return Players:GetPlayerByUserId(id)
end

function Actors.TeamName(actor: Actor): string?
	local team = actor and actor.Team
	return team and team.Name or nil
end

function Actors.SetTeam(actor: Actor, team: Team)
	actor.Team = team
	if Actors.IsBot(actor) then
		local character = actor.Character
		if character then
			character:SetAttribute("TeamName", team.Name)
		end
	end
end

function Actors.CountOnTeam(team: Team): number
	local count = #team:GetPlayers()
	for _, bot in ipairs(botOrder) do
		if bot.Team == team then
			count += 1
		end
	end
	return count
end

return Actors
