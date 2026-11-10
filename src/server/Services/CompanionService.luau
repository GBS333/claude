-- PARCEIRO: o brainrot que você capturou luta do seu lado.
-- Ele te segue, ataca os selvagens, ganha XP quando eles são derrotados,
-- sobe de nível (mais vida, força e renda), aprende ataques novos e EVOLUI.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)
local WildService = require(script.Parent.WildService)
local BrainrotModels = require(script.Parent.BrainrotModels)
local Remotes = require(script.Parent.Remotes)

local CompanionService = {}

local CC = Config.Companion
local BASIC = Config.getMove("Basico")

local folder = Instance.new("Folder")
folder.Name = "Companions"
folder.Parent = workspace

local active = {} -- [Player] = Companion
local faintMemory = {} -- [Player] = { uid = string, untilTime = number } (não dá para "trapacear" guardando e chamando de novo)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

---------------------------------------------------------------------
-- Classe Companion
---------------------------------------------------------------------
local Companion = {}
Companion.__index = Companion

function Companion:isAlive(): boolean
	return not self.destroyed and not self.fainted
end

function Companion:getPosition(): Vector3
	return self.position
end

function Companion:refreshStats(fullHeal: boolean)
	local level = self.item.level
	local oldMax = self.maxHealth or 1
	self.maxHealth = Stats.companionMaxHealth(self.def, level)
	self.power = Stats.companionPower(self.def, level)
	if fullHeal or not self.health then
		self.health = self.maxHealth
	else
		self.health = math.min(self.maxHealth, self.health * self.maxHealth / oldMax)
	end
end

function Companion:updateBar()
	if not self.model then
		return
	end
	local ratio = math.clamp(self.health / self.maxHealth, 0, 1)
	self.fill.Size = UDim2.fromScale(ratio, 1)
	self.hpText.Text = math.ceil(self.health) .. " / " .. self.maxHealth
	self.model:SetAttribute("Health", self.health)
	self.model:SetAttribute("MaxHealth", self.maxHealth)
end

function Companion:buildModel()
	if self.model then
		self.model:Destroy()
	end
	local def, level = self.def, self.item.level
	local model = BrainrotModels.build(def, Stats.scale(level), Stats.stage(level))
	model.Name = self.player.Name .. "_Parceiro"
	model:SetAttribute("OwnerUserId", self.player.UserId)
	model:SetAttribute("CompanionUid", self.item.uid)
	model:SetAttribute("BrainrotId", def.id)
	model:SetAttribute("Level", level)
	-- não bloqueia as bolas nem o mouse
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	self.hipHeight = model:GetAttribute("HipHeight") or def.size.Y / 2
	self.radius = def.size.X * Stats.scale(level) / 2

	-- placa com nome, nível e vida
	local rarity = Config.getRarity(def.rarity)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(190, 62)
	gui.StudsOffsetWorldSpace = Vector3.new(0, self.hipHeight + 3, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = model.PrimaryPart

	local owner = Instance.new("TextLabel")
	owner.Size = UDim2.new(1, 0, 0, 16)
	owner.BackgroundTransparency = 1
	owner.Text = "⚔ Parceiro de " .. self.player.DisplayName
	owner.TextColor3 = Color3.fromRGB(140, 230, 255)
	owner.TextStrokeTransparency = 0.3
	owner.Font = Enum.Font.GothamBold
	owner.TextScaled = true
	owner.Parent = gui

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(0, 16)
	name.Size = UDim2.new(1, 0, 0, 22)
	name.BackgroundTransparency = 1
	name.Text = Stats.displayName(def, level) .. "  Lv." .. level
	name.TextColor3 = rarity.color
	name.TextStrokeTransparency = 0.2
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(15, 42)
	back.Size = UDim2.new(1, -30, 0, 14)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(70, 200, 255)
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

	gui.Parent = model
	self.model = model
	self.fill = fill
	self.hpText = hpText
	self:updateBar()
	model:PivotTo(CFrame.new(self.position + Vector3.new(0, self.hipHeight, 0)))
	model.Parent = folder
end

function Companion:setVisible(visible: boolean)
	if not self.model then
		return
	end
	for _, d in ipairs(self.model:GetDescendants()) do
		if d:IsA("BasePart") then
			if visible then
				local original = d:GetAttribute("OriginalTransparency")
				if original then
					d.Transparency = original
				end
			else
				if d:GetAttribute("OriginalTransparency") == nil then
					d:SetAttribute("OriginalTransparency", d.Transparency)
				end
				d.Transparency = 1
			end
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = visible
		end
	end
end

function Companion:takeDamage(amount: number, attackerState)
	if not self:isAlive() then
		return
	end
	amount = math.max(1, math.floor(amount + 0.5))
	self.health -= amount
	self.lastDamage = os.clock()

	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 60, 60)
	h.FillTransparency = 0.3
	h.OutlineTransparency = 1
	h.Parent = self.model
	Debris:AddItem(h, 0.15)
	WildService.floatingText(self.position + Vector3.new(0, self.hipHeight * 2 + 1, 0), "-" .. amount, Color3.fromRGB(255, 150, 60))

	-- revida em quem bateu
	if attackerState and (not self.target or not WildService.isAlive(self.target)) then
		self.target = attackerState
	end

	if self.health <= 0 then
		self.health = 0
		self:faint()
	end
	self:updateBar()
