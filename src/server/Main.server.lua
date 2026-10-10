local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Services = script.Parent.Services

pcall(function()
	Players.RespawnTime = Config.RespawnTime
end)

local MapBuilder = require(Services.MapBuilder)
local TeamService = require(Services.TeamService)
local DataService = require(Services.DataService)
local MonetizationService = require(Services.MonetizationService)
local ShopService = require(Services.ShopService)
local ClassService = require(Services.ClassService)
local CombatService = require(Services.CombatService)
local FlagService = require(Services.FlagService)
local BotService = require(Services.BotService)
local RoundService = require(Services.RoundService)

local mapInfo = MapBuilder.Build()

TeamService.Init()
DataService.Init()
MonetizationService.Init()
ShopService.Init()
ClassService.Init()
CombatService.Init()
FlagService.Init(mapInfo)
BotService.Init()

RoundService.Run()
