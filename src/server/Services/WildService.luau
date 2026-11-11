-- Brainrots selvagens e CHEFÕES.
-- Cada brainrot nasce no bioma dele, anda, apanha, fica bravo e ataca, regenera
-- e desmaia se a vida zerar. Durante eventos alguns nascem com mutações.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local Stats = require(ReplicatedStorage.Shared.Stats)
local BrainrotModels = require(script.Parent.BrainrotModels)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local WildService = {}

local WILD = Config.Wild
local BOSS = Config.Boss
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "WildBrainrots"
folder.Parent = workspace

local states = {} -- [Model] = estado
local biomeCounts = {} -- [biomeId] = quantos vivos
local bossStates = {} -- [bossId] = estado (se vivo)

-- evento atual (preenchido pelo EventService)
WildService.currentEvent = nil

---------------------------------------------------------------------
-- Avisos para outros sistemas (evita require circular)
---------------------------------------------------------------------
local listeners = { defeated = {}, bossDefeated = {}, playerAttacked = {}, bossSlam = {} }
local function fire(kind: string, ...)
	for _, fn in ipairs(listeners[kind]) do
		task.spawn(fn, ...)
	end
end
function WildService.onDefeated(fn) -- (state, player)
	table.insert(listeners.defeated, fn)
end
function WildService.onBossDefeated(fn) -- (bossConfig, contributors { [Player] = dano })
	table.insert(listeners.bossDefeated, fn)
end
function WildService.onPlayerAttacked(fn) -- (player, state)
	table.insert(listeners.playerAttacked, fn)
end
function WildService.onBossSlam(fn) -- (position, radius, damage, state)
	table.insert(listeners.bossSlam, fn)
end

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function randomPoint(biome, margin: number?): Vector3
	margin = margin or 8
	local c = biome.center
	local hx, hz = biome.size.X / 2 - margin, biome.size.Y / 2 - margin
	return Vector3.new(c.X + rng:NextNumber(-hx, hx), c.Y, c.Z + rng:NextNumber(-hz, hz))
end

local function clampToBiome(biome, p: Vector3): Vector3
	local c = biome.center
	local hx, hz = biome.size.X / 2 - 3, biome.size.Y / 2 - 3
	return Vector3.new(math.clamp(p.X, c.X - hx, c.X + hx), c.Y, math.clamp(p.Z, c.Z - hz, c.Z + hz))
end

local function clampState(state, p: Vector3): Vector3
	p = clampToBiome(state.biome, p)
	if state.boss then
		local offset = flat(p - state.home)
		local limit = BOSS.WanderRadius + 25
		if offset.Magnitude > limit then
			p = state.home + offset.Unit * limit
		end
	end
	return p
end

