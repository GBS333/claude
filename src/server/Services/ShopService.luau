-- Recebe os pedidos da interface do jogador: loja, rebirth, teleporte, trancar base,
-- colocar/guardar/vender, parceiro, trocas e duelos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local ToolService = require(script.Parent.ToolService)
local CompanionService = require(script.Parent.CompanionService)
local InventoryService = require(script.Parent.InventoryService)
local ProgressService = require(script.Parent.ProgressService)
local TradeService = require(script.Parent.TradeService)
local DuelService = require(script.Parent.DuelService)
local Remotes = require(script.Parent.Remotes)

local ShopService = {}

local fmt = CatchMath.formatNumber
local lastAction = {}
local ALLOWED_AMOUNTS = { [1] = true, [5] = true, [10] = true }
local FAST_ACTIONS = { GetData = true, UseMove = true, TradeSetOffer = true }

local function rebirthLock(player: Player, needed: number?)
	local data = DataService.get(player)
	if needed and needed > 0 and data.rebirths < needed then
		return "Precisa de " .. needed .. " rebirth(s) ♻"
	end
	return nil
end

local actions = {}

function actions.GetData(player)
	return true, DataService.snapshot(player)
end

function actions.SelectBall(player, ballId)
	local ballDef = type(ballId) == "string" and Config.getBall(ballId)
	if not ballDef then
		return false, "Bola inválida."
	end
	player:SetAttribute("SelectedBall", ballId)
	ToolService.updateBallTool(player)
	DataService.pushUpdate(player)
	return true, nil
end

function actions.BuyBall(player, ballId, amount)
	local ballDef = type(ballId) == "string" and Config.getBall(ballId)
	if not ballDef or not ALLOWED_AMOUNTS[amount] then
		return false, "Compra inválida."
	end
	local locked = rebirthLock(player, ballDef.rebirth)
	if locked then
		return false, locked
	end
	local price = ballDef.price * amount
	if not DataService.spendCash(player, price) then
		return false, "Você precisa de $" .. fmt(price) .. "."
	end
	DataService.addBalls(player, ballId, amount)
	return true, "Comprou " .. amount .. "x " .. ballDef.name .. "!"
end

function actions.BuyBat(player, batId)
	local batDef = type(batId) == "string" and Config.getBat(batId)
	local data = DataService.get(player)
	if not batDef then
		return false, "Item inválido."
	end
	if not data.ownedBats[batId] then
		local locked = rebirthLock(player, batDef.rebirth)
		if locked then
			return false, locked
		end
		if not DataService.spendCash(player, batDef.price) then
			return false, "Você precisa de $" .. fmt(batDef.price) .. "."
		end
		data.ownedBats[batId] = true
	end
	data.bat = batId
	ToolService.giveTools(player)
	InventoryService.sync(player, true)
	DataService.pushUpdate(player)
	return true, batDef.name .. " equipado!"
end

function actions.BuyGear(player, gearId)
	local gear = type(gearId) == "string" and Config.getGear(gearId)
	local data = DataService.get(player)
	if not gear then
		return false, "Item inválido."
	end
	if data.ownedGear[gearId] then
		return false, "Você já tem " .. gear.name .. "."
	end
	local locked = rebirthLock(player, gear.rebirth)
	if locked then
		return false, locked
	end
	if not DataService.spendCash(player, gear.price) then
		return false, "Você precisa de $" .. fmt(gear.price) .. "."
	end
	data.ownedGear[gearId] = true
	ToolService.giveTools(player)
	InventoryService.sync(player, true)
	DataService.pushUpdate(player)
	return true, "Comprou " .. gear.name .. "! Está na sua barra de itens."
end

function actions.Place(player, uid)
	if type(uid) ~= "string" then
		return false, "Inválido."
	end
	return TycoonService.place(player, uid, nil)
end

function actions.Store(player, uid)
	if type(uid) ~= "string" then
		return false, "Inválido."
	end
	return TycoonService.store(player, uid)
end

