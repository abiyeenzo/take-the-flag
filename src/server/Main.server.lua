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
local ShopService = require(Services.ShopService)
local ClassService = require(Services.ClassService)
local CombatService = require(Services.CombatService)
local FlagService = require(Services.FlagService)
local RoundService = require(Services.RoundService)

local mapInfo = MapBuilder.Build()

TeamService.Init()
DataService.Init()
ShopService.Init()
ClassService.Init()
CombatService.Init()
FlagService.Init(mapInfo)

RoundService.Run()
