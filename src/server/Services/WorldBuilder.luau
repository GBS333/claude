-- Constrói o mapa: uma ilha de terreno com mar em volta, montanhas, caminhos de pedra,
-- árvores, flores, pedras, a Zona de Caça cercada (com portais e uma estátua no meio)
-- e uma iluminação mais bonita. As bases (tycoons) são construídas pelo TycoonService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local BrainrotModels = require(script.Parent.BrainrotModels)

local WorldBuilder = {}

local V = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material

local terrain = workspace.Terrain
local rng = Random.new(2025)

local ISLAND = 640 -- tamanho da ilha (grama)
local BEACH = 40 -- largura da praia

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

local function cyl(parent, diameter: number, height: number, pos: Vector3, color: Color3, material)
	return part(parent, {
		Shape = Enum.PartType.Cylinder, Size = V(height, diameter, diameter),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material or M.SmoothPlastic,
	})
end

local function ball(parent, diameter: number, pos: Vector3, color: Color3, material)
	return part(parent, {
		Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, CFrame = CFrame.new(pos), Color = color,
		Material = material or M.SmoothPlastic, CanCollide = false,
	})
end

local function textOn(board: BasePart, text: string, color: Color3, faces)
	for _, face in ipairs(faces) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(board.Size.X * 20, board.Size.Y * 20)
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = gui
		gui.Parent = board
	end
end

---------------------------------------------------------------------
-- Onde NÃO colocar decoração (zona de caça, bases, caminhos, spawn)
---------------------------------------------------------------------
local blocked = {} -- lista de retângulos { minX, maxX, minZ, maxZ }

local function block(cx, cz, sx, sz)
	table.insert(blocked, { cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2 })
end

local function isFree(x: number, z: number, margin: number): boolean
	for _, r in ipairs(blocked) do
		if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
			return false
		end
	end
	return true
end

---------------------------------------------------------------------
-- Terreno
---------------------------------------------------------------------
local function path(x1, z1, x2, z2, width)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local sx = math.abs(x2 - x1) + width
	local sz = math.abs(z2 - z1) + width
	terrain:FillBlock(CFrame.new(cx, -2, cz), V(sx, 4, sz), M.Cobblestone)
	block(cx, cz, sx, sz)
end

local function buildTerrain()
	terrain:SetMaterialColor(M.Grass, RGB(100, 180, 75))
	terrain:SetMaterialColor(M.LeafyGrass, RGB(80, 160, 65))
	terrain:SetMaterialColor(M.Cobblestone, RGB(160, 150, 135))
	terrain:SetMaterialColor(M.Sand, RGB(235, 220, 165))
	terrain:SetMaterialColor(M.Rock, RGB(125, 120, 115))
	terrain.WaterColor = RGB(40, 150, 210)
	terrain.WaterTransparency = 0.4
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 8
	pcall(function()
		terrain.Decoration = true -- grama animada (se estiver disponível)
	end)

	-- mar, fundo de areia, praia e a ilha
	terrain:FillBlock(CFrame.new(0, -22, 0), V(1400, 4, 1400), M.Sand)
	terrain:FillBlock(CFrame.new(0, -11, 0), V(1400, 18, 1400), M.Water)
	terrain:FillBlock(CFrame.new(0, -8, 0), V(ISLAND + BEACH * 2, 16, ISLAND + BEACH * 2), M.Sand)
	terrain:FillBlock(CFrame.new(0, -8, 0), V(ISLAND, 16, ISLAND), M.Grass)

	-- zona de caça com grama mais escura
	local W = Config.Wild
	terrain:FillBlock(CFrame.new(W.ZoneCenter.X, -2, W.ZoneCenter.Z), V(W.ZoneSize.X, 4, W.ZoneSize.Y), M.LeafyGrass)
	block(W.ZoneCenter.X, W.ZoneCenter.Z, W.ZoneSize.X + 8, W.ZoneSize.Y + 8)

	-- caminhos de pedra: das bases até a zona de caça
	for _, info in ipairs(Config.Tycoon.Plots) do
		local p = info.position
		block(p.X, p.Z, Config.Tycoon.PlotSize + 6, Config.Tycoon.PlotSize + 6)
		local dir = if p.Z > 0 then -1 else 1
		local front = p.Z + dir * Config.Tycoon.PlotSize / 2
		path(p.X, front, p.X, front + dir * 14, 10)
	end
	local edge = W.ZoneSize.Y / 2
	local roadZ = 136
	for _, s in ipairs({ -1, 1 }) do
		path(-140, s * roadZ, 140, s * roadZ, 10) -- estrada na frente das bases
		path(0, s * roadZ, 0, s * (edge + 2), 10) -- até a entrada da zona
	end
	path(-250, 0, -W.ZoneSize.X / 2 - 2, 0, 10) -- do spawn até a zona
	block(-250, 0, 30, 30)

	-- montanhas nas bordas
	local hills = {
		V(-275, -12, -275), V(275, -12, -275), V(-275, -12, 275), V(275, -12, 275),
		V(-300, -16, -110), V(300, -16, 110), V(300, -16, -120), V(-300, -16, 120),
	}
	for _, pos in ipairs(hills) do
		local radius = rng:NextNumber(38, 52)
		terrain:FillBall(pos, radius, M.Rock)
		terrain:FillBall(pos + V(0, -radius * 0.25, 0), radius * 0.95, M.Grass)
		terrain:FillBall(pos + V(0, radius * 0.75, 0), radius * 0.3, M.Snow)
		block(pos.X, pos.Z, radius * 2, radius * 2)
	end
