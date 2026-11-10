-- Monta o visual de cada brainrot usando peças (Parts).
-- Se quiser usar modelos feitos por você: coloque um Model em
-- ServerStorage/BrainrotModels com o MESMO id da Config (ex: "Sapo").
-- O modelo precisa ter uma PrimaryPart no centro do corpo.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BrainrotModels = {}

local function makePart(parent, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		part[k] = v
	end
	part.Parent = parent
	return part
end

local function buildFromParts(def, scale: number)
	local s = scale
	local size = def.size * s
	local model = Instance.new("Model")
	model.Name = def.id

	local root = makePart(model, {
		Name = "Root",
		Size = size,
		Transparency = 1,
		CFrame = CFrame.new(),
	})
	model.PrimaryPart = root

	-- CORPO
	local body
	if def.shape == "Ball" then
		body = makePart(model, {
			Name = "Body", Shape = Enum.PartType.Ball,
			Size = Vector3.new(size.X, size.X, size.X), Color = def.bodyColor, CFrame = CFrame.new(),
		})
	elseif def.shape == "Cylinder" then
		-- cilindros do Roblox ficam deitados no eixo X, então giramos para ficar em pé
		body = makePart(model, {
			Name = "Body", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(size.Y, size.X, size.X), Color = def.bodyColor,
			CFrame = CFrame.Angles(0, 0, math.rad(90)),
		})
	else
		body = makePart(model, {
			Name = "Body", Size = size, Color = def.bodyColor, CFrame = CFrame.new(),
		})
	end

	local halfY = size.Y / 2
	local front = -size.Z / 2 -- frente do modelo é -Z

	-- OLHOS
	local eyeSize = math.max(size.X * 0.28, 0.6)
	for _, side in ipairs({ -1, 1 }) do
		local eyePos = Vector3.new(side * size.X * 0.22, halfY * 0.35, front * 0.85)
		makePart(model, {
			Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * eyeSize,
			Color = Color3.new(1, 1, 1), CFrame = CFrame.new(eyePos),
		})
		makePart(model, {
			Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * eyeSize * 0.5,
			Color = Color3.new(0, 0, 0), CFrame = CFrame.new(eyePos + Vector3.new(0, 0, -eyeSize * 0.35)),
		})
	end

	-- BOCA
	makePart(model, {
		Name = "Mouth", Size = Vector3.new(size.X * 0.4, 0.25 * s, 0.2 * s),
		Color = Color3.fromRGB(60, 20, 20), CFrame = CFrame.new(0, -halfY * 0.25, front * 0.92),
	})

	-- PÉS
	for _, side in ipairs({ -1, 1 }) do
		makePart(model, {
			Name = "Foot", Size = Vector3.new(0.9, 0.7, 1.2) * s, Color = def.accentColor,
			CFrame = CFrame.new(side * size.X * 0.25, -halfY - 0.3 * s, 0),
		})
	end

	-- ACESSÓRIO
	local acc = def.accessory
	local accent = def.accentColor
	if acc == "Antena" then
		makePart(model, {
			Name = "Antenna", Size = Vector3.new(0.2, 1.6, 0.2) * s, Color = Color3.fromRGB(40, 40, 40),
			CFrame = CFrame.new(0, halfY + 0.8 * s, 0),
		})
		makePart(model, {
			Name = "AntennaTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7 * s,
			Color = accent, Material = Enum.Material.Neon, CFrame = CFrame.new(0, halfY + 1.7 * s, 0),
		})
	elseif acc == "Chapeu" then
		makePart(model, {
			Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2 * s, size.X * 0.9, size.X * 0.9),
			Color = accent, CFrame = CFrame.new(0, halfY, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
		makePart(model, {
			Name = "HatTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4 * s, size.X * 0.55, size.X * 0.55),
			Color = accent, CFrame = CFrame.new(0, halfY + 0.7 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
	elseif acc == "Orelhas" then
		for _, side in ipairs({ -1, 1 }) do
			makePart(model, {
				Name = "Ear", Size = Vector3.new(0.5, 1.2, 0.8) * s, Color = accent,
				CFrame = CFrame.new(side * size.X * 0.35, halfY + 0.4 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)),
			})
		end
	elseif acc == "Asas" then
		for _, side in ipairs({ -1, 1 }) do
			makePart(model, {
				Name = "Wing", Size = Vector3.new(2.2, 0.2, 1.4) * s, Color = Color3.new(1, 1, 1),
				CFrame = CFrame.new(side * (size.X / 2 + 1 * s), halfY * 0.3, 0) * CFrame.Angles(0, 0, math.rad(side * 25)),
			})
		end
	elseif acc == "Disco" then
		makePart(model, {
			Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3 * s, 2 * s, 2 * s),
			Color = accent, Material = Enum.Material.Metal,
			CFrame = CFrame.new(size.X / 2 + 0.3 * s, 0, 0),
		})
	elseif acc == "Capacete" then
		makePart(model, {
			Name = "Helmet", Shape = Enum.PartType.Ball, Size = Vector3.one * size.X * 1.25,
			Color = accent, Material = Enum.Material.Glass, Transparency = 0.6, CFrame = CFrame.new(),
		})
		makePart(model, {
			Name = "Crown", Size = Vector3.new(size.X * 0.5, 0.5 * s, size.X * 0.5), Color = Color3.fromRGB(255, 210, 40),
			Material = Enum.Material.Neon, CFrame = CFrame.new(0, size.X * 0.65, 0),
		})
	elseif acc == "Coroa" then
		makePart(model, {
			Name = "Crown", Size = Vector3.new(size.X * 0.6, 0.6 * s, size.X * 0.6), Color = Color3.fromRGB(255, 210, 40),
			Material = Enum.Material.Neon, CFrame = CFrame.new(0, halfY + 0.3 * s, 0),
		})
	end

	-- brilho para os mais raros
	if def.rarity == "Lendario" or def.rarity == "Mitico" then
		local light = Instance.new("PointLight")
		light.Color = Config.getRarity(def.rarity).color
		light.Range = 12
		light.Brightness = 2
		light.Parent = body
	end

	-- altura do centro do corpo até o chão
	model:SetAttribute("HipHeight", halfY + 0.65 * s)
	return model
end

-- Efeitos das evoluções: 2ª evolução brilha, 3ª ganha coroa e aura
local function applyStage(model: Model, def, stage: number)
	if stage < 2 or not model.PrimaryPart then
		return
	end
	local root = model.PrimaryPart
	local color = Config.getRarity(def.rarity).color

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "EvoAura"
	aura.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	aura.LightEmission = 0.8
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new(0.3)
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Rate = if stage >= 3 then 25 else 10
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = root

	if stage >= 3 then
		local _, size = model:GetBoundingBox()
		local crown = Instance.new("Part")
		crown.Name = "EvoCrown"
		crown.Anchored = true
		crown.CanCollide = false
		crown.CanTouch = false
		crown.Material = Enum.Material.Neon
		crown.Color = Color3.fromRGB(255, 215, 50)
		crown.Size = Vector3.new(size.X * 0.45, 0.5, size.X * 0.45)
		crown.CFrame = root.CFrame * CFrame.new(0, size.Y / 2 + 0.6, 0)
		crown.Parent = model
		for i = 0, 3 do
			local spike = Instance.new("Part")
			spike.Name = "EvoSpike"
			spike.Anchored = true
			spike.CanCollide = false
			spike.CanTouch = false
			spike.Material = Enum.Material.Neon
			spike.Color = crown.Color
			spike.Size = Vector3.new(0.35, 0.8, 0.35)
			local angle = i * math.pi / 2
			spike.CFrame = crown.CFrame * CFrame.new(math.cos(angle) * size.X * 0.18, 0.6, math.sin(angle) * size.X * 0.18)
			spike.Parent = model
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 14
		light.Brightness = 3
		light.Parent = root
	end
end

-- Cria um novo modelo do brainrot. scale = tamanho (1 = normal). stage = evolução (1, 2 ou 3).
function BrainrotModels.build(def, scale: number?, stage: number?)
	local model = BrainrotModels.buildBase(def, scale or 1)
	applyStage(model, def, stage or 1)
	return model
end

function BrainrotModels.buildBase(def, scale: number)
	local folder = ServerStorage:FindFirstChild("BrainrotModels")
	local custom = folder and folder:FindFirstChild(def.id)
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local model = custom:Clone()
		model.Name = def.id
		if scale ~= 1 then
			model:ScaleTo(scale)
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
			end
		end
		if model:GetAttribute("HipHeight") == nil then
			local _, bbSize = model:GetBoundingBox()
			model:SetAttribute("HipHeight", bbSize.Y / 2)
		end
		return model
	end
	return buildFromParts(def, scale)
end

return BrainrotModels
