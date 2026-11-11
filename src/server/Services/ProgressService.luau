-- PROGRESSO: nível do jogador, áreas que desbloqueiam (por nível, chefão ou rebirth),
-- teleporte entre áreas, recompensa dos chefões e REBIRTH.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local WildService = require(script.Parent.WildService)
local Remotes = require(script.Parent.Remotes)

local ProgressService = {}

local fmt = CatchMath.formatNumber
local GOLD = Color3.fromRGB(255, 220, 90)
local RED = Color3.fromRGB(255, 120, 120)
local lastWarning = {}

local function progressOf(data)
	return { level = data.playerLevel, bosses = data.bosses, rebirths = data.rebirths }
end

function ProgressService.canEnter(player: Player, biome): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Carregando..."
	end
	return Stats.canEnter(progressOf(data), biome)
end

local function unlockedSet(data)
	local set = {}
	if data then
		for _, biome in ipairs(Config.Biomes) do
			if Stats.canEnter(progressOf(data), biome) then
				set[biome.id] = true
			end
		end
	end
	return set
end

local function announceNewAreas(player: Player, before)
	local data = DataService.get(player)
	local after = unlockedSet(data)
	for _, biome in ipairs(Config.Biomes) do
		if after[biome.id] and not before[biome.id] then
			Remotes.Social:FireClient(player, "areaUnlocked", biome.icon .. " " .. biome.name)
			Remotes.notify(player, "🔓 Nova área liberada: " .. biome.icon .. " " .. biome.name .. "! (menu 🗺 Áreas)", GOLD)
		end
	end
end