end

---------------------------------------------------------------------
-- Decoração
---------------------------------------------------------------------
local function roundTree(parent, pos: Vector3)
	local height = rng:NextNumber(9, 15)
	cyl(parent, rng:NextNumber(1.6, 2.4), height, pos + V(0, height / 2, 0), RGB(110, 75, 45), M.Wood)
	local green = RGB(rng:NextInteger(50, 80), rng:NextInteger(140, 185), rng:NextInteger(45, 75))
	local size = rng:NextNumber(8, 11)
	ball(parent, size, pos + V(0, height + size * 0.25, 0), green, M.Grass)
	ball(parent, size * 0.7, pos + V(size * 0.35, height - 0.5, size * 0.1), green, M.Grass)
	ball(parent, size * 0.7, pos + V(-size * 0.3, height, -size * 0.25), green, M.Grass)
end

local function pineTree(parent, pos: Vector3)
	local height = rng:NextNumber(4, 6)
	cyl(parent, 1.4, height, pos + V(0, height / 2, 0), RGB(100, 65, 40), M.Wood)
	local green = RGB(40, rng:NextInteger(110, 140), 60)
	local y = height
	for i = 0, 3 do
		local d = 9 - i * 2
		cyl(parent, d, 2.2, pos + V(0, y + 1.1, 0), green, M.Grass).CanCollide = false
		y += 2
	end
end

