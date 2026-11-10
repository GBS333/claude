-- Script principal do servidor: liga todos os sistemas do jogo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Services = script.Parent:WaitForChild("Services")
local Remotes = require(Services.Remotes)
local DataService = require(Services.DataService)
local WorldBuilder = require(Services.WorldBuilder)
local TycoonService = require(Services.TycoonService)
local WildService = require(Services.WildService)
local ToolService = require(Services.ToolService)
local ShopService = require(Services.ShopService)

WorldBuilder.build()
TycoonService.start()
WildService.start()
ToolService.start()
ShopService.start()

local function onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	-- espera a mochila nova ser criada após o respawn
	player:WaitForChild("Backpack", 10)
	task.wait(0.2)
	if character.Parent == nil then
		return
	end
	ToolService.giveTools(player)
	TycoonService.teleportHome(player)
end

local function onPlayerAdded(player: Player)
	DataService.load(player)
	if player.Parent ~= Players then
		DataService.release(player)
		return
	end
	TycoonService.assign(player)
	DataService.pushUpdate(player)

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end

	Remotes.notify(player, "Bem-vindo! Pegue o 🏏 Taco, bata nos brainrots e use a ⚪ Bola quando estiverem com POUCA vida!", Color3.fromRGB(255, 230, 100))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	TycoonService.release(player)
	DataService.release(player)
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		task.wait(1)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		TycoonService.release(player)
		task.spawn(DataService.release, player)
	end
	task.wait(3)
end)
