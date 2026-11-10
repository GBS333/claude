-- Recebe os pedidos da interface do jogador: comprar bolas/tacos, escolher bola,
-- colocar/guardar/vender brainrots e desbloquear pedestais.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local ToolService = require(script.Parent.ToolService)
local CompanionService = require(script.Parent.CompanionService)
local InventoryService = require(script.Parent.InventoryService)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Remotes = require(script.Parent.Remotes)

local ShopService = {}

local fmt = CatchMath.formatNumber
local lastAction = {}

local ALLOWED_AMOUNTS = { [1] = true, [5] = true, [10] = true }

local actions = {}

function actions.GetData(player)
	return true, DataService.snapshot(player)
end

function actions.SelectBall(player, ballId)
	if type(ballId) ~= "string" or not Config.getBall(ballId) then
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
	if not batDef or not data then
		return false, "Taco inválido."
	end
	if not data.ownedBats[batId] then
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
	local def = Config.getBrainrot(item.id)
	local data = DataService.get(player)
	if data.companion == uid then
		CompanionService.dismiss(player)
	end
	local price = Stats.sellPrice(def, item.level or 1)
	DataService.removeBrainrot(player, uid)
	TycoonService.onItemRemoved(player, item)
	DataService.addCash(player, price)
	return true, "Vendeu " .. Stats.displayName(def, item.level or 1) .. " por $" .. fmt(price) .. "!"
end

-- escolher o parceiro de batalha (tira do pedestal se precisar)
function actions.Summon(player, uid)
	if type(uid) ~= "string" then
		return false, "Inválido."
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
	return true, if on then "⚔ Modo automático LIGADO: seu parceiro ataca brainrots perto de você." else "Modo automático DESLIGADO: ele só ataca quem você bater ou quem te atacar."
end

function actions.Unlock(player)
	return TycoonService.unlockNext(player)
end

function actions.Home(player)
	TycoonService.teleportHome(player)
	return true, nil
end

function ShopService.start()
	Remotes.Action.OnServerInvoke = function(player, actionName, ...)
		local handler = type(actionName) == "string" and actions[actionName]
		if not handler then
			return false, "Ação desconhecida."
		end
		-- proteção simples contra spam
		local now = os.clock()
		if actionName ~= "GetData" and actionName ~= "UseMove" and lastAction[player] and now - lastAction[player] < 0.15 then
			return false, nil
		end
		if actionName ~= "UseMove" then
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