function ProgressService.giveXp(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	local before = unlockedSet(data)
	local gained = DataService.addPlayerXp(player, math.floor(amount))
	if gained > 0 then
		Remotes.CompanionEvent:FireClient(player, "playerlevel", data.playerLevel)
		announceNewAreas(player, before)
	end
end

function ProgressService.setLevel(player: Player, level: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	local before = unlockedSet(data)
	data.playerLevel = math.clamp(math.floor(level), 1, Config.PlayerLevels.Max)
	data.playerXp = 0
	DataService.pushUpdate(player)
	announceNewAreas(player, before)
end

function ProgressService.markBoss(player: Player, bossId: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local before = unlockedSet(data)
	data.bosses[bossId] = true
	DataService.pushUpdate(player)
	announceNewAreas(player, before)
end

---------------------------------------------------------------------
-- Teleporte
---------------------------------------------------------------------
local function hubCFrame(): CFrame
	local spawnLocation = workspace:FindFirstChild("SpawnLocation", true)
	if spawnLocation and spawnLocation:IsA("BasePart") then
		return spawnLocation.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 5, 0)
end

local function entryCFrame(biome): CFrame
	local c = biome.center
	if biome.id == "Ceu" or c.Magnitude < 1 then
		return CFrame.new(c + Vector3.new(0, 5, 0))
	end
	local toward = Vector3.new(-c.X, 0, -c.Z).Unit
	local depth = math.min(biome.size.X, biome.size.Y) / 2 - 15
	local pos = c + toward * depth + Vector3.new(0, 5, 0)
	return CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
end

function ProgressService.teleportTo(player: Player, biomeId: string)
	local biome = Config.getBiome(biomeId)
	local character = player.Character
	if not biome or not character then
		return false, "Área inválida."
	end
	local ok, why = ProgressService.canEnter(player, biome)
	if not ok then
		return false, "🔒 " .. biome.name .. ": " .. (why or "trancado")
	end
	if player:GetAttribute("Carrying") then
		return false, "Não dá para teleportar carregando um brainrot roubado!"
	end
	if player:GetAttribute("InDuel") then
		return false, "Você está em um duelo!"
	end
	character:PivotTo(entryCFrame(biome))
	return true, "Bem-vindo a " .. biome.icon .. " " .. biome.name .. "!"
end

function ProgressService.teleportHub(player: Player)
	if player.Character then
		player.Character:PivotTo(hubCFrame())
	end
end

---------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------
function ProgressService.rebirthInfo(rebirths: number)
	local R = Config.Rebirth
	local nextIndex = rebirths + 1
	if nextIndex > R.Max then
		return nil
	end
	return { cost = R.Costs[nextIndex], level = R.Levels[nextIndex], number = nextIndex }
end

function ProgressService.rebirth(player: Player)
	local data = DataService.get(player)
	if not data then
		return false, "Carregando..."
	end
	local info = ProgressService.rebirthInfo(data.rebirths)
	if not info then
		return false, "Você já tem o máximo de rebirths!"
	end
	if data.playerLevel < info.level then
		return false, "Precisa do nível " .. info.level .. " para o rebirth " .. info.number .. "."
	end
	if data.cash < info.cost then
		return false, "Precisa de $" .. fmt(info.cost) .. " para o rebirth " .. info.number .. "."
	end
	local before = unlockedSet(data)
	data.cash = Config.StartingCash
	data.rebirths += 1
	TycoonService.refreshPlayer(player)
	DataService.pushUpdate(player)
	announceNewAreas(player, before)
	Remotes.CompanionEvent:FireClient(player, "rebirth", data.rebirths)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			Remotes.notify(p, "♻ " .. player.DisplayName .. " fez o REBIRTH " .. data.rebirths .. "!", GOLD)
		end
	end
	return true, "♻ REBIRTH " .. data.rebirths .. "! +" .. math.floor(Config.Rebirth.IncomeBonus * 100)
		.. "% de renda, mais pedestais e itens novos na loja!"
end

---------------------------------------------------------------------
-- Iniciar
---------------------------------------------------------------------
function ProgressService.start()
	-- XP do jogador por derrotar brainrots
	WildService.onDefeated(function(state, player)
		ProgressService.giveXp(player, Stats.xpReward(state.def, state.level))
	end)

	-- chefões: todo mundo que bateu ganha a recompensa e desbloqueia a área
	WildService.onBossDefeated(function(cfg, contributors)
		local names = {}
		for player, damage in pairs(contributors) do
			if player.Parent == Players and DataService.get(player) and damage > 0 then
				table.insert(names, player.DisplayName)
				DataService.addCash(player, cfg.reward)
				ProgressService.giveXp(player, cfg.xp)
				ProgressService.markBoss(player, cfg.id)
				Remotes.CompanionEvent:FireClient(player, "boss", cfg.name, cfg.reward)
			end
		end
		local text = "👑 O chefão " .. cfg.name .. " foi derrotado"
			.. (if #names > 0 then " por " .. table.concat(names, ", ") else "") .. "! Volta em " .. cfg.respawn .. "s."
		for _, p in ipairs(Players:GetPlayers()) do
			Remotes.notify(p, text, GOLD)
		end
	end)

	-- não deixa entrar em área trancada
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				local biome = hrp and Stats.biomeAt(hrp.Position)
				if biome then
					local ok, why = ProgressService.canEnter(player, biome)
					if not ok then
						if biome.id == "Ceu" then
							character:PivotTo(hubCFrame())
						else
							local c = biome.center
							local pos = hrp.Position
							local dx, dz = pos.X - c.X, pos.Z - c.Z
							local hx, hz = biome.size.X / 2, biome.size.Y / 2
							local x, z = pos.X, pos.Z
							if hx - math.abs(dx) < hz - math.abs(dz) then
								x = c.X + (if dx >= 0 then 1 else -1) * (hx + 8)
							else
								z = c.Z + (if dz >= 0 then 1 else -1) * (hz + 8)
							end
							character:PivotTo(CFrame.new(x, c.Y + 5, z))
						end
						local now = os.clock()
						if not lastWarning[player] or now - lastWarning[player] > 3 then
							lastWarning[player] = now
							Remotes.notify(player, "🔒 " .. biome.icon .. " " .. biome.name .. " está trancado: " .. (why or ""), RED)
						end
					end
				end
			end
		end
	end)

	-- portais do Céu Celestial
	local debounce = {}
	local function portal(name: string, action)
		local pad = workspace:FindFirstChild(name, true)
		if pad and pad:IsA("BasePart") then
			pad.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player or debounce[player] then
					return
				end
				debounce[player] = true
				action(player)
				task.delay(2, function()
					debounce[player] = nil
				end)
			end)
		end
	end
	portal("PortalCeu", function(player)
		local ok, msg = ProgressService.teleportTo(player, "Ceu")
		Remotes.notify(player, msg, if ok then GOLD else RED)
	end)
	portal("PortalVolta", function(player)
		ProgressService.teleportHub(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastWarning[player] = nil
	end)
end

return ProgressService
