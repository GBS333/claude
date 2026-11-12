-- Script principal do servidor: liga todos os sistemas do jogo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Services = script.Parent:WaitForChild("Services")
local Remotes = require(Services.Remotes)
local DataService = require(Services.DataService)
local WorldBuilder = require(Services.WorldBuilder)
local TycoonService = require(Services.TycoonService)
local WildService = require(Services.WildService)
local EventService = require(Services.EventService)
local ProgressService = require(Services.ProgressService)
local CompanionService = require(Services.CompanionService)
local StealService = require(Services.StealService)
local ToolService = require(Services.ToolService)
local InventoryService = require(Services.InventoryService)
local TradeService = require(Services.TradeService)
local DuelService = require(Services.DuelService)
local ShopService = require(Services.ShopService)

WorldBuilder.build()
TycoonService.start()
WorldBuilder.applyStyle(workspace:WaitForChild("Plots")) -- bases no mesmo estilo do mapa
WildService.start()
EventService.start()
ProgressService.start()
CompanionService.start()
StealService.start()
ToolService.start()
InventoryService.start()
TradeService.start()
DuelService.start()
ShopService.start()

---------------------------------------------------------------------
-- Comandos de teste no chat (só no Studio ou para o dono do jogo)
---------------------------------------------------------------------
local function isAdmin(player: Player): boolean
	return Config.AdminCommands and (RunService:IsStudio() or player.UserId == game.CreatorId)
end

local commands = {}
commands.ajuda = function(player)
	Remotes.notify(player, "Comandos (use / ou !): !dinheiro 100000 • !nivel 30 • !rebirth 2 • !evento Magma • "
		.. "!chefe TungGigante • !brainrot TungTung 20 Magma • !bolas 50 • !liberar", Color3.fromRGB(255, 230, 120))
end
commands.dinheiro = function(player, amount)
	DataService.addCash(player, tonumber(amount) or 100000)
end
commands.nivel = function(player, level)
	ProgressService.setLevel(player, tonumber(level) or 30)
end
commands.rebirth = function(player, amount)
	local data = DataService.get(player)
	data.rebirths = math.clamp(tonumber(amount) or 1, 0, Config.Rebirth.Max)
	TycoonService.refreshPlayer(player)
	DataService.pushUpdate(player)
end
commands.evento = function(player, eventId)
	if not EventService.startEvent(eventId) then
		Remotes.notify(player, "Eventos: Radiacao, Magma, ArcoIris", Color3.fromRGB(255, 120, 120))
	end
end
commands.chefe = function(player, bossId)
	if not WildService.spawnBoss(bossId or "TungGigante") then
		Remotes.notify(player, "Chefões: TungGigante, FrigoTita, BombardiroImperador (ou já está vivo)", Color3.fromRGB(255, 120, 120))
	end
end
commands.brainrot = function(player, id, level, mutation)
	if not Config.getBrainrot(id) then
		Remotes.notify(player, "id inválido (veja os ids na Config)", Color3.fromRGB(255, 120, 120))
		return
	end
	DataService.addBrainrot(player, id, math.clamp(tonumber(level) or 1, 1, Config.Levels.MaxLevel), Config.getMutation(mutation) and mutation or nil)
end
commands.bolas = function(player, amount)
	for _, ball in ipairs(Config.Balls) do
		DataService.addBalls(player, ball.id, tonumber(amount) or 50)
	end
end
commands.liberar = function(player)
	ProgressService.setLevel(player, Config.PlayerLevels.Max)
	for _, boss in ipairs(Config.Bosses) do
		ProgressService.markBoss(player, boss.id)
	end
	commands.rebirth(player, 1)
end

local function onChatted(player: Player, message: string)
	local prefix = string.sub(message, 1, 1)
	if not isAdmin(player) or (prefix ~= "/" and prefix ~= "!") then
		return
	end
	local args = string.split(string.sub(message, 2), " ")
	local name = string.lower(table.remove(args, 1) or "")
	local command = commands[name]
	if command then
		local ok, err = pcall(command, player, table.unpack(args))
		if not ok then
			warn("[Admin] erro em /" .. name .. ": " .. tostring(err))
		end
	end
end

---------------------------------------------------------------------
-- Jogadores
---------------------------------------------------------------------
local function onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	player:WaitForChild("Backpack", 10)
	task.wait(0.2)
	if character.Parent == nil then
		return
	end
	ToolService.giveTools(player)
	InventoryService.sync(player, true)
	TycoonService.teleportHome(player)
	task.wait(0.1)
	CompanionService.spawn(player)
end

local function onPlayerAdded(player: Player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)

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

	Remotes.notify(player, "Bem-vindo! 🏏 Bata nos brainrots e use a ⚪ Bola quando estiverem com POUCA vida!", Color3.fromRGB(255, 230, 100))
	task.delay(6, function()
		if player.Parent == Players then
			Remotes.notify(player, "🗺 Explore os biomas, derrote chefões e cuidado: outros jogadores podem ROUBAR sua base!",
				Color3.fromRGB(140, 230, 255))
		end
	end)
	if isAdmin(player) then
		task.delay(10, function()
			if player.Parent == Players then
				commands.ajuda(player)
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	StealService.cancel(player, "saiu do jogo")
	CompanionService.dismiss(player, true)
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