end

function Companion:faint()
	self.fainted = true
	self.faintedUntil = os.clock() + CC.FaintTime
	self.target = nil
	self.queuedMove = nil
	faintMemory[self.player] = { uid = self.item.uid, untilTime = self.faintedUntil }
	WildService.poof(self.position + Vector3.new(0, 2, 0), Color3.fromRGB(150, 150, 150))
	self:setVisible(false)
	Remotes.CompanionEvent:FireClient(self.player, "faint", Stats.displayName(self.def, self.item.level), CC.FaintTime)
end

function Companion:revive()
	self.fainted = false
	self.health = self.maxHealth
	faintMemory[self.player] = nil
	if self.needsRebuild then
		self.needsRebuild = false
		self:buildModel()
	end
	local character = self.player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		self.position = (hrp.CFrame * CFrame.new(3, -2, CC.FollowDistance)).Position
	end
	self:setVisible(true)
	self:updateBar()
	WildService.poof(self.position + Vector3.new(0, 2, 0), Color3.fromRGB(120, 230, 255))
	Remotes.CompanionEvent:FireClient(self.player, "revive", Stats.displayName(self.def, self.item.level))
end

function Companion:destroy()
	self.destroyed = true
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

---------------------------------------------------------------------
-- Ataques
---------------------------------------------------------------------
local function projectile(fromPos: Vector3, toPos: Vector3, color: Color3, size: number, onArrive)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * size
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(fromPos)
	p.Parent = workspace
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size / 3, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size / 3, 0)
	a1.Parent = p
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = 0.25
	trail.Parent = p

	local travel = math.clamp((toPos - fromPos).Magnitude / 90, 0.12, 0.5)
	local tween = TweenService:Create(p, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = CFrame.new(toPos) })
	tween:Play()
	tween.Completed:Connect(function()
		p:Destroy()
		onArrive()
	end)
end

local function shockwave(position: Vector3, radius: number, color: Color3)
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

function Companion:performMove(move, target)
	local player = self.player
	local damage = self.power * move.power
	local color = Config.getRarity(self.def.rarity).color
	local moveName = Stats.moveName(move, self.def)
	self.lastBasic = os.clock() -- não usa o ataque básico junto

	if move.kind == "Melee" then
		self.phase += 2.5 -- pulinho de ataque
		if move.id ~= "Basico" then
			WildService.floatingText(self.position + Vector3.new(0, self.hipHeight * 2 + 2, 0), moveName .. "!", color)
			WildService.poof(WildService.getPosition(target) + Vector3.new(0, 2, 0), color)
		end
		WildService.damage(target, damage, player, self)
	elseif move.kind == "Projectile" then
		WildService.floatingText(self.position + Vector3.new(0, self.hipHeight * 2 + 2, 0), moveName .. "!", color)
		local fromPos = self.position + Vector3.new(0, self.hipHeight * 1.5, 0)
		local targetPos = WildService.getPosition(target) + Vector3.new(0, target.def.size.Y / 2 + 0.5, 0)
		local size = if move.signature then 2.5 else 1.4
		projectile(fromPos, targetPos, color, size, function()
			if WildService.isAlive(target) then
				if move.signature then
					shockwave(targetPos, 6, color)
				end
				WildService.damage(target, damage, player, if self:isAlive() then self else nil)
			end
		end)
	elseif move.kind == "Area" then
		WildService.floatingText(self.position + Vector3.new(0, self.hipHeight * 2 + 2, 0), moveName .. "!", color)
		shockwave(self.position + Vector3.new(0, 0.3, 0), move.range, color)
		for _, state in ipairs(WildService.getInRadius(self.position, move.range)) do
			WildService.damage(state, damage, player, self)
		end
	end
