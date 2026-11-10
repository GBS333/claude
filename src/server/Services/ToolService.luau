-- Ferramentas: o TACO de beisebol (bater) e a BOLA DE CAPTURA (capturar).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local WildService = require(script.Parent.WildService)
local Remotes = require(script.Parent.Remotes)

local ToolService = {}

local BAT_NAME = "Taco"
local BALL_NAME = "Bola"
local C = Config.Catch

local lastSwing = {} -- [Player] = os.clock()
local lastThrow = {}

---------------------------------------------------------------------
-- TACO
---------------------------------------------------------------------
local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function createBat(batDef)
	local tool = Instance.new("Tool")
	tool.Name = BAT_NAME
	tool.ToolTip = batDef.name .. " (dano " .. batDef.damage .. ")"
	tool.CanBeDropped = false
	tool:SetAttribute("BatId", batDef.id)
	-- segura igual a espada clássica: o taco aponta para cima
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, -0.8), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 0.45, 2.4)
	handle.Color = batDef.color
	handle.Material = batDef.material
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- parte grossa do taco
	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(2.6, 0.8, 0.8)
	barrel.Color = batDef.color
	barrel.Material = batDef.material
	barrel.CanCollide = false
	barrel.Massless = true
	barrel.CFrame = handle.CFrame * CFrame.new(0, 0, 2.4) * CFrame.Angles(0, math.rad(90), 0)
	barrel.Parent = tool
	weld(handle, barrel)

	-- fita do cabo
	local grip = Instance.new("Part")
	grip.Name = "Tape"
	grip.Size = Vector3.new(0.5, 0.5, 1)
	grip.Color = Color3.fromRGB(30, 30, 30)
	grip.Material = Enum.Material.Fabric
	grip.CanCollide = false
	grip.Massless = true
	grip.CFrame = handle.CFrame * CFrame.new(0, 0, -0.8)
	grip.Parent = tool
	weld(handle, grip)

	if batDef.id == "Diamante" or batDef.id == "Ouro" then
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = batDef.color
		sparkle.Parent = barrel
	end

	return tool
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

	-- animação de golpe (funciona com o script Animate padrão do Roblox)
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	Debris:AddItem(anim, 1)

	local target = WildService.findTargetInFront(player, batDef.range)
	if target then
		WildService.damage(target, batDef.damage, player)
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

	-- flash de luz quando o brainrot entra na bola
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
		DataService.addBrainrot(player, def.id)
		Remotes.CatchResult:FireClient(player, true, def.id, chance)
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
	if magnitude ~= magnitude or magnitude > 1e5 then -- ignora valores inválidos (NaN/gigantes)
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
		Remotes.notify(player, "Você não tem " .. ballDef.name .. "! Compre na Loja 🛒", Color3.fromRGB(255, 120, 120))
		return
	end
	lastThrow[player] = now

	-- calcula o arremesso em arco
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
	ball.CFrame = CFrame.new(origin) -- as outras peças da bola estão soldadas e acompanham
	ball.Parent = workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, ball }

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
			if state and WildService.isAlive(state) and not state.capturing then
				task.spawn(attemptCapture, player, state, ball, ballDef)
			else
				-- errou: a bola quebra
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
			for _, name in ipairs({ BAT_NAME, BALL_NAME }) do
				local old = container:FindFirstChild(name)
				if old then
					old:Destroy()
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
	local ballTool = createBallTool(ballDef)
	ballTool.Parent = backpack
end

function ToolService.start()
	Remotes.ThrowBall.OnServerEvent:Connect(throwBall)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastThrow[player] = nil
	end)
end

return ToolService
