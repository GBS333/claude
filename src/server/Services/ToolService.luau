-- Ferramentas: OBJETOS DE BATER (taco, frigideira, martelo...), a BOLA DE CAPTURA
-- e os EQUIPAMENTOS (molas, escudo, capa de invisibilidade).
-- Os objetos de bater acertam brainrots e também JOGADORES (com empurrão).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)
local WildService = require(script.Parent.WildService)
local CompanionService = require(script.Parent.CompanionService)
local StealService = require(script.Parent.StealService)
local ProgressService = require(script.Parent.ProgressService)
local Remotes = require(script.Parent.Remotes)

local ToolService = {}

local BAT_NAME = "Taco"
local BALL_NAME = "Bola"
local C = Config.Catch
local RED = Color3.fromRGB(255, 120, 120)

local lastSwing = {} -- [Player] = os.clock()
local lastThrow = {}
local gearCooldown = {} -- [Player] = { [gearId] = os.clock() }

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function toolPart(tool: Tool, handle: BasePart?, props)
	local p = Instance.new("Part")
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = tool
	if handle then
		weld(handle, p)
	end
	return p
end

---------------------------------------------------------------------
-- MOVIMENTO (velocidade/pulo dependem de mola, roubo e duelo)
---------------------------------------------------------------------
function ToolService.refreshMovement(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local speed, jump = 16, 50
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			local gear = Config.getGear(tool:GetAttribute("GearId"))
			if gear and gear.kind == "speed" then
				speed = gear.value
			elseif gear and gear.kind == "jump" then
				jump = gear.value
			end
		end
	end
	if player:GetAttribute("Carrying") then
		speed = math.min(speed, Config.Steal.CarrySpeed)
	end
	if player:GetAttribute("Frozen") then
		speed, jump = 0, 0
	end
	humanoid.UseJumpPower = true
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = jump
end

---------------------------------------------------------------------
-- OBJETOS DE BATER
---------------------------------------------------------------------
local function createBat(batDef)
	local tool = Instance.new("Tool")
	tool.Name = BAT_NAME
	tool.ToolTip = batDef.name .. " (dano " .. batDef.damage .. ", empurrão " .. batDef.knockback .. ")"
	tool.CanBeDropped = false
	tool:SetAttribute("BatId", batDef.id)
	-- segura igual à espada clássica: a ponta aponta para cima
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, -0.8), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))

	local color, material = batDef.color, batDef.material
	local handle = toolPart(tool, nil, {
		Name = "Handle", Size = Vector3.new(0.45, 0.45, 2.4), Color = if batDef.look == "bat" then color else Color3.fromRGB(90, 60, 40),
		Material = if batDef.look == "bat" then material else Enum.Material.Wood,
	})
	toolPart(tool, handle, {
		Name = "Tape", Size = Vector3.new(0.5, 0.5, 1), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Fabric,
		CFrame = handle.CFrame * CFrame.new(0, 0, -0.8),
	})

	local head
	if batDef.look == "pan" then
		-- frigideira: disco grande na ponta
		head = toolPart(tool, handle, {
			Name = "Pan", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.6, 2.6), Color = color, Material = material,
			CFrame = handle.CFrame * CFrame.new(0, 0, 2.5),
		})
	elseif batDef.look == "hammer" then
		-- martelo: bloco atravessado na ponta
		head = toolPart(tool, handle, {
			Name = "HammerHead", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.3, 1.3), Color = color, Material = material,
			CFrame = handle.CFrame * CFrame.new(0, 0, 1.8),
		})
	else
		head = toolPart(tool, handle, {
			Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 0.8, 0.8), Color = color, Material = material,
			CFrame = handle.CFrame * CFrame.new(0, 0, 2.4) * CFrame.Angles(0, math.rad(90), 0),
		})
	end
	if batDef.rebirth > 0 or batDef.id == "Diamante" or batDef.id == "Ouro" then
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = color
		sparkle.Parent = head
	end
	return tool
end

-- jogador mais perto na frente (para o PvP)
local function findPlayerInFront(attacker: Player, range: number)
	local character = attacker.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil, nil
	end
	local best, bestDist = nil, math.huge
	for _, other in ipairs(Players:GetPlayers()) do
		local oc = other ~= attacker and other.Character
		local ohrp = oc and oc:FindFirstChild("HumanoidRootPart")
		local ohum = oc and oc:FindFirstChildOfClass("Humanoid")
		if ohrp and ohum and ohum.Health > 0 then
			local offset = ohrp.Position - hrp.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			local dist = flatOffset.Magnitude
			if dist <= range and math.abs(offset.Y) < 8 then
				local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
				if dist < 0.5 or look:Dot(flatOffset.Unit) > 0.3 then
					if dist < bestDist then
						best, bestDist = other, dist
					end
				end
			end
		end
	end
	return best, bestDist