end

---------------------------------------------------------------------
-- IA (roda todo frame)
---------------------------------------------------------------------
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateGroundFilter()
	local list = { folder }
	local wild = workspace:FindFirstChild("WildBrainrots")
	if wild then
		table.insert(list, wild)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = list
end

local function holdingBall(player: Player): boolean
	local character = player.Character
	return character ~= nil and character:FindFirstChild("Bola") ~= nil
end

function Companion:update(dt: number, now: number)
	if self.destroyed or not self.model then
		return
	end
	if self.fainted then
		if now >= self.faintedUntil then
			self:revive()
		end
		return
	end

	local player = self.player
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local ownerPos = hrp.Position

	-- regenerar fora de combate
	if self.health < self.maxHealth and now - self.lastDamage > CC.RegenDelay then
		self.health = math.min(self.maxHealth, self.health + self.maxHealth * CC.RegenPercentPerSecond * dt)
		self:updateBar()
	end

	-- validar alvo
	local target = self.target
	if target and (not WildService.isAlive(target) or target.capturing
		or flat(WildService.getPosition(target) - ownerPos).Magnitude > CC.LeashDistance) then
		self.target = nil
		self.queuedMove = nil
		target = nil
	end
	if not target then
		target = WildService.findAggressor(player, self, ownerPos, CC.AutoTargetRadius + 10)
		if not target and player:GetAttribute("AutoBattle") ~= false then
			target = WildService.findNearest(ownerPos, CC.AutoTargetRadius)
		end
		self.target = target
	end

	-- segurando a bola + selvagem com pouca vida = o parceiro espera você capturar
	local holdFire = target ~= nil and holdingBall(player) and target.health / target.maxHealth <= 0.25

	-- longe demais? teleporta para perto do dono
	if flat(self.position - ownerPos).Magnitude > CC.TeleportDistance then
		self.position = (hrp.CFrame * CFrame.new(3, -2, CC.FollowDistance)).Position
	end

	local goal, stopDist
	local speed = math.max(self.def.speed * 1.3, CC.MinSpeed)
	if target and not holdFire then
		goal = WildService.getPosition(target)
		stopDist = BASIC.range * 0.6 + target.def.size.X / 2 + self.radius
	else
		goal = (hrp.CFrame * CFrame.new(3, 0, CC.FollowDistance)).Position
		stopDist = 1.5
		if flat(goal - self.position).Magnitude > 20 then
			speed *= 1.6
		end
	end

	local offset = flat(goal - self.position)
	local dist = offset.Magnitude
	local moving = false
	if dist > stopDist then
		local dir = offset.Unit
		self.position += dir * math.min(speed * dt, dist - stopDist)
		self.yaw = math.atan2(-dir.X, -dir.Z)
		moving = true
	end
	if target then
		local look = flat(WildService.getPosition(target) - self.position)
		if look.Magnitude > 0.1 then
			look = look.Unit
			self.yaw = math.atan2(-look.X, -look.Z)
		end
	end

	-- achar o chão
	local result = workspace:Raycast(
		Vector3.new(self.position.X, ownerPos.Y + 15, self.position.Z), Vector3.new(0, -60, 0), groundParams)
	local groundY = if result then result.Position.Y else ownerPos.Y - 3
	self.position = Vector3.new(self.position.X, groundY, self.position.Z)

	local hop
	if moving then
		self.phase += dt * speed * 0.6
		hop = math.abs(math.sin(self.phase)) * 0.8
	else
		hop = math.abs(math.sin(now * 2 + self.phase)) * 0.15
	end
	self.model:PivotTo(CFrame.new(self.position + Vector3.new(0, self.hipHeight + hop, 0)) * CFrame.Angles(0, self.yaw, 0))

	-- atacar
	if target and not holdFire then
		local targetDist = flat(WildService.getPosition(target) - self.position).Magnitude - target.def.size.X / 2 - self.radius
		local queued = self.queuedMove
		if queued and targetDist <= queued.range then
			self.queuedMove = nil
			self:performMove(queued, target)
		elseif targetDist <= BASIC.range and now - self.lastBasic >= BASIC.cooldown then
			self:performMove(BASIC, target)
		end
	end
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------
function CompanionService.get(player: Player)
	return active[player]
