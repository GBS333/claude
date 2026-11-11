-- Bases dos jogadores (o "tycoon"): pedestais onde você coloca seus brainrots
-- capturados. Cada brainrot gera dinheiro por segundo, que vai para o coletor.
-- Outros jogadores podem ROUBAR brainrots dos pedestais (veja StealService) e
-- o dono pode TRANCAR a base por um tempo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)
local BrainrotModels = require(script.Parent.BrainrotModels)
local Remotes = require(script.Parent.Remotes)

local TycoonService = {}

local T = Config.Tycoon
local fmt = CatchMath.formatNumber

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = workspace

local plots = {}
local plotByPlayer = {} -- [Player] = plot
local lockCooldown = {} -- [Player] = os.clock() em que pode trancar de novo

-- posições dos 20 pedestais (frente da base = +Z)
local SLOT_COLUMNS = { -28, -14, 0, 14, 28 }
local SLOT_ROWS = { 12, -2, -16, -30 }
local BASE_TOP = 1
local PEDESTAL_HEIGHT = 2

-- preenchido pelo StealService: function(thief, plot, slot)
TycoonService.stealHandler = nil

---------------------------------------------------------------------
-- Construção
---------------------------------------------------------------------
local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function billboard(adornee: BasePart, offsetY: number, width: number, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.Parent = gui
	gui.Parent = adornee
	return label
end

local function makePrompt(parent: Instance, role: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0.25
	prompt.Enabled = false
	prompt:SetAttribute("PromptRole", role) -- a interface esconde o que não é para você
	prompt.Parent = parent
	return prompt
end

local function buildPlot(index: number, info)
	local cf = CFrame.new(info.position) * CFrame.Angles(0, math.rad(info.angle), 0)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local colors = {
		Color3.fromRGB(240, 120, 120), Color3.fromRGB(120, 170, 255), Color3.fromRGB(130, 220, 130),
		Color3.fromRGB(255, 210, 100), Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 160, 210),
	}
	local color = colors[(index - 1) % #colors + 1]
	local half = T.PlotSize / 2

	part(model, {
		Name = "Base", Size = Vector3.new(T.PlotSize, 1, T.PlotSize), CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(230, 225, 215), Material = Enum.Material.Concrete,
	})
	part(model, {
		Name = "Floor", Size = Vector3.new(T.PlotSize - 6, 0.2, T.PlotSize - 12), CFrame = cf * CFrame.new(0, 1.05, -3),
		Color = Color3.fromRGB(205, 160, 110), Material = Enum.Material.WoodPlanks,
	})
	part(model, {
		Name = "Border", Size = Vector3.new(T.PlotSize + 2, 0.8, T.PlotSize + 2), CFrame = cf * CFrame.new(0, 0.3, 0),
		Color = color, Material = Enum.Material.SmoothPlastic,
	})
	local walls = {
		{ Vector3.new(T.PlotSize, 3, 1), CFrame.new(0, 2.5, -half + 0.5) },
		{ Vector3.new(1, 3, T.PlotSize), CFrame.new(-half + 0.5, 2.5, 0) },
		{ Vector3.new(1, 3, T.PlotSize), CFrame.new(half - 0.5, 2.5, 0) },
	}
	for _, w in ipairs(walls) do
		part(model, { Name = "Wall", Size = w[1], CFrame = cf * w[2], Color = Color3.fromRGB(235, 230, 220), Material = Enum.Material.Brick })
		part(model, {
			Name = "WallCap", Size = w[1] + Vector3.new(0.4, -2.6, 0.4), CFrame = cf * w[2] * CFrame.new(0, 1.7, 0),
			Color = color, Material = Enum.Material.SmoothPlastic,
		})
	end
	for _, s in ipairs({ -1, 1 }) do
		part(model, {
			Name = "LampPost", Size = Vector3.new(0.6, 9, 0.6), CFrame = cf * CFrame.new(s * (half - 2), 5.5, half - 2),
			Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal,
		})
		local bulb = part(model, {
			Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = cf * CFrame.new(s * (half - 2), 10.5, half - 2),
			Color = color, Material = Enum.Material.Neon, CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 18
		light.Parent = bulb
	end

	-- placa com o nome do dono
	local signBoard = part(model, {
		Name = "OwnerSign", Size = Vector3.new(34, 8, 1), CFrame = cf * CFrame.new(0, 10, -half + 2),
		Color = color, Material = Enum.Material.SmoothPlastic,
	})
	for _, x in ipairs({ -16, 16 }) do
		part(model, { Name = "SignPole", Size = Vector3.new(1, 10, 1), CFrame = cf * CFrame.new(x, 5, -half + 2), Color = color })
	end
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Back
	signGui.CanvasSize = Vector2.new(680, 160)
	signGui.LightInfluence = 0
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.TextStrokeTransparency = 0
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.RichText = true
	signLabel.Text = "Base livre"
	signLabel.Parent = signGui
	signGui.Parent = signBoard

	-- coletor de dinheiro
	local collector = part(model, {
		Name = "Collector", Size = Vector3.new(10, 0.4, 10), CFrame = cf * CFrame.new(0, BASE_TOP + 0.2, 26),
		Color = Color3.fromRGB(60, 230, 90), Material = Enum.Material.Neon,
	})
	local collectorLabel = billboard(collector, 4, 220, 70)

	-- campo de força da base trancada
	local lockField = part(model, {
		Name = "LockField", Size = Vector3.new(T.PlotSize, 16, T.PlotSize), CFrame = cf * CFrame.new(0, 8, 0),
		Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.ForceField, Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	})

	local plot = {
		index = index,
		cf = cf,
		model = model,
		owner = nil,
		stored = 0,
		slots = {},
		signLabel = signLabel,
		collector = collector,
		collectorLabel = collectorLabel,
		lockField = lockField,
		lockedUntil = 0,
		spawnCF = cf * CFrame.new(0, 4, 32) * CFrame.Angles(0, math.pi, 0),
		outsideCF = cf * CFrame.new(0, 4, half + 12) * CFrame.Angles(0, math.pi, 0),
	}

	-- pedestais
	local n = 0
	for _, z in ipairs(SLOT_ROWS) do
		for _, x in ipairs(SLOT_COLUMNS) do
			n += 1
			if n > T.SlotCount then
				break
			end
			local pedestal = part(model, {
				Name = "Pedestal" .. n, Shape = Enum.PartType.Cylinder, Size = Vector3.new(PEDESTAL_HEIGHT, 8, 8),
				CFrame = cf * CFrame.new(x, BASE_TOP + PEDESTAL_HEIGHT / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(235, 235, 240), Material = Enum.Material.Marble,
			})
			local ring = part(model, {
				Name = "PedestalRing" .. n, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 7, 7),
				CFrame = cf * CFrame.new(x, BASE_TOP + PEDESTAL_HEIGHT + 0.05, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(90, 90, 100), CanCollide = false,
			})
			local slot = {
				index = n,
				part = pedestal,
				ring = ring,
				topCF = cf * CFrame.new(x, BASE_TOP + PEDESTAL_HEIGHT, z) * CFrame.Angles(0, math.pi, 0),
				prompt = makePrompt(pedestal, "owner"),
				stealPrompt = makePrompt(pedestal, "steal"),
				label = billboard(pedestal, 6, 200, 50),
				display = nil,
				stolen = false,
			}
			slot.stealPrompt.ActionText = "Roubar"
			slot.stealPrompt.HoldDuration = Config.Steal.HoldDuration
			slot.stealPrompt.KeyboardKeyCode = Enum.KeyCode.F
			plot.slots[n] = slot

			slot.prompt.Triggered:Connect(function(player)
				TycoonService.onSlotPrompt(player, plot, slot)
			end)
			slot.stealPrompt.Triggered:Connect(function(player)
				if player ~= plot.owner and TycoonService.stealHandler then
					TycoonService.stealHandler(player, plot, slot)
				end
			end)
		end
	end

	local debounce = {}
	collector.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or player ~= plot.owner or debounce[player] then
			return
		end
		debounce[player] = true
		TycoonService.collect(player)
		task.delay(0.5, function()
			debounce[player] = nil
		end)
	end)

	model.Parent = plotsFolder
	return plot
end

---------------------------------------------------------------------
-- Atualizar visual
---------------------------------------------------------------------
local function itemInSlot(data, slotIndex: number)
	for _, item in ipairs(data.inventory) do
		if item.slot == slotIndex then
			return item
		end
	end
	return nil
end

local function isLocked(plot): boolean
	return os.clock() < plot.lockedUntil
end

local function refreshSlot(plot, slot)
	if slot.display then
		slot.display:Destroy()
		slot.display = nil
	end

	local owner = plot.owner
	local data = owner and DataService.get(owner)
	local prompt = slot.prompt
	slot.stealPrompt.Enabled = false

	local function setRing(color: Color3, glowing: boolean)
		slot.ring.Color = color
		slot.ring.Material = if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end

	if not data then
		setRing(Color3.fromRGB(90, 90, 100), false)
		slot.label.Text = ""
		prompt.Enabled = false
		return
	end

	local maxSlots = Stats.maxSlots(data.rebirths)
	if slot.index > data.unlockedSlots then
		setRing(Color3.fromRGB(70, 70, 75), false)
		prompt.Enabled = false
		if slot.index > maxSlots then
			slot.label.Text = "♻"
		elseif slot.index == data.unlockedSlots + 1 then
			local price = T.SlotPrices[slot.index] or 0
			slot.label.Text = "🔒 Desbloquear\n<font color=\"#7CFF7C\">$" .. fmt(price) .. "</font>"
			prompt.ActionText = "Desbloquear"
			prompt.ObjectText = "$" .. fmt(price)
			prompt.Enabled = true
		else
			slot.label.Text = "🔒"
		end
		slot.label.Parent.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		return
	end

	local item = itemInSlot(data, slot.index)
	if item and slot.stolen then
		setRing(Color3.fromRGB(255, 60, 60), true)
		slot.label.Text = "🚨 SENDO ROUBADO!"
		prompt.Enabled = false
	elseif item then
		local def = Config.getBrainrot(item.id)
		local rarity = Config.getRarity(def.rarity)
		local level = item.level or 1
		local name = Stats.displayName(def, level, item.mutation)
		setRing(rarity.color, true)

		local model = BrainrotModels.build(def, 0.9 * Stats.scale(level), Stats.stage(level), item.mutation)
		local hip = model:GetAttribute("HipHeight") or def.size.Y / 2
		model:PivotTo(slot.topCF * CFrame.new(0, hip, 0))
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanQuery = false
			end
		end
		model.Parent = plot.model
		slot.display = model

		local income = Stats.income(def, level, item.mutation) * Stats.rebirthIncomeMultiplier(data.rebirths)
		slot.label.Text = name .. " Lv." .. level .. "\n<font color=\"#7CFF7C\">+$" .. fmt(income) .. "/s</font>"
		prompt.ActionText = "Guardar"
		prompt.ObjectText = name
		prompt.Enabled = true
		slot.stealPrompt.ObjectText = name
		slot.stealPrompt.Enabled = not isLocked(plot)
	else
		setRing(Color3.fromRGB(200, 230, 255), true)
		slot.label.Text = "Vazio\n<font size=\"14\">segure um brainrot e clique</font>"
		prompt.ActionText = "Colocar Brainrot"
		prompt.ObjectText = "Pedestal " .. slot.index
		prompt.Enabled = true
	end
	local height = if item and not slot.stolen then 8 * Stats.scale(item.level or 1) else 3
	slot.label.Parent.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
end

local function refreshSign(plot)
	if not plot.owner then
		plot.signLabel.Text = "Base livre"
	elseif isLocked(plot) then
		plot.signLabel.Text = "Base de " .. plot.owner.DisplayName .. "\n<font color=\"#FF8080\">🔒 TRANCADA "
			.. math.ceil(plot.lockedUntil - os.clock()) .. "s</font>"
	else
		plot.signLabel.Text = "Base de " .. plot.owner.DisplayName
	end
end

local function refreshPlot(plot)
	plot.model:SetAttribute("OwnerUserId", if plot.owner then plot.owner.UserId else nil)
	for _, slot in ipairs(plot.slots) do
		refreshSlot(plot, slot)
	end
	refreshSign(plot)
end

local function getIncome(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, item in ipairs(data.inventory) do
		if item.slot then
			local def = Config.getBrainrot(item.id)
			if def then
				total += Stats.income(def, item.level or 1, item.mutation)
			end
		end
	end
	return total * Stats.rebirthIncomeMultiplier(data.rebirths)
end

local function updateCollectorLabel(plot)
	if plot.owner then
		plot.collectorLabel.Text = "💰 $" .. fmt(plot.stored) .. "\n<font color=\"#BFFFBF\">+$" .. fmt(getIncome(plot.owner)) .. "/s  (pise aqui)</font>"
	else
		plot.collectorLabel.Text = ""
	end
end

---------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------
function TycoonService.getPlot(player: Player)
	return plotByPlayer[player]
end

function TycoonService.getIncome(player: Player): number
	return getIncome(player)
end

function TycoonService.isInPlot(plot, position: Vector3): boolean
	local p = plot.cf:PointToObjectSpace(position)
	local half = T.PlotSize / 2
	return math.abs(p.X) <= half and math.abs(p.Z) <= half and p.Y > -5 and p.Y < 25
end

function TycoonService.getSlotItem(plot, slotIndex: number)
	local data = plot.owner and DataService.get(plot.owner)
	return data and itemInSlot(data, slotIndex)
end

function TycoonService.setSlotStolen(plot, slotIndex: number, stolen: boolean)
	local slot = plot.slots[slotIndex]
	if slot then
		slot.stolen = stolen
		refreshSlot(plot, slot)
		updateCollectorLabel(plot)
	end
end

-- O brainrot está sendo carregado por um ladrão agora?
function TycoonService.isItemStolen(player: Player, uid: string): boolean
	local plot = plotByPlayer[player]
	local item = DataService.findItem(player, uid)
	return plot ~= nil and item ~= nil and item.slot ~= nil and plot.slots[item.slot] ~= nil and plot.slots[item.slot].stolen
end

function TycoonService.isLocked(plot): boolean
	return isLocked(plot)
end

---------------------------------------------------------------------
-- Ações do jogador
---------------------------------------------------------------------
function TycoonService.refreshPlayer(player: Player)
	local plot = plotByPlayer[player]
	if plot then
		refreshPlot(plot)
		updateCollectorLabel(plot)
	end
end

function TycoonService.collect(player: Player)
	local plot = plotByPlayer[player]
	if not plot or plot.stored < 1 then
		return
	end
	local amount = math.floor(plot.stored)
	plot.stored -= amount
	DataService.addCash(player, amount)
	Remotes.notify(player, "Coletou $" .. fmt(amount) .. "!", Color3.fromRGB(100, 255, 120))
	updateCollectorLabel(plot)
end

function TycoonService.unlockNext(player: Player)
	local data = DataService.get(player)
	if not data then
		return false, "Dados não carregados"
	end
	local nextIndex = data.unlockedSlots + 1
	if nextIndex > T.SlotCount then
		return false, "Todos os pedestais já foram desbloqueados!"
	end
	if nextIndex > Stats.maxSlots(data.rebirths) then
		return false, "Faça REBIRTH ♻ para liberar mais pedestais!"
	end
	local price = T.SlotPrices[nextIndex] or 0
	if not DataService.spendCash(player, price) then
		return false, "Você precisa de $" .. fmt(price) .. " para desbloquear."
	end
	data.unlockedSlots = nextIndex
	TycoonService.refreshPlayer(player)
	DataService.pushUpdate(player)
	return true, "Pedestal " .. nextIndex .. " desbloqueado!"
end

-- Coloca um brainrot do inventário em um pedestal (o primeiro livre se slotIndex for nil)
function TycoonService.place(player: Player, uid: string?, slotIndex: number?)
	local data = DataService.get(player)
	local plot = plotByPlayer[player]
	if not data or not plot then
		return false, "Você não tem uma base."
	end

	local item
	if uid then
		item = DataService.findItem(player, uid)
		if not item then
			return false, "Brainrot não encontrado."
		end
		if item.slot then
			return false, "Esse brainrot já está em um pedestal."
		end
		if item.uid == data.companion then
			return false, "Esse é o seu parceiro de batalha! Guarde ele antes."
		end
	else
		local bestIncome = -1
		for _, candidate in ipairs(data.inventory) do
			local def = Config.getBrainrot(candidate.id)
			local income = def and Stats.income(def, candidate.level or 1, candidate.mutation)
			if not candidate.slot and candidate.uid ~= data.companion and def and income > bestIncome then
				item, bestIncome = candidate, income
			end
		end
		if not item then
			return false, "Você não tem brainrots guardados. Vá caçar!"
		end
	end

	if not slotIndex then
		for i = 1, data.unlockedSlots do
			if not itemInSlot(data, i) then
				slotIndex = i
				break
			end
		end
		if not slotIndex then
			return false, "Todos os pedestais estão ocupados. Desbloqueie mais!"
		end
	elseif slotIndex > data.unlockedSlots or itemInSlot(data, slotIndex) then
		return false, "Esse pedestal não está disponível."
	end

	item.slot = slotIndex
	refreshSlot(plot, plot.slots[slotIndex])
	updateCollectorLabel(plot)
	DataService.pushUpdate(player)
	return true, Stats.displayName(Config.getBrainrot(item.id), item.level or 1, item.mutation) .. " colocado no pedestal " .. slotIndex .. "!"
end

function TycoonService.store(player: Player, uid: string)
	local item = DataService.findItem(player, uid)
	local plot = plotByPlayer[player]
	if not item or not item.slot then
		return false, "Esse brainrot não está em um pedestal."
	end
	if TycoonService.isItemStolen(player, uid) then
		return false, "Ele está sendo roubado! Bata no ladrão!"
	end
	local slotIndex = item.slot
	item.slot = nil
	if plot then
		refreshSlot(plot, plot.slots[slotIndex])
		updateCollectorLabel(plot)
	end
	DataService.pushUpdate(player)
	return true, Stats.displayName(Config.getBrainrot(item.id), item.level or 1, item.mutation) .. " guardado."
end

-- Chamado quando um brainrot sai do inventário (vendido, trocado, roubado...)
function TycoonService.onItemRemoved(player: Player, item)
	local plot = plotByPlayer[player]
	if plot and item.slot and plot.slots[item.slot] then
		plot.slots[item.slot].stolen = false
		refreshSlot(plot, plot.slots[item.slot])
		updateCollectorLabel(plot)
	end
end

function TycoonService.onSlotPrompt(player: Player, plot, slot)
	if plot.owner ~= player then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local ok, msg
	if slot.index > data.unlockedSlots then
		ok, msg = TycoonService.unlockNext(player)
	else
		local item = itemInSlot(data, slot.index)
		if item then
			ok, msg = TycoonService.store(player, item.uid)
		else
			local character = player.Character
			local held = character and character:FindFirstChildOfClass("Tool")
			local heldUid = held and held:GetAttribute("BrainrotUid")
			ok, msg = TycoonService.place(player, heldUid, slot.index)
		end
	end
	if msg then
		Remotes.notify(player, msg, if ok then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 120, 120))
	end
end

-- Trancar a base: ninguém entra nem rouba por um tempo
function TycoonService.lock(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return false, "Você não tem uma base."
	end
	local now = os.clock()
	if lockCooldown[player] and now < lockCooldown[player] then
		return false, "Você pode trancar de novo em " .. math.ceil(lockCooldown[player] - now) .. "s."
	end
	plot.lockedUntil = now + T.LockDuration
	lockCooldown[player] = now + T.LockCooldown
	plot.lockField.Transparency = 0.6
	refreshPlot(plot)
	return true, "🔒 Base trancada por " .. T.LockDuration .. "s!"
end

---------------------------------------------------------------------
-- Entrar / sair
---------------------------------------------------------------------
function TycoonService.assign(player: Player)
	local data = DataService.get(player)
	for _, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			plot.stored = 0
			plot.lockedUntil = 0
			plot.lockField.Transparency = 1
			plotByPlayer[player] = plot
			for _, slot in ipairs(plot.slots) do
				slot.stolen = false
			end

			if data then
				local used = {}
				for _, item in ipairs(data.inventory) do
					if item.slot then
						if item.slot > data.unlockedSlots or used[item.slot] or item.uid == data.companion then
							item.slot = nil
						else
							used[item.slot] = true
						end
					end
				end
			end

			refreshPlot(plot)
			updateCollectorLabel(plot)
			return plot
		end
	end
	Remotes.notify(player, "Todas as bases estão ocupadas neste servidor :(", Color3.fromRGB(255, 120, 120))
	return nil
end

function TycoonService.release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local data = DataService.get(player)
	if data and plot.stored >= 1 then
		data.cash += math.floor(plot.stored)
	end
	plotByPlayer[player] = nil
	lockCooldown[player] = nil
	plot.owner = nil
	plot.stored = 0
	plot.lockedUntil = 0
	plot.lockField.Transparency = 1
	for _, slot in ipairs(plot.slots) do
		slot.stolen = false
	end
	refreshPlot(plot)
	updateCollectorLabel(plot)
end

function TycoonService.findFreeSlotNear(player: Player, position: Vector3, maxDistance: number): number?
	local plot = plotByPlayer[player]
	local data = DataService.get(player)
	if not plot or not data then
		return nil
	end
	local best, bestDist = nil, maxDistance
	for i = 1, math.min(data.unlockedSlots, #plot.slots) do
		if not itemInSlot(data, i) then
			local offset = plot.slots[i].topCF.Position - position
			local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if dist <= bestDist then
				best, bestDist = i, dist
			end
		end
	end
	return best
end

function TycoonService.teleportHome(player: Player)
	local plot = plotByPlayer[player]
	local character = player.Character
	if plot and character then
		character:PivotTo(plot.spawnCF)
	end
end

function TycoonService.start()
	for i, info in ipairs(T.Plots) do
		plots[i] = buildPlot(i, info)
		refreshPlot(plots[i])
	end

	-- renda passiva
	task.spawn(function()
		while true do
			task.wait(T.IncomeTick)
			for _, plot in ipairs(plots) do
				if plot.owner then
					plot.stored += getIncome(plot.owner) * T.IncomeTick
					updateCollectorLabel(plot)
				end
			end
		end
	end)

	-- bases trancadas: expulsa quem não é dono e atualiza a placa
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, plot in ipairs(plots) do
				if plot.owner and plot.lockedUntil > 0 then
					if isLocked(plot) then
						refreshSign(plot)
						for _, other in ipairs(Players:GetPlayers()) do
							local hrp = other ~= plot.owner and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
							if hrp and TycoonService.isInPlot(plot, hrp.Position) then
								other.Character:PivotTo(plot.outsideCF)
								Remotes.notify(other, "Essa base está trancada! 🔒", Color3.fromRGB(255, 120, 120))
							end
						end
					else
						plot.lockedUntil = 0
						plot.lockField.Transparency = 1
						refreshPlot(plot)
					end
				end
			end
		end
	end)
end

return TycoonService
