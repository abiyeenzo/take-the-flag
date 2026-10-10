local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Monetization)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

local lastPrompt: { [Player]: number } = {}
local warnedUnknown: { [number]: boolean } = {}

local function findProduct(productId: number): (string?, any?)
	for key, entry in pairs(Monetization.Products) do
		if entry.Id ~= 0 and entry.Id == productId then
			return key, entry
		end
	end
	return nil, nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(info.PurchaseId)
	if DataService.HasReceipt(player, purchaseId) then
		-- already granted: only confirm once the grant is safely stored
		if DataService.SaveNow(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local _, entry = findProduct(info.ProductId)
	if not entry then
		if not warnedUnknown[info.ProductId] then
			warnedUnknown[info.ProductId] = true
			warn("[TakeTheFlag] unknown developer product " .. tostring(info.ProductId))
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local weaponDef = entry.Weapon and Weapons.Defs[entry.Weapon]
	if not entry.Coins and not weaponDef then
		-- misconfigured product: never record a receipt for something we cannot grant
		warn("[TakeTheFlag] product " .. tostring(info.ProductId) .. " has no valid reward")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService.AddReceipt(player, purchaseId)
	if entry.Coins then
		-- purchased coins are never boosted
		DataService.AddCoins(player, entry.Coins, true)
		Remotes.Toast:FireClient(player, entry.Name .. " added!", "good")
	else
		data.OwnedWeapons[entry.Weapon] = true
		DataService.Push(player)
		Remotes.Toast:FireClient(player, weaponDef.Name .. " unlocked!", "good")
	end

	if DataService.SaveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function grantVip(player: Player)
	if DataService.IsVIP(player) then
		return
	end
	DataService.SetVIP(player, true)
	Remotes.Toast:FireClient(player, "VIP unlocked! Double coins and the Golden Blaster are yours", "good")
end

local function onPurchaseRequest(player: Player, kind: any, key: any)
	if typeof(kind) ~= "string" or typeof(key) ~= "string" or #key > 40 then
		return
	end
	local now = os.clock()
	if lastPrompt[player] and now - lastPrompt[player] < 1 then
		return
	end
	lastPrompt[player] = now
	if not DataService.Get(player) then
		return
	end

	if kind == "Product" then
		local entry = Monetization.Products[key]
		if not entry then
			return
		end
		if entry.Id == 0 then
			Remotes.Toast:FireClient(player, "Not available yet", "bad")
			return
		end
		if entry.Weapon and DataService.OwnsWeapon(player, entry.Weapon) then
			Remotes.Toast:FireClient(player, "You already own this weapon", "good")
			return
		end
		MarketplaceService:PromptProductPurchase(player, entry.Id)
	elseif kind == "Pass" then
		local entry = Monetization.GamePasses[key]
		if not entry then
			return
		end
		if entry.Id == 0 then
			Remotes.Toast:FireClient(player, "Not available yet", "bad")
			return
		end
		if key == "VIP" and DataService.IsVIP(player) then
			Remotes.Toast:FireClient(player, "You already have VIP", "good")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, entry.Id)
	end
end

local function validateProducts()
	for key, entry in pairs(Monetization.Products) do
		if entry.Weapon then
			if not Weapons.Defs[entry.Weapon] then
				warn("[TakeTheFlag] product " .. key .. " references unknown weapon " .. tostring(entry.Weapon))
			end
		elseif not entry.Coins or entry.Coins <= 0 then
			warn("[TakeTheFlag] product " .. key .. " has no valid weapon or coin amount")
		end
	end
end

function MonetizationService.Init()
	validateProducts()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		if not wasPurchased then
			return
		end
		local vip = Monetization.GamePasses.VIP
		if vip.Id ~= 0 and passId == vip.Id then
			grantVip(player)
		end
	end)

	Remotes.Purchase.OnServerEvent:Connect(onPurchaseRequest)

	Players.PlayerRemoving:Connect(function(player)
		lastPrompt[player] = nil
	end)
end

return MonetizationService
