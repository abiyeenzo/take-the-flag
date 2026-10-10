local Config = {
	MinPlayers = 1,
	IntermissionTime = 20,
	RoundTime = 300,
	OvertimeTime = 60,
	EndScreenTime = 9,
	CapsToWin = 3,

	FlagAutoReturnTime = 12,
	CarrierSpeedFactor = 0.85,
	RequireOwnFlagHome = true,

	RespawnTime = 4,
	SpawnProtection = 3,
	ShotRange = 400,
	HeadshotMultiplier = 1.5,
	KillAssistWindow = 5,

	MaxLevel = 50,
	AutosaveInterval = 120,
	DataStoreName = "TakeTheFlag_v1",

	-- Bots fill the match so nobody plays alone. Total actors (humans + bots) aimed for.
	BotTargetPlayers = 8,
	CountdownSeconds = 3,
	LobbyCenter = Vector3.new(0, 0, 420),

	VipCoinMultiplier = 2,
	VipXpMultiplier = 1.25,

	-- Arena dimensions in studs
	ArenaLength = 240,
	ArenaWidth = 130,
	BaseOffset = 100,

	Teams = {
		{ Name = "Red", BrickColor = BrickColor.new("Bright red"), Color = Color3.fromRGB(255, 72, 84) },
		{ Name = "Blue", BrickColor = BrickColor.new("Bright blue"), Color = Color3.fromRGB(62, 142, 255) },
	},

	-- coins and xp granted for each action
	Rewards = {
		Capture = { Coins = 50, XP = 80 },
		Kill = { Coins = 10, XP = 15 },
		BotKill = { Coins = 5, XP = 8 },
		Return = { Coins = 15, XP = 25 },
		Win = { Coins = 100, XP = 120 },
		Play = { Coins = 20, XP = 30 },
		StreakBonus = { Coins = 5, XP = 5 },
	},
}

function Config.XpForLevel(level: number): number
	return 100 + (level - 1) * 75
end

function Config.TeamColor(teamName: string): Color3
	for _, def in ipairs(Config.Teams) do
		if def.Name == teamName then
			return def.Color
		end
	end
	return Color3.fromRGB(255, 255, 255)
end

return Config