function actions.Sell(player, uid)
	if type(uid) ~= "string" then
		return false, "Inválido."
	end
	local item = DataService.findItem(player, uid)
	if not item then
		return false, "Brainrot não encontrado."
	end
	if TycoonService.isItemStolen(player, uid) then
		return false, "Ele está sendo roubado agora!"
	end
	if TradeService.isTrading(player) then
		return false, "Termine a troca primeiro."
	end
	local def = Config.getBrainrot(item.id)
	local data = DataService.get(player)
	if data.companion == uid then
		CompanionService.dismiss(player)
	end
	local price = Stats.sellPrice(def, item.level or 1, item.mutation)
	DataService.removeBrainrot(player, uid)
	TycoonService.onItemRemoved(player, item)
	DataService.addCash(player, price)
	return true, "Vendeu " .. Stats.displayName(def, item.level or 1, item.mutation) .. " por $" .. fmt(price) .. "!"
end

function actions.Summon(player, uid)
	if type(uid) ~= "string" then
		return false, "Inválido."
	end
	if TycoonService.isItemStolen(player, uid) then
		return false, "Ele está sendo roubado agora!"
	end
	local item = DataService.findItem(player, uid)
	if item and item.slot then
		TycoonService.store(player, uid)
	end
	return CompanionService.summon(player, uid)
end

function actions.Dismiss(player)
	return CompanionService.dismiss(player)
end

function actions.UseMove(player, moveId, targetModel)
	return CompanionService.useMove(player, moveId, targetModel)
end

function actions.ToggleAuto(player)
	local on = player:GetAttribute("AutoBattle") == false
	player:SetAttribute("AutoBattle", on)
	DataService.pushUpdate(player)
	return true, if on then "⚔ Modo automático LIGADO." else "Modo automático DESLIGADO."
end

function actions.Unlock(player)
	return TycoonService.unlockNext(player)
end

function actions.Home(player)
	if player:GetAttribute("InDuel") then
		return false, "Você está em um duelo!"
	end
	TycoonService.teleportHome(player)
	return true, nil
end

function actions.Lock(player)
	return TycoonService.lock(player)
end

function actions.Rebirth(player)
	return ProgressService.rebirth(player)
end

function actions.Teleport(player, biomeId)
	if type(biomeId) ~= "string" then
		return false, "Inválido."
	end
	return ProgressService.teleportTo(player, biomeId)
end

-- trocas
function actions.TradeRequest(player, userId)
	return TradeService.request(player, userId)
end
function actions.TradeRespond(player, accept)
	return TradeService.respond(player, accept)
end
function actions.TradeSetOffer(player, uids, cash)
	return TradeService.setOffer(player, uids, cash)
end
function actions.TradeReady(player, ready)
	return TradeService.setReady(player, ready)
end
function actions.TradeCancel(player)
	return TradeService.cancel(player)
end

-- duelos
function actions.DuelRequest(player, userId)
	return DuelService.request(player, userId)
end
function actions.DuelRespond(player, accept)
	return DuelService.respond(player, accept)
end
function actions.DuelPick(player, uid)
	return DuelService.pick(player, uid)
end
function actions.DuelRansom(player, pay)
	return DuelService.ransom(player, pay)
end

function ShopService.start()
	Remotes.Action.OnServerInvoke = function(player, actionName, ...)
		local handler = type(actionName) == "string" and actions[actionName]
		if not handler then
			return false, "Ação desconhecida."
		end
		local now = os.clock()
		if not FAST_ACTIONS[actionName] then
			if lastAction[player] and now - lastAction[player] < 0.15 then
				return false, nil
			end
			lastAction[player] = now
		end
		if not DataService.get(player) then
			return false, "Carregando seus dados..."
		end
		local ok, okResult, msg = pcall(handler, player, ...)
		if not ok then
			warn("[ShopService] erro em " .. actionName .. ": " .. tostring(okResult))
			return false, "Ocorreu um erro."
		end
		return okResult, msg
	end

	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return ShopService