end

function CompanionService.spawn(player: Player)
	local data = DataService.get(player)
	if not data or not data.companion then
		return
	end
	local item = DataService.findItem(player, data.companion)
	local def = item and Config.getBrainrot(item.id)
	if not def then
		data.companion = nil
		return
	end

	local old = active[player]
	if old then
		old:destroy()
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local startPos = if hrp then (hrp.CFrame * CFrame.new(3, -2, CC.FollowDistance)).Position else Vector3.zero

	local comp = setmetatable({
		player = player,
		item = item,
		def = def,
		position = startPos,
		yaw = 0,
		phase = 0,
		lastBasic = 0,
		lastDamage = 0,
		cooldowns = {},
		target = nil,
		queuedMove = nil,
		fainted = false,
		faintedUntil = 0,
		destroyed = false,
	}, Companion)
	comp:refreshStats(true)
	comp:buildModel()
	active[player] = comp

	-- se ele tinha desmaiado há pouco, continua desmaiado
	local memory = faintMemory[player]
	if memory and memory.uid == item.uid and os.clock() < memory.untilTime then
		comp.health = 0
		comp.fainted = true
		comp.faintedUntil = memory.untilTime
		comp:setVisible(false)
		comp:updateBar()
	end
	return comp
end

function CompanionService.summon(player: Player, uid: string)
	local data = DataService.get(player)
	local item = DataService.findItem(player, uid)
	if not data or not item then
		return false, "Brainrot não encontrado."
	end
	if item.slot then
		return false, "Tire ele do pedestal primeiro."
	end
	data.companion = uid
	local comp = CompanionService.spawn(player)
	DataService.pushUpdate(player)
	if not comp then
		return false, "Não deu para chamar o parceiro."
	end
	return true, Stats.displayName(comp.def, item.level) .. " é seu parceiro! ⚔"
end

-- keepData = true quando o jogador sai do jogo (o parceiro volta na próxima vez)
function CompanionService.dismiss(player: Player, keepData: boolean?)
	local comp = active[player]
	if comp then
		comp:destroy()
		active[player] = nil
	end
	if not keepData then
		local data = DataService.get(player)
		if data then
			data.companion = nil
			DataService.pushUpdate(player)
		end
	end
	return true, "Parceiro guardado."
end

-- O jogador bateu em alguém com o taco: o parceiro ataca o mesmo
function CompanionService.setTarget(player: Player, state)
	local comp = active[player]
	if comp and comp:isAlive() and WildService.isAlive(state) then
		comp.target = state
	end
end