local function pickDef(biome)
	local pool = {}
	for _, def in ipairs(Config.Brainrots) do
		if def.biome == biome.id then
			table.insert(pool, def)
		end
	end
	if #pool == 0 then
		return nil
	end
	-- sorteia a raridade (só as que existem nesse bioma), depois o brainrot
	local total = 0
	local present = {}
	for _, name in ipairs(Config.RarityOrder) do
		for _, def in ipairs(pool) do
			if def.rarity == name then
				present[name] = true
				total += Config.Rarities[name].spawnWeight
				break
			end
		end
	end
	local roll = rng:NextNumber(0, total)
	local chosen
	for _, name in ipairs(Config.RarityOrder) do
		if present[name] then
			chosen = name
			roll -= Config.Rarities[name].spawnWeight
			if roll <= 0 then
				break
			end
		end
	end
	local options = {}
	for _, def in ipairs(pool) do
		if def.rarity == chosen then
			table.insert(options, def)
		end
	end
	return options[rng:NextInteger(1, #options)]
end

local function rollMutation(): string?
	local event = WildService.currentEvent
	if event and rng:NextNumber() < event.chance then
		return event.mutation
	end
	for _, id in ipairs(Config.MutationOrder) do
		local m = Config.Mutations[id]
		if m.chance and rng:NextNumber() < m.chance then
			return id
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Barra de vida
---------------------------------------------------------------------
local function nameText(state): string
	if state.boss then
		return "👑 " .. state.boss.name
	end
	return Stats.displayName(state.def, 1, state.mutation) .. "  Lv." .. state.level
end

local function createBillboard(state)
	local def = state.def
	local rarity = Config.getRarity(def.rarity)
	local isBoss = state.boss ~= nil
	local height = state.model:GetAttribute("HipHeight") or def.size.Y / 2

	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = if isBoss then UDim2.fromOffset(320, 80) else UDim2.fromOffset(190, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 3, 0)
	gui.MaxDistance = if isBoss then 250 else 110
	gui.LightInfluence = 0
	gui.Adornee = state.model.PrimaryPart

	local name = Instance.new("TextLabel")
	name.Name = "NameLabel"
	name.Size = UDim2.new(1, 0, 0, if isBoss then 30 else 20)
	name.BackgroundTransparency = 1
	name.Text = nameText(state)
	name.TextColor3 = if isBoss then Color3.fromRGB(255, 80, 80) else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Position = UDim2.fromOffset(0, if isBoss then 30 else 20)
	rarityLabel.Size = UDim2.new(1, 0, 0, if isBoss then 20 else 16)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = if isBoss then "CHEFÃO • não dá para capturar" else rarity.display
	rarityLabel.TextColor3 = if isBoss then Color3.fromRGB(255, 200, 80) else rarity.color
	rarityLabel.TextStrokeTransparency = 0.3
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextScaled = true
	rarityLabel.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(15, if isBoss then 54 else 40)
	back.Size = UDim2.new(1, -30, 0, if isBoss then 20 else 12)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

	local hpText = Instance.new("TextLabel")
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextStrokeTransparency = 0.2
	hpText.Font = Enum.Font.GothamBold
	hpText.TextScaled = true
	hpText.ZIndex = 2
	hpText.Parent = back

	gui.Parent = state.model
	state.gui = gui
	state.nameLabel = name
	state.fill = fill
	state.hpText = hpText
end

local function updateHealthBar(state)
	local ratio = math.clamp(state.health / state.maxHealth, 0, 1)
	state.fill.Size = UDim2.fromScale(ratio, 1)
	if state.boss then
		state.fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	elseif ratio > 0.5 then
		state.fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	elseif ratio > 0.2 then
		state.fill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	else
		state.fill.BackgroundColor3 = Color3.fromRGB(240, 60, 60)
	end
	state.hpText.Text = CatchMath.formatNumber(math.ceil(state.health)) .. " / " .. CatchMath.formatNumber(state.maxHealth)
	state.model:SetAttribute("Health", state.health)
	state.model:SetAttribute("MaxHealth", state.maxHealth)
end

---------------------------------------------------------------------
-- Efeitos
---------------------------------------------------------------------
local function floatingText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui

	TweenService:Create(anchor, TweenInfo.new(0.9), { CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end
WildService.floatingText = floatingText

function WildService.poof(position: Vector3, color: Color3, amount: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(position)
	p.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.LightEmission = 0.6
	emitter.Parent = p
	emitter:Emit(amount or 35)
	Debris:AddItem(p, 1.5)
end

function WildService.shockwave(position: Vector3, radius: number, color: Color3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.45), { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.5)
end

local function flash(state)
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 60, 60)
	h.FillTransparency = 0.3
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = state.model
	Debris:AddItem(h, 0.15)
end

-- Empurra um jogador (o empurrão é aplicado no computador dele)
function WildService.knockbackPlayer(player: Player, fromPosition: Vector3, strength: number)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or character:FindFirstChildOfClass("ForceField") then
		return
	end
	local dir = flat(hrp.Position - fromPosition)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(1, 0, 0)
	Remotes.Knockback:FireClient(player, dir * strength + Vector3.new(0, strength * 0.45, 0))
end

---------------------------------------------------------------------
-- Ciclo de vida
---------------------------------------------------------------------
local function recordTransparency(state)
	state.transparency = {}
	for _, d in ipairs(state.model:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			state.transparency[d] = d.Transparency
		end
	end
end

local function newState(def, biome, level: number, mutation: string?, bossCfg)
	local scale = if bossCfg then bossCfg.scale else 1
	local model = BrainrotModels.build(def, scale, if bossCfg then 3 else 1, mutation)
	local maxHealth = if bossCfg then bossCfg.maxHealth else Stats.maxHealth(def, level, 1, mutation)
	local state = {
		def = def,
		model = model,
		biome = biome,
		boss = bossCfg,
		level = level,
		mutation = mutation,
		maxHealth = maxHealth,
		power = if bossCfg then bossCfg.damage else Stats.power(def, level, 1, mutation),
		health = maxHealth,
		position = randomPoint(biome),
		yaw = rng:NextNumber(0, math.pi * 2),
		target = nil,
		idleUntil = 0,
		lastDamage = 0,
		lastAttack = 0,
		lastSlam = os.clock(),
		aggroPlayer = nil,
		aggroCompanion = nil,
		aggroUntil = 0,
		capturing = false,
		hipHeight = model:GetAttribute("HipHeight") or def.size.Y / 2 * scale,
		phase = rng:NextNumber(0, 10),
		contributors = {},
		active = true,
		nextActiveCheck = 0,
	}
	if bossCfg then
		state.home = Vector3.new(bossCfg.position.X, biome.center.Y, bossCfg.position.Z)
		state.position = state.home
	end
	recordTransparency(state)

	model:SetAttribute("BrainrotId", def.id)
	model:SetAttribute("Level", level)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("IsBoss", bossCfg ~= nil)
	model:PivotTo(CFrame.new(state.position + Vector3.new(0, state.hipHeight, 0)) * CFrame.Angles(0, state.yaw, 0))
	model.Parent = folder
	createBillboard(state)
	updateHealthBar(state)
	states[model] = state
	return state
end

local function spawnOne(biome)
	local def = pickDef(biome)
	if not def then
		return nil
	end
	local range = Config.getRarity(def.rarity).wildLevels or { 1, 1 }
	local state = newState(def, biome, rng:NextInteger(range[1], range[2]), rollMutation(), nil)
	biomeCounts[biome.id] = (biomeCounts[biome.id] or 0) + 1
	WildService.poof(state.position + Vector3.new(0, 2, 0), Config.getRarity(def.rarity).color)
	return state
end

local function despawn(state)
	if not states[state.model] then
		return
	end
	states[state.model] = nil
	if state.boss then
		bossStates[state.boss.id] = nil
	else
		biomeCounts[state.biome.id] = math.max(0, (biomeCounts[state.biome.id] or 1) - 1)
	end
	state.model:Destroy()
end

function WildService.spawnBoss(bossId: string)
	local cfg = Config.getBoss(bossId)
	if not cfg or bossStates[bossId] then
		return nil
	end
	local def = Config.getBrainrot(cfg.brainrot)
	local biome = Config.getBiome(cfg.biome)
	if not def or not biome then
		warn("[WildService] chefão mal configurado: " .. bossId)
		return nil
	end
	local state = newState(def, biome, 50, nil, cfg)
	bossStates[bossId] = state
	WildService.poof(state.position + Vector3.new(0, 6, 0), Color3.fromRGB(255, 60, 60), 80)
	for _, p in ipairs(Players:GetPlayers()) do
		Remotes.notify(p, "👑 O chefão " .. cfg.name .. " apareceu em " .. biome.name .. "!", Color3.fromRGB(255, 120, 90))
	end
	return state
end

local function bossDied(state)
	local cfg = state.boss
	WildService.poof(state.model:GetPivot().Position, Color3.fromRGB(255, 220, 80), 120)
	local contributors = state.contributors
	despawn(state)
	fire("bossDefeated", cfg, contributors)
	task.delay(cfg.respawn, function()
		WildService.spawnBoss(cfg.id)
	end)
end

local function faint(state, player: Player?)
	if state.boss then
		bossDied(state)
		return
	end
	local def = state.def
	local rarity = Config.getRarity(def.rarity)
	WildService.poof(state.model:GetPivot().Position, rarity.color)
	despawn(state)
	if player then
		local reward = math.floor(rarity.faintReward * (1 + 0.25 * (state.level - 1)) * Stats.mutationMult(state.mutation, "income"))
		DataService.addCash(player, reward)
		Remotes.notify(player, Stats.displayName(def, 1, state.mutation) .. " Lv." .. state.level .. " foi derrotado! +$"
			.. CatchMath.formatNumber(reward), Color3.fromRGB(255, 170, 60))
		fire("defeated", state, player)
	end
end

-- Muda a mutação de um selvagem vivo (usado quando um evento começa)
function WildService.setMutation(state, mutationId: string)
	if not WildService.isAlive(state) or state.boss or state.capturing then
		return
	end
	local ratio = state.health / state.maxHealth
	state.mutation = mutationId
	state.maxHealth = Stats.maxHealth(state.def, state.level, 1, mutationId)
	state.power = Stats.power(state.def, state.level, 1, mutationId)
	state.health = state.maxHealth * ratio
	local old = state.model:FindFirstChild("Mutation")
	if old then
		old:Destroy()
	end
	local oldParticles = state.model.PrimaryPart and state.model.PrimaryPart:FindFirstChild("MutationParticles")
	if oldParticles then
		oldParticles:Destroy()
	end
	BrainrotModels.applyMutation(state.model, mutationId)
	state.model:SetAttribute("Mutation", mutationId)
	state.nameLabel.Text = nameText(state)
	updateHealthBar(state)
	WildService.poof(state.position + Vector3.new(0, 2, 0), Config.getMutation(mutationId).color)
end

function WildService.forEachWild(fn)
	for _, state in pairs(states) do
		if not state.boss then
			fn(state)
		end
	end
end

---------------------------------------------------------------------
-- API usada pelo taco, bolas e parceiro
---------------------------------------------------------------------
function WildService.getStateFromPart(part: Instance)
	local model = part
	while model and model.Parent ~= folder do
		model = model.Parent
	end
	if model then
		return states[model]
	end
	return nil
end

function WildService.getStateFromModel(model: Instance)
	return states[model]
end

function WildService.isAlive(state): boolean
	return state ~= nil and states[state.model] == state
end

function WildService.isBoss(state): boolean
	return state ~= nil and state.boss ~= nil
end

function WildService.radius(state): number
	local scale = if state.boss then state.boss.scale else 1
	return state.def.size.X / 2 * scale
end

-- Acha o brainrot mais perto na frente do jogador
function WildService.findTargetInFront(player: Player, range: number)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil, nil
	end
	local best, bestDist = nil, math.huge
	for _, state in pairs(states) do
		if not state.capturing then
			local pos = state.model:GetPivot().Position
			local offset = flat(pos - hrp.Position)
			local dist = offset.Magnitude - WildService.radius(state)
			if dist <= range and math.abs(pos.Y - hrp.Position.Y) < 12 + state.hipHeight then
				local facing = offset.Magnitude < 0.1 or flat(hrp.CFrame.LookVector).Unit:Dot(offset.Unit) > 0.2
				if facing and dist < bestDist then
					best, bestDist = state, dist
				end
			end
		end
	end
	return best, bestDist
end

-- companion = o parceiro que bateu (ou nil se foi o jogador)
function WildService.damage(state, amount: number, player: Player?, companion: any?)
	if not WildService.isAlive(state) or state.capturing then
		return
	end
	amount = math.max(1, math.floor(amount + 0.5))
	state.health -= amount
	state.lastDamage = os.clock()
	if player then
		state.contributors[player] = (state.contributors[player] or 0) + amount
	end
	flash(state)
	floatingText(state.model:GetPivot().Position + Vector3.new(0, state.hipHeight + 1, 0), "-" .. amount, Color3.fromRGB(255, 80, 80))

	if state.health <= 0 then
		state.health = 0
		faint(state, player)
		return
	end
	updateHealthBar(state)

	local sourcePosition
	if companion and companion:isAlive() then
		state.aggroCompanion = companion
		state.aggroPlayer = nil
		state.aggroUntil = os.clock() + WILD.AggroTime
		sourcePosition = companion:getPosition()
	elseif player then
		state.aggroPlayer = player
		state.aggroCompanion = nil
		state.aggroUntil = os.clock() + WILD.AggroTime
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		sourcePosition = hrp and hrp.Position
	end
	if sourcePosition and not state.boss then
		local away = flat(state.position - sourcePosition)
		if away.Magnitude > 0.1 then
			state.position = clampState(state, state.position + away.Unit * WILD.Knockback)
		end
	end
end

function WildService.getChance(state, ballMultiplier: number): number
	if state.boss then
		return 0
	end
	return CatchMath.getChance(state.def.catchRate, state.health, state.maxHealth, ballMultiplier)
end

function WildService.setCapturing(state, capturing: boolean)
	state.capturing = capturing
	for part, original in pairs(state.transparency) do
		if part.Parent then
			part.Transparency = if capturing then 1 else original
		end
	end
	for _, d in ipairs(state.model:GetDescendants()) do
		if d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = not capturing
		end
	end
	if state.gui then
		state.gui.Enabled = not capturing
	end
end

function WildService.releaseAfterFail(state, player: Player?)
	if not WildService.isAlive(state) then
		return
	end
	WildService.setCapturing(state, false)
	if player then
		state.aggroPlayer = player
		state.aggroCompanion = nil
		state.aggroUntil = os.clock() + WILD.AggroTime
	end
end

function WildService.removeCaptured(state)
	despawn(state)
end

function WildService.getPosition(state): Vector3
	return state.position
end

function WildService.getInRadius(position: Vector3, radius: number)
	local list = {}
	for _, state in pairs(states) do
		if not state.capturing then
			local dist = flat(state.position - position).Magnitude - WildService.radius(state)
			if dist <= radius and math.abs(state.position.Y - position.Y) < 30 then
				table.insert(list, state)
			end
		end
	end
	return list
end

function WildService.findNearest(position: Vector3, radius: number)
	local best, bestDist = nil, math.huge
	for _, state in pairs(states) do
		if not state.capturing and math.abs(state.position.Y - position.Y) < 30 then
			local dist = flat(state.position - position).Magnitude
			if dist <= radius and dist < bestDist then
				best, bestDist = state, dist
			end
		end
	end
	return best
end

function WildService.findAggressor(player: Player, companion: any?, position: Vector3, radius: number)
	local now = os.clock()
	local best, bestDist = nil, math.huge
	for _, state in pairs(states) do
		if not state.capturing and now <= state.aggroUntil
			and (state.aggroPlayer == player or (companion and state.aggroCompanion == companion)) then
			local dist = flat(state.position - position).Magnitude
			if dist <= radius and dist < bestDist then
				best, bestDist = state, dist
			end
		end
	end
	return best
end

---------------------------------------------------------------------
-- Movimento e IA
---------------------------------------------------------------------
local function getAggroTarget(state)
	if os.clock() > state.aggroUntil then
		state.aggroPlayer = nil
		state.aggroCompanion = nil
		return nil
	end
	local companion = state.aggroCompanion
	if companion then
		if companion:isAlive() then
			return companion:getPosition(), function(amount)
				companion:takeDamage(amount, state)
			end
		end
		state.aggroCompanion = nil
		return nil
	end
	local player = state.aggroPlayer
	if not player or player.Parent ~= Players then
		state.aggroPlayer = nil
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp then
		state.aggroPlayer = nil
		return nil
	end
	return hrp.Position, function()
		humanoid:TakeDamage(if state.boss then state.boss.damage else state.def.damage)
		fire("playerAttacked", player, state)
	end
end

local function bossSlam(state)
	local cfg = state.boss
	local center = state.position
	WildService.shockwave(center + Vector3.new(0, 0.5, 0), BOSS.SlamRadius, Color3.fromRGB(255, 80, 60))
	WildService.poof(center + Vector3.new(0, 1, 0), Color3.fromRGB(150, 110, 80), 50)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 and (hrp.Position - center).Magnitude <= BOSS.SlamRadius + 4 then
			humanoid:TakeDamage(cfg.damage)
			WildService.knockbackPlayer(player, center, BOSS.SlamKnockback)
		end
	end
	fire("bossSlam", center, BOSS.SlamRadius, cfg.damage * 2, state)
end

local function updateActive(state, now: number)
	if now < state.nextActiveCheck then
		return
	end
	state.nextActiveCheck = now + 0.5 + rng:NextNumber() * 0.3
	local active = false
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - state.position).Magnitude < WILD.ActiveDistance then
			active = true
			break
		end
	end
	state.active = active
end

local function step(state, dt: number, now: number)
	if state.capturing then
		return
	end
	updateActive(state, now)
	if not state.active then
		return
	end
	local def = state.def
	local isBoss = state.boss ~= nil

	-- regenerar
	local regenDelay = if isBoss then BOSS.RegenDelay else WILD.RegenDelay
	local regenRate = if isBoss then BOSS.RegenPercentPerSecond else WILD.RegenPercentPerSecond
	if state.health < state.maxHealth and now - state.lastDamage > regenDelay then
		state.health = math.min(state.maxHealth, state.health + state.maxHealth * regenRate * dt)
		if state.health >= state.maxHealth then
			state.contributors = {}
		end
		updateHealthBar(state)
	end

	local goal
	local speed = def.speed
	local targetPosition, hitTarget = getAggroTarget(state)
	local chasing = targetPosition ~= nil
	local reach = WILD.AttackRange + WildService.radius(state)
	if targetPosition then
		goal = clampState(state, targetPosition)
		speed = def.speed * 1.15
		local dist = flat(targetPosition - state.position).Magnitude
		if dist <= reach and now - state.lastAttack >= WILD.AttackCooldown then
			state.lastAttack = now
			hitTarget(state.power)
			state.phase += 2
		end
		if isBoss and now - state.lastSlam >= BOSS.SlamInterval then
			state.lastSlam = now
			bossSlam(state)
		end
	else
		if now >= state.idleUntil and (not state.target or flat(state.target - state.position).Magnitude < 2) then
			if state.target and rng:NextNumber() < 0.4 then
				state.idleUntil = now + rng:NextNumber(1, 3)
				state.target = nil
			elseif isBoss then
				local a = rng:NextNumber(0, math.pi * 2)
				state.target = clampState(state, state.home + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0, BOSS.WanderRadius))
			else
				state.target = randomPoint(state.biome)
			end
		end
		goal = if now < state.idleUntil then nil else state.target
	end

	local moving = false
	if goal then
		local offset = flat(goal - state.position)
		local dist = offset.Magnitude
		local stopDist = if chasing then 2.5 + WildService.radius(state) * 0.5 else 0.1
		if dist > stopDist then
			local dir = offset.Unit
			state.position = clampState(state, state.position + dir * math.min(speed * dt, dist - stopDist))
			state.yaw = math.atan2(-dir.X, -dir.Z)
			moving = true
		elseif chasing and dist > 0.01 then
			local dir = offset.Unit
			state.yaw = math.atan2(-dir.X, -dir.Z)
		end
	end

	local hop
	if moving then
		state.phase += dt * speed * 0.6
		hop = math.abs(math.sin(state.phase)) * (if isBoss then 1.5 else 0.8)
	else
		hop = math.abs(math.sin(now * 2 + state.phase)) * 0.15
	end
	local cf = CFrame.new(state.position + Vector3.new(0, state.hipHeight + hop, 0)) * CFrame.Angles(0, state.yaw, 0)
	state.model:PivotTo(cf)
end

---------------------------------------------------------------------
-- Iniciar
---------------------------------------------------------------------
function WildService.start()
	for _, biome in ipairs(Config.Biomes) do
		biomeCounts[biome.id] = 0
		for _ = 1, math.floor(biome.maxAlive / 2) do
			spawnOne(biome)
		end
	end

	task.spawn(function()
		while true do
			task.wait(WILD.SpawnInterval)
			for _, biome in ipairs(Config.Biomes) do
				if (biomeCounts[biome.id] or 0) < biome.maxAlive then
					spawnOne(biome)
				end
			end
		end
	end)

	task.delay(20, function()
		for _, cfg in ipairs(Config.Bosses) do
			WildService.spawnBoss(cfg.id)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, state in pairs(states) do
			local ok, err = pcall(step, state, dt, now)
			if not ok then
				warn("[WildService] erro no brainrot " .. state.def.id .. ": " .. tostring(err))
				despawn(state)
			end
		end
	end)
end

return WildService
