-- Brainrots selvagens: nascem na zona de caça, andam, apanham do taco,
-- ficam bravos e atacam, regeneram vida e desmaiam se a vida zerar.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CatchMath = require(ReplicatedStorage.Shared.CatchMath)
local BrainrotModels = require(script.Parent.BrainrotModels)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local WildService = {}

local WILD = Config.Wild
local folder = Instance.new("Folder")
folder.Name = "WildBrainrots"
folder.Parent = workspace

local states = {} -- [Model] = estado
local count = 0
local rng = Random.new()

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
local function randomZonePoint(): Vector3
	local c = WILD.ZoneCenter
	local hx, hz = WILD.ZoneSize.X / 2 - 6, WILD.ZoneSize.Y / 2 - 6
	return Vector3.new(c.X + rng:NextNumber(-hx, hx), WILD.GroundY, c.Z + rng:NextNumber(-hz, hz))
end

local function clampToZone(p: Vector3): Vector3
	local c = WILD.ZoneCenter
	local hx, hz = WILD.ZoneSize.X / 2 - 3, WILD.ZoneSize.Y / 2 - 3
	return Vector3.new(math.clamp(p.X, c.X - hx, c.X + hx), WILD.GroundY, math.clamp(p.Z, c.Z - hz, c.Z + hz))
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function pickRandomDef()
	local total = 0
	for _, name in ipairs(Config.RarityOrder) do
		total += Config.Rarities[name].spawnWeight
	end
	local roll = rng:NextNumber(0, total)
	local chosen = Config.RarityOrder[1]
	for _, name in ipairs(Config.RarityOrder) do
		roll -= Config.Rarities[name].spawnWeight
		if roll <= 0 then
			chosen = name
			break
		end
	end
	local options = {}
	for _, def in ipairs(Config.Brainrots) do
		if def.rarity == chosen then
			table.insert(options, def)
		end
	end
	if #options == 0 then
		return Config.Brainrots[rng:NextInteger(1, #Config.Brainrots)]
	end
	return options[rng:NextInteger(1, #options)]
end

---------------------------------------------------------------------
-- Barra de vida
---------------------------------------------------------------------
local function createBillboard(state)
	local def = state.def
	local rarity = Config.getRarity(def.rarity)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(180, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, def.size.Y / 2 + 3, 0)
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	gui.Adornee = state.model.PrimaryPart

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 20)
	name.BackgroundTransparency = 1
	name.Text = def.name
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Position = UDim2.fromOffset(0, 20)
	rarityLabel.Size = UDim2.new(1, 0, 0, 16)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = rarity.display
	rarityLabel.TextColor3 = rarity.color
	rarityLabel.TextStrokeTransparency = 0.3
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextScaled = true
	rarityLabel.Parent = gui

	local back = Instance.new("Frame")
	back.Name = "HealthBack"
	back.Position = UDim2.fromOffset(15, 40)
	back.Size = UDim2.new(1, -30, 0, 12)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HpText"
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
	state.fill = fill
	state.hpText = hpText
end

local function updateHealthBar(state)
	local ratio = math.clamp(state.health / state.def.maxHealth, 0, 1)
	state.fill.Size = UDim2.fromScale(ratio, 1)
	if ratio > 0.5 then
		state.fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	elseif ratio > 0.2 then
		state.fill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	else
		state.fill.BackgroundColor3 = Color3.fromRGB(240, 60, 60)
	end
	state.hpText.Text = math.ceil(state.health) .. " / " .. state.def.maxHealth
	state.model:SetAttribute("Health", state.health)
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
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
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

function WildService.poof(position: Vector3, color: Color3)
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
	emitter:Emit(35)
	Debris:AddItem(p, 1.5)
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

---------------------------------------------------------------------
-- Ciclo de vida
---------------------------------------------------------------------
local function spawnOne()
	local def = pickRandomDef()
	local model = BrainrotModels.build(def, 1)
	local state = {
		def = def,
		model = model,
		health = def.maxHealth,
		position = randomZonePoint(),
		yaw = rng:NextNumber(0, math.pi * 2),
		target = nil,
		idleUntil = 0,
		lastDamage = 0,
		lastAttack = 0,
		aggroPlayer = nil,
		aggroUntil = 0,
		capturing = false,
		hipHeight = model:GetAttribute("HipHeight") or def.size.Y / 2,
		phase = rng:NextNumber(0, 10),
		transparency = {},
	}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			state.transparency[d] = d.Transparency
		end
	end

	model:SetAttribute("BrainrotId", def.id)
	model:SetAttribute("MaxHealth", def.maxHealth)
	model:SetAttribute("Health", def.maxHealth)
	model:PivotTo(CFrame.new(state.position + Vector3.new(0, state.hipHeight, 0)) * CFrame.Angles(0, state.yaw, 0))
	model.Parent = folder
	createBillboard(state)
	updateHealthBar(state)

	states[model] = state
	count += 1
	WildService.poof(state.position + Vector3.new(0, 2, 0), Config.getRarity(def.rarity).color)
	return state
end

local function despawn(state)
	if not states[state.model] then
		return
	end
	states[state.model] = nil
	count -= 1
	state.model:Destroy()
end

local function faint(state, player: Player?)
	local def = state.def
	local rarity = Config.getRarity(def.rarity)
	WildService.poof(state.model:GetPivot().Position, rarity.color)
	despawn(state)
	if player then
		DataService.addCash(player, rarity.faintReward)
		Remotes.notify(
			player,
			def.name .. " desmaiou e fugiu! +$" .. rarity.faintReward .. "  (Dica: deixe com POUCA vida e jogue a bola!)",
			Color3.fromRGB(255, 170, 60)
		)
	end
end

---------------------------------------------------------------------
-- API usada pelo taco e pelas bolas
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

function WildService.isAlive(state): boolean
	return state ~= nil and states[state.model] == state
end

-- Acha o brainrot mais perto na frente do jogador
function WildService.findTargetInFront(player: Player, range: number)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, state in pairs(states) do
		if not state.capturing then
			local pos = state.model:GetPivot().Position
			local offset = flat(pos - hrp.Position)
			local dist = offset.Magnitude - state.def.size.X / 2
			if dist <= range and math.abs(pos.Y - hrp.Position.Y) < 12 then
				local facing = offset.Magnitude < 0.1 or flat(hrp.CFrame.LookVector).Unit:Dot(offset.Unit) > 0.2
				if facing and dist < bestDist then
					best, bestDist = state, dist
				end
			end
		end
	end
	return best
end

function WildService.damage(state, amount: number, player: Player?)
	if not WildService.isAlive(state) or state.capturing then
		return
	end
	state.health -= amount
	state.lastDamage = os.clock()
	flash(state)
	floatingText(state.model:GetPivot().Position + Vector3.new(0, state.def.size.Y / 2 + 1, 0), "-" .. amount, Color3.fromRGB(255, 80, 80))

	if state.health <= 0 then
		state.health = 0
		faint(state, player)
		return
	end
	updateHealthBar(state)

	-- fica bravo e empurra para trás
	if player then
		state.aggroPlayer = player
		state.aggroUntil = os.clock() + WILD.AggroTime
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local away = flat(state.position - hrp.Position)
			if away.Magnitude > 0.1 then
				state.position = clampToZone(state.position + away.Unit * WILD.Knockback)
			end
		end
	end
end

function WildService.getChance(state, ballMultiplier: number): number
	return CatchMath.getChance(state.def.catchRate, state.health, state.def.maxHealth, ballMultiplier)
end

-- Some/aparece enquanto está dentro da bola
function WildService.setCapturing(state, capturing: boolean)
	state.capturing = capturing
	for part, original in pairs(state.transparency) do
		if part.Parent then
			part.Transparency = if capturing then 1 else original
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
		state.aggroUntil = os.clock() + WILD.AggroTime
	end
end

function WildService.removeCaptured(state)
	despawn(state)
end

function WildService.getPosition(state): Vector3
	return state.position
end

---------------------------------------------------------------------
-- Movimento e IA
---------------------------------------------------------------------
local function getAggroTarget(state)
	if not state.aggroPlayer or os.clock() > state.aggroUntil then
		state.aggroPlayer = nil
		return nil
	end
	local player = state.aggroPlayer
	if player.Parent ~= Players then
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
	return humanoid, hrp
end

local function step(state, dt: number, now: number)
	if state.capturing then
		return
	end
	local def = state.def

	-- regenerar
	if state.health < def.maxHealth and now - state.lastDamage > WILD.RegenDelay then
		state.health = math.min(def.maxHealth, state.health + def.maxHealth * WILD.RegenPercentPerSecond * dt)
		updateHealthBar(state)
	end

	local goal
	local speed = def.speed
	local humanoid, hrp = getAggroTarget(state)
	if humanoid then
		goal = clampToZone(hrp.Position)
		speed = def.speed * 1.15
		local dist = flat(hrp.Position - state.position).Magnitude
		if dist <= WILD.AttackRange + def.size.X / 2 and now - state.lastAttack >= WILD.AttackCooldown then
			state.lastAttack = now
			humanoid:TakeDamage(def.damage)
			state.phase += 2 -- pulinho de ataque
		end
	else
		if now < state.idleUntil then
			goal = nil
		elseif not state.target or flat(state.target - state.position).Magnitude < 2 then
			if state.target and rng:NextNumber() < 0.4 then
				state.idleUntil = now + rng:NextNumber(1, 3)
				state.target = nil
			else
				state.target = randomZonePoint()
			end
		end
		goal = if now < state.idleUntil then nil else state.target
	end

	local moving = false
	if goal then
		local offset = flat(goal - state.position)
		local dist = offset.Magnitude
		local stopDist = if humanoid then 2.5 else 0.1
		if dist > stopDist then
			local dir = offset.Unit
			state.position = clampToZone(state.position + dir * math.min(speed * dt, dist - stopDist))
			state.yaw = math.atan2(-dir.X, -dir.Z)
			moving = true
		elseif humanoid then
			local dir = offset.Unit
			state.yaw = math.atan2(-dir.X, -dir.Z)
		end
	end

	local hop = 0
	if moving then
		state.phase += dt * speed * 0.6
		hop = math.abs(math.sin(state.phase)) * 0.8
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
	for _ = 1, math.floor(WILD.MaxAlive / 2) do
		spawnOne()
	end

	task.spawn(function()
		while true do
			task.wait(WILD.SpawnInterval)
			if count < WILD.MaxAlive then
				spawnOne()
			end
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
