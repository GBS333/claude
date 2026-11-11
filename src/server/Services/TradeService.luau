-- TROCA entre jogadores: um pede, o outro aceita, cada um escolhe brainrots e dinheiro,
-- os dois apertam "Pronto" e a troca acontece. Mudou a oferta? Os dois precisam confirmar de novo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local CompanionService = require(script.Parent.CompanionService)
local Remotes = require(script.Parent.Remotes)

local TradeService = {}

local MAX_ITEMS = 8
local REQUEST_TIME = 20
local RED = Color3.fromRGB(255, 120, 120)
local GREEN = Color3.fromRGB(120, 255, 140)

local requests = {} -- [alvo] = { from = Player, time = número }
local trades = {} -- [Player] = troca

function TradeService.isTrading(player: Player): boolean
	return trades[player] ~= nil
end

local function itemInfo(item)
	local def = Config.getBrainrot(item.id)
	return {
		uid = item.uid,
		id = item.id,
		level = item.level or 1,
		mutation = item.mutation,
		name = Stats.displayName(def, item.level or 1, item.mutation),
		rarity = def.rarity,
	}
end

local function eligible(player: Player, uid: string)
	local item = DataService.findItem(player, uid)
	if not item or TycoonService.isItemStolen(player, uid) then
		return nil
	end
	return item
end

local function describe(trade, player: Player)
	local offer = trade.offers[player]
	local items = {}
	for _, uid in ipairs(offer.uids) do
		local item = DataService.findItem(player, uid)
		if item then
			table.insert(items, itemInfo(item))
		end
	end
	return { cash = offer.cash, items = items }
end

local function sendState(trade)
	for _, p in ipairs({ trade.a, trade.b }) do
		local other = if p == trade.a then trade.b else trade.a
		Remotes.Social:FireClient(p, "tradeUpdate", {
			partner = other.DisplayName,
			mine = describe(trade, p),
			theirs = describe(trade, other),
			myReady = trade.ready[p],
			theirReady = trade.ready[other],
		})
	end
end

local function close(trade, message: string?, color: Color3?)
	for _, p in ipairs({ trade.a, trade.b }) do
		if trades[p] == trade then
			trades[p] = nil
		end
		if p.Parent == Players then
			Remotes.Social:FireClient(p, "tradeClosed", message)
			if message then
				Remotes.notify(p, message, color or RED)
			end
		end
	end
end

function TradeService.request(from: Player, targetUserId: any)
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target or target == from then
		return false, "Jogador não encontrado."
	end
	if trades[from] or trades[target] then
		return false, "Alguém já está em uma troca."
	end
	if not DataService.get(target) then
		return false, "Esse jogador ainda está carregando."
	end
	requests[target] = { from = from, time = os.clock() }
	Remotes.Social:FireClient(target, "tradeRequest", { fromName = from.DisplayName, fromUserId = from.UserId })
	return true, "🤝 Pedido de troca enviado para " .. target.DisplayName .. "."
end

function TradeService.respond(target: Player, accept: any)
	local req = requests[target]
	requests[target] = nil
	if not req or os.clock() - req.time > REQUEST_TIME or req.from.Parent ~= Players then
		return false, "O pedido de troca expirou."
	end
	local from = req.from
	if not accept then
		Remotes.notify(from, target.DisplayName .. " recusou a troca.", RED)
		return true, nil
	end
	if trades[from] or trades[target] then
		return false, "Alguém já está em uma troca."
	end
	local trade = {
		a = from,
		b = target,
		offers = { [from] = { uids = {}, cash = 0 }, [target] = { uids = {}, cash = 0 } },
		ready = { [from] = false, [target] = false },
	}
	trades[from] = trade
	trades[target] = trade
	sendState(trade)
	return true, nil
end

function TradeService.setOffer(player: Player, uids: any, cash: any)
	local trade = trades[player]
	local data = DataService.get(player)
	if not trade or not data then
		return false, "Você não está em uma troca."
	end
	if type(uids) ~= "table" then
		uids = {}
	end
	local clean, seen = {}, {}
	for _, uid in ipairs(uids) do
		if type(uid) == "string" and not seen[uid] and #clean < MAX_ITEMS and eligible(player, uid) then
			seen[uid] = true
			table.insert(clean, uid)
		end
	end
	cash = math.floor(tonumber(cash) or 0)
	if cash ~= cash then
		cash = 0
	end
	cash = math.clamp(cash, 0, math.max(0, math.floor(data.cash)))

	trade.offers[player] = { uids = clean, cash = cash }
	trade.ready[trade.a] = false
	trade.ready[trade.b] = false
	sendState(trade)
	return true, nil
end

local function execute(trade)
	-- confere tudo de novo antes de trocar
	for _, p in ipairs({ trade.a, trade.b }) do
		local data = DataService.get(p)
		local offer = trade.offers[p]
		if not data or p.Parent ~= Players or data.cash < offer.cash then
			close(trade, "Troca cancelada: algo mudou.")
			return
		end
		for _, uid in ipairs(offer.uids) do
			if not eligible(p, uid) then
				trade.ready[trade.a] = false
				trade.ready[trade.b] = false
				sendState(trade)
				Remotes.notify(trade.a, "Um brainrot da troca mudou. Confira e aperte Pronto de novo.", RED)
				Remotes.notify(trade.b, "Um brainrot da troca mudou. Confira e aperte Pronto de novo.", RED)
				return
			end
		end
	end

	for _, p in ipairs({ trade.a, trade.b }) do
		local other = if p == trade.a then trade.b else trade.a
		local offer = trade.offers[p]
		local data = DataService.get(p)
		for _, uid in ipairs(offer.uids) do
			if data.companion == uid then
				CompanionService.dismiss(p)
			end
			local _, oldItem = DataService.transferItem(p, other, uid)
			if oldItem then
				TycoonService.onItemRemoved(p, oldItem)
			end
		end
		if offer.cash > 0 then
			DataService.get(p).cash -= offer.cash
			DataService.get(other).cash += offer.cash
		end
	end
	DataService.pushUpdate(trade.a)
	DataService.pushUpdate(trade.b)
	close(trade, "✅ Troca feita com sucesso!", GREEN)
end

function TradeService.setReady(player: Player, ready: any)
	local trade = trades[player]
	if not trade then
		return false, "Você não está em uma troca."
	end
	trade.ready[player] = ready == true
	sendState(trade)
	if trade.ready[trade.a] and trade.ready[trade.b] then
		execute(trade)
	end
	return true, nil
end

function TradeService.cancel(player: Player)
	local trade = trades[player]
	if trade then
		close(trade, "❌ " .. player.DisplayName .. " cancelou a troca.")
	end
	return true, nil
end

function TradeService.start()
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
		local trade = trades[player]
		if trade then
			close(trade, "❌ " .. player.DisplayName .. " saiu do jogo. Troca cancelada.")
		end
	end)
end

return TradeService
