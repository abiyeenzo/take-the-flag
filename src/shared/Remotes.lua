-- Server creates every remote at require time, the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Fire", -- client -> server: aim point
	"ShotFx", -- server -> clients: origin, endpoint, color
	"HitMarker", -- server -> shooter: headshot, killed
	"Announce", -- server -> clients: feed message, team name
	"Toast", -- server -> client: private message, kind
	"RoundEnd", -- server -> clients: result table
	"Profile", -- server -> client: profile snapshot
	"RequestProfile", -- client -> server
	"SelectClass", -- client -> server: class id
	"UseAbility", -- client -> server
	"AbilityFx", -- server -> client: effect name
	"ShopAction", -- client -> server: action, id (Buy, Equip, BuyWeapon, EquipWeapon)
	"Purchase", -- client -> server: kind ("Pass" or "Product"), key from Monetization
	"Countdown", -- server -> clients: number (3,2,1) or "GO"
	"Flash", -- server -> clients: white screen flash when entering the arena
	"EnterGame", -- client -> server: the player pressed Play on the main menu
	"LeaveToMenu", -- client -> server: the player goes back to the main menu
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in ipairs(EVENTS) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

return folder