end

local function isSafe(player: Player): boolean
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local spawnLocation = workspace:FindFirstChild("SpawnLocation", true)
	if hrp and spawnLocation and spawnLocation:IsA("BasePart") then
		return (hrp.Position - spawnLocation.Position).Magnitude < Config.PvP.SafeRadius
	end
	return false
end

local function hitPlayer(attacker: Player, victim: Player, batDef)
	if isSafe(victim) or isSafe(attacker) then
		Remotes.notify(attacker, "Perto do spawn ninguém apanha 😇", RED)
		return
	end
	local character = victim.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local attackerRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not attackerRoot then
		return
	end
	StealService.onPlayerHit(victim, attacker) -- ladrão larga o brainrot
	if character:FindFirstChildOfClass("ForceField") then
		return -- escudo de bolha
	end
	humanoid:TakeDamage(batDef.pvpDamage)
	WildService.knockbackPlayer(victim, attackerRoot.Position, batDef.knockback)
	local head = character:FindFirstChild("Head")
	if head then
		WildService.floatingText(head.Position + Vector3.new(0, 2, 0), "-" .. batDef.pvpDamage, Color3.fromRGB(255, 80, 80))
	end
end

local function onSwing(player: Player, tool: Tool)
	local data = DataService.get(player)
	if not data then
		return
	end
	local batDef = Config.getBat(data.bat) or Config.Bats[1]
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < batDef.cooldown then
		return
	end
	lastSwing[player] = now

	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	Debris:AddItem(anim, 1)

	local target, targetDist = WildService.findTargetInFront(player, batDef.range)
	local victim, victimDist = nil, nil
	if Config.PvP.Enabled then
		victim, victimDist = findPlayerInFront(player, batDef.range * 0.7)
	end
	if victim and (not target or victimDist < targetDist) then
		hitPlayer(player, victim, batDef)
	elseif target then
		WildService.damage(target, batDef.damage, player)
		CompanionService.setTarget(player, target)
	end
end

---------------------------------------------------------------------
-- BOLA DE CAPTURA
---------------------------------------------------------------------
local function paintBall(part: BasePart, ballDef)
	part.Color = ballDef.color
	local stripe = part:FindFirstChild("Stripe")
	if stripe then
		stripe.Color = Color3.fromRGB(30, 30, 30)
	end
end

local function makeBallPart(ballDef, size: number)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * size
	ball.Material = Enum.Material.SmoothPlastic
	ball.CanCollide = false
	ball.Massless = true
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth

	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Shape = Enum.PartType.Cylinder
	stripe.Size = Vector3.new(size * 0.15, size * 1.02, size * 1.02)
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CanTouch = false
	stripe.Massless = true
	stripe.CFrame = ball.CFrame * CFrame.Angles(0, 0, math.rad(90))
	stripe.Parent = ball
	weld(ball, stripe)

	local button = Instance.new("Part")
	button.Name = "Button"
	button.Shape = Enum.PartType.Cylinder
	button.Size = Vector3.new(size * 0.1, size * 0.35, size * 0.35)
	button.Color = Color3.new(1, 1, 1)
	button.CanCollide = false
	button.CanQuery = false
	button.CanTouch = false
	button.Massless = true
	button.CFrame = ball.CFrame * CFrame.new(0, 0, -size / 2) * CFrame.Angles(0, math.rad(90), 0)
	button.Parent = ball
	weld(ball, button)

	paintBall(ball, ballDef)
	return ball
end

local function createBallTool(ballDef)
	local tool = Instance.new("Tool")
	tool.Name = BALL_NAME
	tool.ToolTip = "Jogue nos brainrots com POUCA vida!"
	tool.CanBeDropped = false
	local handle = makeBallPart(ballDef, 1.1)
	handle.Name = "Handle"
	handle.Parent = tool
	return tool
end

function ToolService.updateBallTool(player: Player)
	local ballDef = Config.getBall(player:GetAttribute("SelectedBall") or "Basica") or Config.Balls[1]
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		local tool = container and container:FindFirstChild(BALL_NAME)
		if tool and tool:FindFirstChild("Handle") then
			paintBall(tool.Handle, ballDef)
		end
	end
end

local function shake(ball: BasePart, base: CFrame)
	local info = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for _, angle in ipairs({ 25, -25, 0 }) do
		local tween = TweenService:Create(ball, info, { CFrame = base * CFrame.Angles(0, 0, math.rad(angle)) })
		tween:Play()
		tween.Completed:Wait()
	end
