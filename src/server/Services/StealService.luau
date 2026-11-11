-- ROUBO: vá até a base de outro jogador, segure F no pedestal para pegar o brainrot
-- e leve até a SUA base antes do tempo acabar. Se alguém te bater com um taco
-- (ou você morrer), o brainrot volta para o dono. O dono recebe um alarme.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local BrainrotModels = require(script.Parent.BrainrotModels)
local Remotes = require(script.Parent.Remotes)

local StealService = {}

local S = Config.Steal
local RED = Color3.fromRGB(255, 100, 100)
local GREEN = Color3.fromRGB(120, 255, 140)

local carrying = {} -- [ladrão] = { victim, plot, slotIndex, uid, startTime, model, name }

-- outros sistemas podem bloquear o roubo (ex.: quem está em duelo)
StealService.canStealCheck = nil -- function(player): (boolean, string?)

function StealService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

local function attachCarryModel(thief: Player, item)
	local character = thief.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local def = Config.getBrainrot(item.id)
	local model = BrainrotModels.build(def, 3 / math.max(def.size.Y, 0.5), Stats.stage(item.level or 1), item.mutation)
	local root = model.PrimaryPart
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = root
			end
		end
	end
	model:PivotTo(head.CFrame * CFrame.new(0, 1 + root.Size.Y / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = root
	weld.Parent = root
	model.Name = "Roubado"
	model.Parent = character
	return model
end

local function finish(thief: Player, success: boolean, reason: string?)
	local info = carrying[thief]
	if not info then
		return
	end
	carrying[thief] = nil
	if info.model then
		info.model:Destroy()
	end
	thief:SetAttribute("Carrying", nil)

	local victim = info.victim
	local victimOnline = victim.Parent == Players and DataService.get(victim) ~= nil
	local item = victimOnline and DataService.findItem(victim, info.uid)

	if success and item and DataService.get(thief) then
		-- tira do pedestal e passa para o ladrão
		local _, oldItem = DataService.transferItem(victim, thief, info.uid)
		if oldItem then
			TycoonService.onItemRemoved(victim, oldItem)
		end
		Remotes.notify(thief, "🤑 Você roubou " .. info.name .. "! Ele está na sua barra de itens.", GREEN)
		Remotes.notify(victim, "😭 " .. thief.DisplayName .. " roubou seu " .. info.name .. "!", RED)
		return
	end

	-- falhou: volta para o pedestal do dono
	if victimOnline and item then
		TycoonService.setSlotStolen(info.plot, info.slotIndex, false)
		Remotes.notify(victim, "🛡 Seu " .. info.name .. " voltou para a base!", GREEN)
	end
	if thief.Parent == Players then
		Remotes.notify(thief, "❌ Roubo falhou" .. (if reason then ": " .. reason else "") .. ".", RED)
	end
end

local function startSteal(thief: Player, plot, slot)
	local victim = plot.owner
	if not victim or victim == thief then
		return
	end
	if carrying[thief] then
		Remotes.notify(thief, "Você já está carregando um brainrot!", RED)
		return
	end
	if not TycoonService.getPlot(thief) then
		Remotes.notify(thief, "Você precisa de uma base para roubar.", RED)
		return
	end
	if TycoonService.isLocked(plot) then
		Remotes.notify(thief, "Essa base está trancada! 🔒", RED)
		return
	end
	if slot.stolen then
		Remotes.notify(thief, "Alguém já está roubando esse!", RED)
		return
	end
	if StealService.canStealCheck then
		local ok, why = StealService.canStealCheck(thief)
		if not ok then
			Remotes.notify(thief, why or "Agora não dá.", RED)
			return
		end
	end
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local item = TycoonService.getSlotItem(plot, slot.index)
	if not item then
		return
	end

	local def = Config.getBrainrot(item.id)
	local name = Stats.displayName(def, item.level or 1, item.mutation)
	TycoonService.setSlotStolen(plot, slot.index, true)
	carrying[thief] = {
		victim = victim,
		plot = plot,
		slotIndex = slot.index,
		uid = item.uid,
		startTime = os.clock(),
		name = name,
		model = attachCarryModel(thief, item),
	}
	thief:SetAttribute("Carrying", true)
	-- tira a invisibilidade quando pega (fica mais justo)
	thief:SetAttribute("BreakInvisibility", true)

	Remotes.notify(thief, "🏃 Leve " .. name .. " até a SUA base em " .. S.TimeLimit .. "s! Não deixe te baterem!", Color3.fromRGB(255, 220, 90))
	Remotes.notify(victim, "🚨 " .. thief.DisplayName .. " está ROUBANDO seu " .. name .. "! Bata nele com o taco!", RED)
end

-- chamado quando alguém acerta o ladrão com um objeto de bater
function StealService.onPlayerHit(victim: Player, attacker: Player?)
	if carrying[victim] then
		finish(victim, false, if attacker then attacker.DisplayName .. " te acertou" else "você levou um golpe")
		if attacker then
			Remotes.notify(attacker, "💥 Você fez " .. victim.DisplayName .. " largar o brainrot!", GREEN)
		end
	end
end

function StealService.cancel(player: Player, reason: string?)
	finish(player, false, reason)
end

function StealService.start()
	TycoonService.stealHandler = startSteal

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for thief, info in pairs(carrying) do
			local character = thief.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if thief.Parent ~= Players or not humanoid or humanoid.Health <= 0 or not hrp then
				finish(thief, false, "você caiu")
			elseif info.victim.Parent ~= Players then
				finish(thief, false, "o dono saiu do jogo")
			elseif now - info.startTime > S.TimeLimit then
				finish(thief, false, "o tempo acabou")
			else
				local myPlot = TycoonService.getPlot(thief)
				if myPlot and TycoonService.isInPlot(myPlot, hrp.Position) then
					finish(thief, true)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if carrying[player] then
			finish(player, false, "saiu do jogo")
		end
		for thief, info in pairs(carrying) do
			if info.victim == player then
				finish(thief, false, "o dono saiu do jogo")
			end
		end
	end)
end

return StealService