local function flowers(parent, center: Vector3, count: number)
	local colors = { RGB(255, 90, 120), RGB(255, 220, 60), RGB(255, 255, 255), RGB(170, 110, 255), RGB(255, 150, 60) }
	local color = colors[rng:NextInteger(1, #colors)]
	for _ = 1, count do
		local pos = center + V(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		part(parent, {
			Size = V(0.15, 0.8, 0.15), CFrame = CFrame.new(pos + V(0, 0.4, 0)), Color = RGB(60, 140, 50),
			CanCollide = false, CastShadow = false,
		})
		ball(parent, 0.6, pos + V(0, 0.9, 0), color).CastShadow = false
	end
end

local function rock(parent, pos: Vector3)
	local size = V(rng:NextNumber(2, 5), rng:NextNumber(1.5, 3.5), rng:NextNumber(2, 5))
	part(parent, {
		Size = size, CFrame = CFrame.new(pos + V(0, size.Y / 2 - 0.4, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		Color = RGB(130, 125, 120), Material = M.Slate,
	})
end

local function lamp(parent, pos: Vector3)
	cyl(parent, 0.6, 9, pos + V(0, 4.5, 0), RGB(50, 50, 55), M.Metal)
	local light = ball(parent, 1.4, pos + V(0, 9.5, 0), RGB(255, 235, 170), M.Neon)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = RGB(255, 220, 160)
	pointLight.Range = 22
	pointLight.Brightness = 1.5
	pointLight.Parent = light
end

local function fence(parent, x1, z1, x2, z2, gapCenter: number?, gapSize: number)
	local dir = V(x2 - x1, 0, z2 - z1)
	local length = dir.Magnitude
	local unit = dir.Unit
	local start = V(x1, 0, z1)
	local wood = RGB(150, 105, 65)
	local function segment(a: number, b: number)
		if b - a < 1 then
			return
		end
		local mid = start + unit * ((a + b) / 2)
		local cf = CFrame.lookAt(mid, mid + unit)
		for _, y in ipairs({ 1.3, 2.5 }) do
			part(parent, { Size = V(0.3, 0.35, b - a), CFrame = cf + V(0, y, 0), Color = wood, Material = M.WoodPlanks })
		end
		local d = a
		while d <= b do
			local p = start + unit * d
			part(parent, { Size = V(0.6, 3.2, 0.6), CFrame = CFrame.new(p + V(0, 1.6, 0)), Color = wood, Material = M.Wood })
			d += 8
		end
	end
	if gapCenter then
		segment(0, gapCenter - gapSize / 2)
		segment(gapCenter + gapSize / 2, length)
	else
		segment(0, length)
	end
end

local function arch(parent, pos: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(pos, pos + facing)
	local stone = RGB(200, 190, 175)
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Size = V(2, 13, 2), CFrame = cf * CFrame.new(s * 8, 6.5, 0), Color = stone, Material = M.Brick })
		ball(parent, 2.2, (cf * CFrame.new(s * 8, 13.5, 0)).Position, RGB(255, 210, 60), M.Neon)
	end
	local beam = part(parent, {
		Size = V(20, 3.5, 1.2), CFrame = cf * CFrame.new(0, 11.5, 0), Color = RGB(70, 45, 30), Material = M.Wood,
	})
	textOn(beam, "🏏 ZONA DE CAÇA 🏏", RGB(255, 230, 90), { Enum.NormalId.Front, Enum.NormalId.Back })
end

local function statue(parent, center: Vector3)
	local def = Config.getBrainrot("TungTung") or Config.Brainrots[1]
	cyl(parent, 14, 2, center + V(0, 1, 0), RGB(190, 185, 175), M.Marble)
	cyl(parent, 11, 2, center + V(0, 3, 0), RGB(210, 205, 195), M.Marble)
	local plaque = part(parent, {
		Size = V(8, 1.6, 0.4), CFrame = CFrame.new(center + V(0, 2.6, -5.6)), Color = RGB(255, 205, 60), Material = M.Metal,
	})
	textOn(plaque, def.name, RGB(60, 40, 10), { Enum.NormalId.Front })
	local model = BrainrotModels.build(def, 2.2)
	local hip = model:GetAttribute("HipHeight") or 3
	model:PivotTo(CFrame.new(center + V(0, 4 + hip, 0)) * CFrame.Angles(0, math.pi, 0))
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	model.Name = "Statue"
	model.Parent = parent
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 3
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = RGB(150, 150, 165)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local function effect(className: string, props)
		local old = Lighting:FindFirstChild("Brainrot" .. className)
		if old then
			old:Destroy()
		end
		local e = Instance.new(className)
		e.Name = "Brainrot" .. className
		for k, v in pairs(props) do
			e[k] = v
		end
		e.Parent = Lighting
	end
	effect("Atmosphere", {
		Density = 0.28, Offset = 0.2, Color = RGB(200, 225, 255), Decay = RGB(110, 145, 190), Glare = 0.2, Haze = 1,
	})
	effect("BloomEffect", { Intensity = 0.4, Size = 24, Threshold = 1.6 })
	effect("ColorCorrectionEffect", { Saturation = 0.18, Contrast = 0.06, Brightness = 0.02 })
	effect("SunRaysEffect", { Intensity = 0.06, Spread = 0.8 })
end

---------------------------------------------------------------------
-- Construir tudo
---------------------------------------------------------------------
function WorldBuilder.build()
	if not Config.BuildMap then
		return
	end
	if workspace:FindFirstChild("Map") then
		workspace.Map:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	buildTerrain()
	setupLighting()

	local W = Config.Wild
	local c = W.ZoneCenter
	local hx, hz = W.ZoneSize.X / 2, W.ZoneSize.Y / 2
	local decor = Instance.new("Folder")
	decor.Name = "Decoracao"
	decor.Parent = map

	-- cerca da zona de caça com entradas no meio de cada lado
	local gap = 20
	fence(map, c.X - hx, c.Z - hz, c.X + hx, c.Z - hz, hx, gap)
	fence(map, c.X - hx, c.Z + hz, c.X + hx, c.Z + hz, hx, gap)
	fence(map, c.X - hx, c.Z - hz, c.X - hx, c.Z + hz, hz, gap)
	fence(map, c.X + hx, c.Z - hz, c.X + hx, c.Z + hz, hz, gap)
	arch(map, V(c.X, 0, c.Z + hz), V(0, 0, 1))
	arch(map, V(c.X, 0, c.Z - hz), V(0, 0, -1))
	arch(map, V(c.X - hx, 0, c.Z), V(-1, 0, 0))
	arch(map, V(c.X + hx, 0, c.Z), V(1, 0, 0))

	-- estátua do Tung Tung no meio da zona
	statue(map, V(c.X, W.GroundY, c.Z))

	-- dentro da zona: árvores, flores e pedras (longe do centro)
	for _ = 1, 22 do
		local x, z = c.X + rng:NextNumber(-hx + 8, hx - 8), c.Z + rng:NextNumber(-hz + 8, hz - 8)
		if V(x - c.X, 0, z - c.Z).Magnitude > 22 then
			if rng:NextNumber() < 0.6 then
				roundTree(decor, V(x, W.GroundY, z))
			else
				pineTree(decor, V(x, W.GroundY, z))
			end
		end
	end
	for _ = 1, 30 do
		local x, z = c.X + rng:NextNumber(-hx + 4, hx - 4), c.Z + rng:NextNumber(-hz + 4, hz - 4)
		if V(x - c.X, 0, z - c.Z).Magnitude > 12 then
			flowers(decor, V(x, W.GroundY, z), rng:NextInteger(4, 8))
		end
	end
	for _ = 1, 10 do
		local x, z = c.X + rng:NextNumber(-hx + 6, hx - 6), c.Z + rng:NextNumber(-hz + 6, hz - 6)
		if V(x - c.X, 0, z - c.Z).Magnitude > 14 then
			rock(decor, V(x, W.GroundY, z))
		end
	end

	-- fora da zona: floresta em volta da ilha (sem cobrir bases e caminhos)
	local half = ISLAND / 2 - 8
	local placed = 0
	for _ = 1, 600 do
		if placed >= 90 then
			break
		end
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		if isFree(x, z, 6) then
			placed += 1
			local roll = rng:NextNumber()
			if roll < 0.45 then
				roundTree(decor, V(x, 0, z))
			elseif roll < 0.8 then
				pineTree(decor, V(x, 0, z))
			elseif roll < 0.92 then
				flowers(decor, V(x, 0, z), rng:NextInteger(5, 9))
			else
				rock(decor, V(x, 0, z))
			end
		end
	end

	-- postes de luz na estrada
	for _, s in ipairs({ -1, 1 }) do
		for x = -130, 130, 40 do
			lamp(map, V(x, 0, s * 136 + s * 7))
		end
	end

	-- SPAWN
	local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Parent = map
	end
	spawnLocation.Anchored = true
	spawnLocation.Size = V(14, 1, 14)
	spawnLocation.CFrame = CFrame.new(-250, 0.5, 0)
	spawnLocation.Material = M.Marble
	spawnLocation.Color = RGB(240, 240, 240)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 3
end

return WorldBuilder