function CompanionService.useMove(player: Player, moveId: any, targetModel: any)
	local comp = active[player]
	if not comp then
		return false, "Escolha um parceiro no menu 🎒 Brainrots."
	end
	if not comp:isAlive() then
		return false, "Seu parceiro está desmaiado."
	end
	local move = type(moveId) == "string" and Config.getMove(moveId)
	if not move or move.auto then
		return false, nil
	end
	if comp.item.level < move.level then
		return false, Stats.moveName(move, comp.def) .. " só no nível " .. move.level .. "."
	end
	local now = os.clock()
	if comp.cooldowns[move.id] and now < comp.cooldowns[move.id] then
		return false, nil
	end

	if move.kind == "Area" then
		comp.cooldowns[move.id] = now + move.cooldown
		comp:performMove(move, nil)
		return true, nil
	end

	-- alvo: o que está embaixo do mouse, o atual, ou o mais perto
	local target
	if typeof(targetModel) == "Instance" then
		target = WildService.getStateFromModel(targetModel)
	end
	if target and flat(WildService.getPosition(target) - comp.position).Magnitude > CC.LeashDistance then
		target = nil
	end
	target = target or comp.target or WildService.findNearest(comp.position, math.max(move.range, CC.AutoTargetRadius))
	if not target or not WildService.isAlive(target) or target.capturing then
		return false, "Nenhum brainrot selvagem por perto."
	end

	comp.cooldowns[move.id] = now + move.cooldown
	comp.target = target
	local dist = flat(WildService.getPosition(target) - comp.position).Magnitude - target.def.size.X / 2 - comp.radius
	if dist <= move.range then
		comp:performMove(move, target)
	else
		comp.queuedMove = move -- vai correndo e usa quando chegar perto
	end
	return true, nil
end

-- XP, níveis, novos ataques e evolução
function CompanionService.grantXp(player: Player, amount: number)
	local comp = active[player]
	if not comp or amount <= 0 then
		return
	end
	local item = comp.item
	local maxLevel = Config.Levels.MaxLevel
	if item.level >= maxLevel then
		return
	end

	item.xp += amount
	WildService.floatingText(comp.position + Vector3.new(0, comp.hipHeight * 2 + 3, 0), "+" .. amount .. " XP", Color3.fromRGB(120, 230, 255))

	local oldLevel = item.level
	local oldStage = Stats.stage(oldLevel)
	local oldName = Stats.displayName(comp.def, oldLevel)
	while item.level < maxLevel and item.xp >= Stats.xpToNext(item.level) do
		item.xp -= Stats.xpToNext(item.level)
		item.level += 1
	end
	if item.level >= maxLevel then
		item.xp = 0
	end

	if item.level > oldLevel then
		local newStage = Stats.stage(item.level)
		comp:refreshStats(true)
		if comp.model then
			comp.model:SetAttribute("Level", item.level)
		end

		if comp.fainted then
			comp.needsRebuild = true -- reconstrói quando ele voltar
			comp.health = 0
		end
		if newStage > oldStage then
			if not comp.fainted then
				comp:buildModel() -- modelo maior e com efeitos
			end
			local newName = Stats.displayName(comp.def, item.level)
			Remotes.CompanionEvent:FireClient(player, "evolve", oldName, newName)
			WildService.poof(comp.position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 230, 80))
		elseif not comp.fainted then
			comp:buildModel() -- atualiza o nome/nível na placa
		end

		Remotes.CompanionEvent:FireClient(player, "levelup", Stats.displayName(comp.def, item.level), item.level)
		for _, move in ipairs(Config.Moves) do
			if move.level > oldLevel and move.level <= item.level then
				Remotes.CompanionEvent:FireClient(player, "learn", Stats.moveName(move, comp.def), move.key)
			end
		end
	end
	DataService.pushUpdate(player)
end

function CompanionService.onCaptured(player: Player, state)
	local xp = math.floor(Stats.xpReward(state.def, state.level) * Config.Levels.CaptureXpShare)
	CompanionService.grantXp(player, xp)
end

function CompanionService.start()
	WildService.onDefeated = function(state, player)
		CompanionService.grantXp(player, Stats.xpReward(state.def, state.level))
	end
	WildService.onPlayerAttacked = function(player, state)
		local comp = active[player]
		if comp and comp:isAlive() and not comp.target then
			comp.target = state
		end
	end

	local filterTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		filterTimer -= dt
		if filterTimer <= 0 then
			filterTimer = 1
			updateGroundFilter()
		end
		local now = os.clock()
		for player, comp in pairs(active) do
			local ok, err = pcall(comp.update, comp, dt, now)
			if not ok then
				warn("[CompanionService] erro no parceiro de " .. player.Name .. ": " .. tostring(err))
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		CompanionService.dismiss(player, true)
		faintMemory[player] = nil
	end)
end

return CompanionService
