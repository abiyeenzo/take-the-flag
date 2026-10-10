-- Client side copy of the player's profile, updated by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Store = {}

Store.Profile = nil :: any
Store.Changed = Instance.new("BindableEvent")

function Store.Owns(id: string): boolean
	if Store.Profile then
		for _, owned in ipairs(Store.Profile.Owned) do
			if owned == id then
				return true
			end
		end
	end
	return false
end

function Store.Init()
	Remotes:WaitForChild("Profile").OnClientEvent:Connect(function(profile)
		Store.Profile = profile
		Store.Changed:Fire(profile)
	end)
	Remotes:WaitForChild("RequestProfile"):FireServer()
end

return Store
