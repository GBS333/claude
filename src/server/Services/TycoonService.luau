-- Bases dos jogadores (o "tycoon"): pedestais onde você coloca seus brainrots
-- capturados. Cada brainrot gera dinheiro por segundo, que vai para o coletor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
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

-- posições dos 12 pedestais (frente da base = +Z)
local SLOT_COLUMNS = { -21, -7, 7, 21 }
local SLOT_ROWS = { 6, -8, -22 }
local BASE_TOP = 1
local PEDESTAL_HEIGHT = 2

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

local function buildPlot(index: number, info)
	local cf = CFrame.new(info.position) * CFrame.Angles(0, math.rad(info.angle), 0)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local colors = {
		Color3.fromRGB(240, 120, 120), Color3.fromRGB(120, 170, 255), Color3.fromRGB(130, 220, 130),
		Color3.fromRGB(255, 210, 100), Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 160, 210),
	}
	local color = colors[(index - 1) % #colors + 1]

	part(model, {
		Name = "Base", Size = Vector3.new(T.PlotSize, 1, T.PlotSize), CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(225, 225, 225), Material = Enum.Material.SmoothPlastic,
	})
	-- borda colorida
	part(model, {
		Name = "Border", Size = Vector3.new(T.PlotSize + 2, 0.8, T.PlotSize + 2), CFrame = cf * CFrame.new(0, 0.3, 0),
		Color = color, Material = Enum.Material.SmoothPlastic,
	})

	-- placa com o nome do dono
	local signBoard = part(model, {
		Name = "OwnerSign", Size = Vector3.new(34, 8, 1), CFrame = cf * CFrame.new(0, 9, -T.PlotSize / 2 + 2),
		Color = color, Material = Enum.Material.SmoothPlastic,
	})
	part(model, {
		Name = "SignPole", Size = Vector3.new(1, 9, 1), CFrame = cf * CFrame.new(-16, 4.5, -T.PlotSize / 2 + 2), Color = color,
	})
	part(model, {
		Name = "SignPole", Size = Vector3.new(1, 9, 1), CFrame = cf * CFrame.new(16, 4.5, -T.PlotSize / 2 + 2), Color = color,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Back -- a face de trás (+Z) aponta para a frente da base
	signGui.CanvasSize = Vector2.new(680, 160)
	signGui.LightInfluence = 0
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.TextStrokeTransparency = 0
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.Text = "Base livre"
	signLabel.Parent = signGui
	signGui.Parent = signBoard

	-- coletor de dinheiro
	local collector = part(model, {
		Name = "Collector", Size = Vector3.new(10, 0.4, 10), CFrame = cf * CFrame.new(0, BASE_TOP + 0.2, 24),
		Color = Color3.fromRGB(60, 230, 90), Material = Enum.Material.Neon,
	})
	local collectorLabel = billboard(collector, 4, 220, 70)

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
		spawnCF = cf * CFrame.new(0, 4, 32) * CFrame.Angles(0, math.pi, 0),
	}

	-- pedestais
	local n = 0
	for _, z in ipairs(SLOT_ROWS) do
		for _, x in ipairs(SLOT_COLUMNS) do
			n += 1
			if n > T.SlotCount then
				break
			end
			local slotCF = cf * CFrame.new(x, BASE_TOP + PEDESTAL_HEIGHT / 2, z)
			local pedestal = part(model, {
				Name = "Pedestal" .. n, Shape = Enum.PartType.Cylinder, Size = Vector3.new(PEDESTAL_HEIGHT, 8, 8),
				CFrame = slotCF * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 90, 100),
			})
			local prompt = Instance.new("ProximityPrompt")
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 10
			prompt.HoldDuration = 0.25
			prompt.Enabled = false
			prompt.Parent = pedestal

			local slot = {
				index = n,
				part = pedestal,
				topCF = cf * CFrame.new(x, BASE_TOP + PEDESTAL_HEIGHT, z) * CFrame.Angles(0, math.pi, 0),
				prompt = prompt,
				label = billboard(pedestal, 6, 200, 50),
				display = nil,
			}
			plot.slots[n] = slot

			prompt.Triggered:Connect(function(player)
				TycoonService.onSlotPrompt(player, plot, slot)
			end)
		end
	end

	-- tocar no coletor
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

local function refreshSlot(plot, slot)
	if slot.display then
		slot.display:Destroy()
		slot.display = nil
	end

	local owner = plot.owner
	local data = owner and DataService.get(owner)
	local prompt = slot.prompt

	if not data then
		slot.part.Color = Color3.fromRGB(90, 90, 100)
		slot.part.Material = Enum.Material.SmoothPlastic
		slot.label.Text = ""
		prompt.Enabled = false
		return
	end

	if slot.index > data.unlockedSlots then
		local price = T.SlotPrices[slot.index] or 0
		slot.part.Color = Color3.fromRGB(70, 70, 75)
		slot.part.Material = Enum.Material.SmoothPlastic
		if slot.index == data.unlockedSlots + 1 then
			slot.label.Text = "🔒 Desbloquear\n<font color=\"#7CFF7C\">$" .. fmt(price) .. "</font>"
			prompt.ActionText = "Desbloquear"
			prompt.ObjectText = "$" .. fmt(price)
			prompt.Enabled = true
		else
			slot.label.Text = "🔒"
			prompt.Enabled = false
		end
		return
	end

	local item = itemInSlot(data, slot.index)
	slot.part.Material = Enum.Material.Neon
	if item then
		local def = Config.getBrainrot(item.id)
		local rarity = Config.getRarity(def.rarity)
		slot.part.Color = rarity.color

		local model = BrainrotModels.build(def, 0.9)
		local hip = model:GetAttribute("HipHeight") or def.size.Y / 2
		model:PivotTo(slot.topCF * CFrame.new(0, hip, 0))
		model.Parent = plot.model
		slot.display = model

		slot.label.Text = def.name .. "\n<font color=\"#7CFF7C\">+$" .. fmt(def.income) .. "/s</font>"
		prompt.ActionText = "Guardar"
		prompt.ObjectText = def.name
		prompt.Enabled = true
	else
		slot.part.Color = Color3.fromRGB(180, 180, 190)
		slot.label.Text = "Vazio"
		prompt.ActionText = "Colocar Brainrot"
		prompt.ObjectText = "Pedestal " .. slot.index
		prompt.Enabled = true
	end
	slot.label.Parent.StudsOffsetWorldSpace = Vector3.new(0, if item then 8 else 3, 0)
end

local function refreshPlot(plot)
	for _, slot in ipairs(plot.slots) do
		refreshSlot(plot, slot)
	end
	if plot.owner then
		plot.signLabel.Text = "Base de " .. plot.owner.DisplayName
	else
		plot.signLabel.Text = "Base livre"
	end
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
				total += def.income
			end
		end
	end
	return total
end

local function updateCollectorLabel(plot)
	if plot.owner then
		plot.collectorLabel.Text = "💰 $" .. fmt(plot.stored) .. "\n<font color=\"#BFFFBF\">+$" .. fmt(getIncome(plot.owner)) .. "/s  (pise aqui)</font>"
	else
		plot.collectorLabel.Text = ""
	end
end

---------------------------------------------------------------------
-- Ações do jogador
---------------------------------------------------------------------
function TycoonService.getPlot(player: Player)
	return plotByPlayer[player]
end

function TycoonService.getIncome(player: Player): number
	return getIncome(player)
end

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
	else
		-- escolhe o que dá mais dinheiro
		local bestIncome = -1
		for _, candidate in ipairs(data.inventory) do
			local def = Config.getBrainrot(candidate.id)
			if not candidate.slot and def and def.income > bestIncome then
				item, bestIncome = candidate, def.income
			end
		end
		if not item then
			return false, "Você não tem brainrots guardados. Vá caçar na Zona de Caça!"
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
	return true, Config.getBrainrot(item.id).name .. " colocado no pedestal " .. slotIndex .. "!"
end

function TycoonService.store(player: Player, uid: string)
	local item = DataService.findItem(player, uid)
	local plot = plotByPlayer[player]
	if not item or not item.slot then
		return false, "Esse brainrot não está em um pedestal."
	end
	local slotIndex = item.slot
	item.slot = nil
	if plot then
		refreshSlot(plot, plot.slots[slotIndex])
		updateCollectorLabel(plot)
	end
	DataService.pushUpdate(player)
	return true, Config.getBrainrot(item.id).name .. " guardado."
end

-- Chamado quando um brainrot é vendido (pode estar em um pedestal)
function TycoonService.onItemRemoved(player: Player, item)
	local plot = plotByPlayer[player]
	if plot and item.slot and plot.slots[item.slot] then
		refreshSlot(plot, plot.slots[item.slot])
		updateCollectorLabel(plot)
	end
end

function TycoonService.onSlotPrompt(player: Player, plot, slot)
	if plot.owner ~= player then
		Remotes.notify(player, "Essa base não é sua!", Color3.fromRGB(255, 90, 90))
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
			ok, msg = TycoonService.place(player, nil, slot.index)
		end
	end
	if msg then
		Remotes.notify(player, msg, if ok then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 120, 120))
	end
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
			plotByPlayer[player] = plot

			-- conserta dados inválidos (pedestais repetidos ou bloqueados)
			if data then
				local used = {}
				for _, item in ipairs(data.inventory) do
					if item.slot then
						if item.slot > data.unlockedSlots or used[item.slot] then
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
	-- dinheiro que ficou no coletor vai para o jogador antes de salvar
	local data = DataService.get(player)
	if data and plot.stored >= 1 then
		data.cash += math.floor(plot.stored)
	end
	plotByPlayer[player] = nil
	plot.owner = nil
	plot.stored = 0
	refreshPlot(plot)
	updateCollectorLabel(plot)
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
end

return TycoonService
