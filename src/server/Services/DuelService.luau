-- DUELO: desafie outro jogador. Os dois vão para a Arena e lutam com os objetos de bater
-- (e os parceiros lutam entre si). Quem cair perde. O vencedor escolhe um brainrot
-- do perdedor, e o perdedor pode PAGAR um resgate para não perder ele.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local CompanionService = require(script.Parent.CompanionService)
local StealService = require(script.Parent.StealService)
local ProgressService = require(script.Parent.ProgressService)
local Remotes = require(script.Parent.Remotes)

local DuelService = {}

local D = Config.Duel
local fmt = CatchMath.formatNumber
local RED = Color3.fromRGB(255, 120, 120)
local GREEN = Color3.fromRGB(120, 255, 140)
local GOLD = Color3.fromRGB(255, 220, 90)
local REQUEST_TIME = 20

local requests = {} -- [alvo] = { from, time }
local duels = {} -- [Player] = duelo

function DuelService.isInDuel(player: Player): boolean
	return duels[player] ~= nil
end

local function ransomPrice(item): number
	local def = Config.getBrainrot(item.id)
	return math.max(100, math.floor(Stats.sellPrice(def, item.level or 1, item.mutation) * D.RansomMultiplier))
end

local function cleanup(duel)
	for _, p in ipairs({ duel.a, duel.b }) do
		if duels[p] == duel then
			duels[p] = nil
		end
	end
end

local function sendHome(player: Player)
	task.delay(2.5, function()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
			TycoonService.teleportHome(player)
		end
	end)
end

local function resolve(duel, pay: boolean)
	if duel.resolved then
		return
	end
	duel.resolved = true
	local winner, loser = duel.winner, duel.loser
	local loserData = DataService.get(loser)
	local item = loserData and DataService.findItem(loser, duel.pickedUid)
	if not item or winner.Parent ~= Players then
		cleanup(duel)
		return
	end
	local def = Config.getBrainrot(item.id)
	local name = Stats.displayName(def, item.level or 1, item.mutation)
	local price = ransomPrice(item)

	if pay and loserData.cash >= price then
		loserData.cash -= price
		DataService.addCash(winner, price)
		DataService.pushUpdate(loser)
		Remotes.notify(loser, "💸 Você pagou $" .. fmt(price) .. " e salvou " .. name .. "!", GOLD)
		Remotes.notify(winner, "💰 " .. loser.DisplayName .. " pagou $" .. fmt(price) .. " de resgate por " .. name .. "!", GREEN)
	else
		if loserData.companion == item.uid then
			CompanionService.dismiss(loser)
		end
		local _, oldItem = DataService.transferItem(loser, winner, item.uid)
		if oldItem then
			TycoonService.onItemRemoved(loser, oldItem)
		end
		Remotes.notify(winner, "🏆 Você ganhou " .. name .. " do duelo! Ele está na sua barra de itens.", GREEN)
		Remotes.notify(loser, "😭 " .. winner.DisplayName .. " levou seu " .. name .. ".", RED)
	end
	cleanup(duel)
end

local function startRansom(duel, uid: string)
	local item = DataService.findItem(duel.loser, uid)
	if not item then
		resolve(duel, false)
		return
	end
	duel.phase = "ransom"
	duel.pickedUid = uid
	local def = Config.getBrainrot(item.id)
	local name = Stats.displayName(def, item.level or 1, item.mutation)
	Remotes.Social:FireClient(duel.loser, "duelRansom", {
		winnerName = duel.winner.DisplayName, itemName = name, price = ransomPrice(item), time = D.RansomTime,
	})
	Remotes.notify(duel.winner, "Você escolheu " .. name .. ". Esperando " .. duel.loser.DisplayName .. " decidir se paga o resgate...", GOLD)
	task.delay(D.RansomTime, function()
		if duel.phase == "ransom" and not duel.resolved then
			resolve(duel, false)
		end
	end)
end

local function finishDuel(duel, winner: Player?, loser: Player?, reason: string?)
	if duel.ended then
		return
	end
	duel.ended = true
	for _, c in ipairs(duel.connections) do
		c:Disconnect()
	end
	for _, p in ipairs({ duel.a, duel.b }) do
		p:SetAttribute("InDuel", nil)
		p:SetAttribute("Frozen", nil)
		CompanionService.setDuelTarget(p, nil)
		if p.Parent == Players then
			Remotes.Social:FireClient(p, "duelEnded", { won = p == winner, draw = winner == nil })
		end
	end

	if not winner or not loser then
		for _, p in ipairs({ duel.a, duel.b }) do
			if p.Parent == Players then
				Remotes.notify(p, "⚔ Duelo terminou empatado" .. (if reason then " (" .. reason .. ")" else "") .. ".", GOLD)
				sendHome(p)
			end
		end
		cleanup(duel)
		return
	end

	duel.winner, duel.loser = winner, loser
	Remotes.notify(winner, "🏆 Você venceu o duelo contra " .. loser.DisplayName .. "!", GREEN)
	ProgressService.giveXp(winner, 150)
	sendHome(winner)

	local loserData = DataService.get(loser)
	if not loserData or loser.Parent ~= Players then
		cleanup(duel)
		return
	end
	Remotes.notify(loser, "💀 Você perdeu o duelo para " .. winner.DisplayName .. ".", RED)

	-- lista de brainrots que o vencedor pode escolher
	local items = {}
	for _, item in ipairs(loserData.inventory) do
		if not TycoonService.isItemStolen(loser, item.uid) then
			local def = Config.getBrainrot(item.id)
			table.insert(items, {
				uid = item.uid, id = item.id, level = item.level or 1, mutation = item.mutation,
				name = Stats.displayName(def, item.level or 1, item.mutation), rarity = def.rarity,
				value = Stats.sellPrice(def, item.level or 1, item.mutation),
			})
		end
	end

	if #items == 0 then
		local prize = math.floor(loserData.cash * 0.1)
		if prize > 0 then
			loserData.cash -= prize
			DataService.pushUpdate(loser)
			DataService.addCash(winner, prize)
		end
		Remotes.notify(winner, loser.DisplayName .. " não tem brainrots. Você ganhou $" .. fmt(prize) .. ".", GOLD)
		cleanup(duel)
		return
	end

	table.sort(items, function(x, y)
		return x.value > y.value
	end)
	duel.phase = "pick"
	duel.pickItems = items
	Remotes.Social:FireClient(winner, "duelPick", { loserName = loser.DisplayName, items = items, time = D.PickTime })
	Remotes.notify(loser, winner.DisplayName .. " está escolhendo um brainrot seu... 😬", RED)
	task.delay(D.PickTime, function()
		if duel.phase == "pick" then
			startRansom(duel, items[1].uid) -- escolhe o mais valioso automaticamente
		end
	end)