end

local function attemptCapture(player: Player, state, ball: BasePart, ballDef)
	WildService.setCapturing(state, true)
	local def = state.def
	local rarity = Config.getRarity(def.rarity)
	local chance = WildService.getChance(state, ballDef.multiplier)
	local success = math.random() < chance
	local shakes = if success then 3 else math.random(0, 2)

	local ground = WildService.getPosition(state)
	local base = CFrame.new(ground + Vector3.new(0, ball.Size.Y / 2 + 0.05, 0))
	ball.CFrame = base

	WildService.poof(ground + Vector3.new(0, 2, 0), Color3.new(1, 1, 1))
	task.wait(0.6)

	for _ = 1, shakes do
		shake(ball, base)
		task.wait(0.5)
	end

	if success then
		WildService.poof(base.Position, Color3.fromRGB(255, 230, 80))
		ball:Destroy()
		if WildService.isAlive(state) then
			WildService.removeCaptured(state)
		end
		DataService.addBrainrot(player, def.id, state.level, state.mutation)
		CompanionService.onCaptured(player, state)
		ProgressService.giveXp(player, Stats.xpReward(def, state.level))
		Remotes.CatchResult:FireClient(player, true, def.id, chance, state.level, state.mutation)
	else
		WildService.poof(base.Position, rarity.color)
		ball:Destroy()
		WildService.releaseAfterFail(state, player)
		Remotes.CatchResult:FireClient(player, false, def.id, chance)
	end
end

local function throwBall(player: Player, targetPos: any)
	if typeof(targetPos) ~= "Vector3" then
		return
	end
	local magnitude = targetPos.Magnitude
	if magnitude ~= magnitude or magnitude > 1e5 then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not head or not character:FindFirstChild(BALL_NAME) then
		return
	end

	local now = os.clock()
	if lastThrow[player] and now - lastThrow[player] < C.ThrowCooldown then
		return
	end

	local ballId = player:GetAttribute("SelectedBall") or "Basica"
	local ballDef = Config.getBall(ballId)
	if not ballDef then
		return
	end
	if not DataService.useBall(player, ballId) then
		Remotes.notify(player, "Você não tem " .. ballDef.name .. "! Compre na Loja 🛒", RED)
		return
	end
	lastThrow[player] = now

	local origin = head.Position + Vector3.new(0, 0.5, 0)
	local offset = targetPos - origin
	if offset.Magnitude > C.MaxThrowDistance then
		offset = offset.Unit * C.MaxThrowDistance
	end
	if offset.Magnitude < 1 then
		offset = head.CFrame.LookVector * 10
	end
	local flightTime = offset.Magnitude / C.ThrowSpeed
	local velocity = offset / flightTime + Vector3.new(0, 0.5 * C.Gravity * flightTime, 0)

	local ball = makeBallPart(ballDef, 1.2)
	ball.Name = "ThrownBall"
	ball.Anchored = true
	ball.CanQuery = false
	ball.CFrame = CFrame.new(origin)
	ball.Parent = workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, ball, workspace:FindFirstChild("Companions") }

	local position = origin
	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local newVelocity = velocity - Vector3.new(0, C.Gravity * dt, 0)
		local newPosition = position + velocity * dt
		local result = workspace:Raycast(position, newPosition - position, params)

		if result then
			connection:Disconnect()
			local state = WildService.getStateFromPart(result.Instance)
			if state and WildService.isBoss(state) then
				WildService.poof(result.Position, ballDef.color)
				ball:Destroy()
				Remotes.notify(player, "👑 Chefões não podem ser capturados! Derrote ele!", RED)
			elseif state and WildService.isAlive(state) and not state.capturing then
				task.spawn(attemptCapture, player, state, ball, ballDef)
			else
				WildService.poof(result.Position, ballDef.color)
				ball:Destroy()
			end
			return
		end

		position = newPosition
		velocity = newVelocity
		ball.CFrame = CFrame.new(position) * CFrame.Angles(elapsed * 10, 0, 0)

		if elapsed > 4 then
			connection:Disconnect()
			ball:Destroy()
		end
	end)
end

