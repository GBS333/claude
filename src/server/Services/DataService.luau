-- Salva e carrega os dados dos jogadores (dinheiro, bolas, brainrots, tacos...).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local DataService = {}

local profiles = {} -- [Player] = dados

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível (no Studio ative 'Enable Studio Access to API Services'). Os dados não serão salvos.")
	end
end

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return copy
end

local function defaultData()
	return {
		cash = Config.StartingCash,
		balls = deepCopy(Config.StartingBalls),
		bat = "Madeira",
		ownedBats = { Madeira = true },
		inventory = {}, -- lista de { uid = "1", id = "TungTung", level = 1, xp = 0, slot = nil ou número do pedestal }
		-- companion = uid do brainrot parceiro (ou nil)
		unlockedSlots = Config.Tycoon.StartingSlots,
		dex = {}, -- [id] = quantas vezes capturou
		nextUid = 1,
		totalCaught = 0,
	}
end

-- Completa campos que faltam (útil quando você adiciona coisas novas ao jogo)
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = if type(v) == "table" then deepCopy(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "inventory" then
			reconcile(data[k], v)
		end
	end
end

local function key(player: Player)
	return "player_" .. player.UserId
end

local function setupLeaderstats(player: Player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Dinheiro"
	cash.Value = data.cash
	cash.Parent = leaderstats

	local caught = Instance.new("IntValue")
	caught.Name = "Capturados"
	caught.Value = data.totalCaught
	caught.Parent = leaderstats

	leaderstats.Parent = player
end

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	leaderstats.Dinheiro.Value = math.floor(data.cash)
	leaderstats.Capturados.Value = data.totalCaught
end

function DataService.load(player: Player)
	local data
	local loadFailed = false

	if store then
		local ok, result = pcall(function()
			return store:GetAsync(key(player))
		end)
		if ok then
			data = result
		else
			loadFailed = true
			warn("[DataService] Falha ao carregar dados de " .. player.Name .. ": " .. tostring(result))
		end
	end

	if type(data) ~= "table" then
		data = defaultData()
	else
		reconcile(data, defaultData())
	end

	-- remove brainrots que não existem mais na Config e completa nível/XP de saves antigos
	local companionFound = false
	for i = #data.inventory, 1, -1 do
		local item = data.inventory[i]
		if not Config.getBrainrot(item.id) then
			table.remove(data.inventory, i)
		else
			item.level = math.clamp(math.floor(tonumber(item.level) or 1), 1, Config.Levels.MaxLevel)
			item.xp = tonumber(item.xp) or 0
			if item.uid == data.companion then
				companionFound = true
				item.slot = nil
			end
		end
	end
	if not companionFound then
		data.companion = nil
	end

	-- se falhou o carregamento, não salva por cima (para não apagar o progresso)
	data._loadFailed = loadFailed
	profiles[player] = data
	setupLeaderstats(player, data)

	if player:GetAttribute("SelectedBall") == nil then
		player:SetAttribute("SelectedBall", "Basica")
	end

	return data
end

function DataService.save(player: Player)
	local data = profiles[player]
	if not data or not store or data._loadFailed then
		return
	end

	local toSave = deepCopy(data)
	toSave._loadFailed = nil

	local ok, err = pcall(function()
		store:SetAsync(key(player), toSave)
	end)
	if not ok then
		warn("[DataService] Falha ao salvar " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player] = nil
end

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.snapshot(player: Player)
	local data = profiles[player]
	if not data then
		return nil
	end
	return {
		cash = data.cash,
		balls = data.balls,
		bat = data.bat,
		ownedBats = data.ownedBats,
		inventory = data.inventory,
		unlockedSlots = data.unlockedSlots,
		dex = data.dex,
		totalCaught = data.totalCaught,
		companion = data.companion,
		autoBattle = player:GetAttribute("AutoBattle") ~= false,
		selectedBall = player:GetAttribute("SelectedBall") or "Basica",
	}
end

function DataService.pushUpdate(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	updateLeaderstats(player, data)
	Remotes.DataUpdated:FireClient(player, DataService.snapshot(player))
	for _, callback in ipairs(DataService.updateListeners) do
		task.spawn(callback, player)
	end
end

-- Outros sistemas podem pedir para ser avisados quando os dados mudam
DataService.updateListeners = {}
function DataService.onUpdate(callback)
	table.insert(DataService.updateListeners, callback)
end

---------------------------------------------------------------------
-- Dinheiro
---------------------------------------------------------------------
function DataService.addCash(player: Player, amount: number)
	local data = profiles[player]
	if not data then
		return
	end
	data.cash += amount
	DataService.pushUpdate(player)
end

function DataService.spendCash(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or data.cash < amount then
		return false
	end
	data.cash -= amount
	DataService.pushUpdate(player)
	return true
end

---------------------------------------------------------------------
-- Bolas
---------------------------------------------------------------------
function DataService.useBall(player: Player, ballId: string): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	local count = data.balls[ballId] or 0
	if count <= 0 then
		return false
	end
	data.balls[ballId] = count - 1
	DataService.pushUpdate(player)
	return true
end

function DataService.addBalls(player: Player, ballId: string, amount: number)
	local data = profiles[player]
	if not data then
		return
	end
	data.balls[ballId] = (data.balls[ballId] or 0) + amount
	DataService.pushUpdate(player)
end

---------------------------------------------------------------------
-- Brainrots
---------------------------------------------------------------------
function DataService.addBrainrot(player: Player, brainrotId: string, level: number?)
	local data = profiles[player]
	if not data then
		return nil
	end
	local item = { uid = tostring(data.nextUid), id = brainrotId, level = level or 1, xp = 0 }
	data.nextUid += 1
	table.insert(data.inventory, item)
	data.dex[brainrotId] = (data.dex[brainrotId] or 0) + 1
	data.totalCaught += 1
	DataService.pushUpdate(player)
	return item
end

function DataService.findItem(player: Player, uid: string)
	local data = profiles[player]
	if not data then
		return nil, nil
	end
	for i, item in ipairs(data.inventory) do
		if item.uid == uid then
			return item, i
		end
	end
	return nil, nil
end

function DataService.removeBrainrot(player: Player, uid: string)
	local data = profiles[player]
	local item, i = DataService.findItem(player, uid)
	if not item then
		return nil
	end
	table.remove(data.inventory, i)
	if data.companion == uid then
		data.companion = nil
	end
	DataService.pushUpdate(player)
	return item
end

---------------------------------------------------------------------
-- Salvamento automático
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.AutoSaveInterval)
		for player in pairs(profiles) do
			task.spawn(DataService.save, player)
		end
	end
end)

return DataService