end

local function startDuel(a: Player, b: Player)
	local duel = { a = a, b = b, connections = {}, phase = "countdown" }
	duels[a] = duel
	duels[b] = duel

	local arena = D.Arena
	local spots = {
		[a] = CFrame.lookAt(arena + Vector3.new(-D.PadOffset, 4, 0), arena + Vector3.new(0, 4, 0)),
		[b] = CFrame.lookAt(arena + Vector3.new(D.PadOffset, 4, 0), arena + Vector3.new(0, 4, 0)),
	}
	for _, p in ipairs({ a, b }) do
		local other = if p == a then b else a
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			finishDuel(duel, nil, nil, "sem personagem")
			return
		end
		character:PivotTo(spots[p])
		humanoid.Health = humanoid.MaxHealth
		p:SetAttribute("InDuel", true)
		p:SetAttribute("Frozen", true)
		Remotes.Social:FireClient(p, "duelCountdown", { opponent = other.DisplayName, seconds = D.Countdown })
		table.insert(duel.connections, humanoid.Died:Connect(function()
			finishDuel(duel, other, p)
		end))
	end

	task.delay(D.Countdown, function()
		if duel.ended then
			return
		end
		duel.phase = "fight"
		for _, p in ipairs({ a, b }) do
			p:SetAttribute("Frozen", nil)
			Remotes.Social:FireClient(p, "duelFight", {})
		end
		CompanionService.setDuelTarget(a, b)
		CompanionService.setDuelTarget(b, a)
	end)

	task.delay(D.Countdown + D.MaxTime, function()
		if not duel.ended then
			finishDuel(duel, nil, nil, "tempo esgotado")
		end
	end)
end

---------------------------------------------------------------------
-- Ações chamadas pela interface
---------------------------------------------------------------------
local function canDuel(player: Player): (boolean, string?)
	if duels[player] then
		return false, "Já está em um duelo."
	end
	if StealService.isCarrying(player) then
		return false, "Está carregando um brainrot roubado."
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Precisa estar vivo."
	end
	return true, nil
end

function DuelService.request(from: Player, targetUserId: any)
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target or target == from then
		return false, "Jogador não encontrado."
	end
	local ok, why = canDuel(from)
	if not ok then
		return false, why
	end
	ok, why = canDuel(target)
	if not ok then
		return false, target.DisplayName .. ": " .. (why or "não pode duelar agora")
	end
	requests[target] = { from = from, time = os.clock() }
	Remotes.Social:FireClient(target, "duelRequest", { fromName = from.DisplayName, fromUserId = from.UserId })
	return true, "⚔ Desafio enviado para " .. target.DisplayName .. "!"
end

function DuelService.respond(target: Player, accept: any)
	local req = requests[target]
	requests[target] = nil
	if not req or os.clock() - req.time > REQUEST_TIME or req.from.Parent ~= Players then
		return false, "O desafio expirou."
	end
	if not accept then
		Remotes.notify(req.from, target.DisplayName .. " recusou o duelo. 🐔", RED)
		return true, nil
	end
	local ok, why = canDuel(req.from)
	if ok then
		ok, why = canDuel(target)
	end
	if not ok then
		return false, why
	end
	startDuel(req.from, target)
	return true, nil
end

function DuelService.pick(player: Player, uid: any)
	local duel = duels[player]
	if not duel or duel.phase ~= "pick" or duel.winner ~= player or type(uid) ~= "string" then
		return false, nil
	end
	for _, info in ipairs(duel.pickItems) do
		if info.uid == uid then
			startRansom(duel, uid)
			return true, nil
		end
	end
	return false, "Brainrot inválido."
end

function DuelService.ransom(player: Player, pay: any)
	local duel = duels[player]
	if not duel or duel.phase ~= "ransom" or duel.loser ~= player then
		return false, nil
	end
	resolve(duel, pay == true)
	return true, nil
end

function DuelService.start()
	StealService.canStealCheck = function(player: Player)
		if duels[player] then
			return false, "Você está em um duelo!"
		end
		return true, nil
	end

	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
		local duel = duels[player]
		if duel then
			if not duel.ended then
				local other = if duel.a == player then duel.b else duel.a
				finishDuel(duel, other, player)
			elseif duel.phase == "ransom" and duel.loser == player then
				resolve(duel, false)
			else
				cleanup(duel)
			end
		end
	end)
end

return DuelService