---------------------------------------------------------------------
-- EQUIPAMENTOS
---------------------------------------------------------------------
local function setInvisible(player: Player, invisible: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, d in ipairs(character:GetDescendants()) do
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			if invisible then
				if d:GetAttribute("VisibleTransparency") == nil then
					d:SetAttribute("VisibleTransparency", d.Transparency)
				end
				d.Transparency = 1
			else
				local original = d:GetAttribute("VisibleTransparency")
				if original ~= nil then
					d.Transparency = original
					d:SetAttribute("VisibleTransparency", nil)
				end
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = if invisible then Enum.HumanoidDisplayDistanceType.None
			else Enum.HumanoidDisplayDistanceType.Viewer
	end
	player:SetAttribute("Invisible", if invisible then true else nil)
end

local function useGear(player: Player, gear)
	gearCooldown[player] = gearCooldown[player] or {}
	local now = os.clock()
	local readyAt = gearCooldown[player][gear.id] or 0
	if now < readyAt then
		Remotes.notify(player, gear.name .. " recarregando: " .. math.ceil(readyAt - now) .. "s", RED)
		return
	end
	local character = player.Character
	if not character then
		return
	end
	gearCooldown[player][gear.id] = now + gear.cooldown
	if gear.kind == "shield" then
		local ff = Instance.new("ForceField")
		ff.Visible = true
		ff.Parent = character
		Debris:AddItem(ff, gear.duration)
	elseif gear.kind == "invisible" then
		setInvisible(player, true)
		Remotes.notify(player, "👻 Você está invisível por " .. gear.duration .. "s!", Color3.fromRGB(180, 160, 255))
		local myCharacter = character
		task.delay(gear.duration, function()
			if player.Character == myCharacter then
				setInvisible(player, false)
			end
		end)
	end
end

local function createGearTool(player: Player, gear)
	local tool = Instance.new("Tool")
	tool.Name = gear.name
	tool.ToolTip = gear.description
	tool.CanBeDropped = false
	tool:SetAttribute("GearId", gear.id)

	if gear.kind == "speed" or gear.kind == "jump" then
		local handle = toolPart(tool, nil, {
			Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.9, 0.9), Color = gear.color,
			Material = Enum.Material.Neon,
		})
		for i = -1, 1 do
			toolPart(tool, handle, {
				Name = "Coil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.1, 1.1), Color = Color3.fromRGB(200, 200, 210),
				Material = Enum.Material.Metal, CFrame = handle.CFrame * CFrame.new(i * 0.45, 0, 0),
			})
		end
		tool.Equipped:Connect(function()
			ToolService.refreshMovement(player)
		end)
		tool.Unequipped:Connect(function()
			task.defer(ToolService.refreshMovement, player)
		end)
	elseif gear.kind == "shield" then
		toolPart(tool, nil, {
			Name = "Handle", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = gear.color,
			Material = Enum.Material.Glass, Transparency = 0.3,
		})
		tool.Activated:Connect(function()
			useGear(player, gear)
		end)
	else
		toolPart(tool, nil, {
			Name = "Handle", Size = Vector3.new(1.4, 1.8, 0.2), Color = gear.color, Material = Enum.Material.Fabric,
		})
		tool.Activated:Connect(function()
			useGear(player, gear)
		end)
	end
	return tool
end

---------------------------------------------------------------------
-- Dar as ferramentas
---------------------------------------------------------------------
function ToolService.giveTools(player: Player)
	local data = DataService.get(player)
	local backpack = player:FindFirstChild("Backpack")
	if not data or not backpack then
		return
	end

	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and (child.Name == BAT_NAME or child.Name == BALL_NAME or child:GetAttribute("GearId")) then
					child:Destroy()
				end
			end
		end
	end

	local bat = createBat(Config.getBat(data.bat) or Config.Bats[1])
	bat.Activated:Connect(function()
		onSwing(player, bat)
	end)
	bat.Parent = backpack

	local ballDef = Config.getBall(player:GetAttribute("SelectedBall") or "Basica") or Config.Balls[1]
	createBallTool(ballDef).Parent = backpack

	for _, gear in ipairs(Config.Gear) do
		if data.ownedGear[gear.id] then
			createGearTool(player, gear).Parent = backpack
		end
	end
	ToolService.refreshMovement(player)
end

function ToolService.start()
	Remotes.ThrowBall.OnServerEvent:Connect(throwBall)

	local function watch(player: Player)
		player:GetAttributeChangedSignal("Carrying"):Connect(function()
			ToolService.refreshMovement(player)
		end)
		player:GetAttributeChangedSignal("Frozen"):Connect(function()
			ToolService.refreshMovement(player)
		end)
		player:GetAttributeChangedSignal("BreakInvisibility"):Connect(function()
			if player:GetAttribute("BreakInvisibility") then
				player:SetAttribute("BreakInvisibility", nil)
				if player:GetAttribute("Invisible") then
					setInvisible(player, false)
				end
			end
		end)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Invisible", nil)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastThrow[player] = nil
		gearCooldown[player] = nil
	end)
end

return ToolService
