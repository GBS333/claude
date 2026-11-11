-- Constrói o mapa: uma ilha grande com mar em volta e 6 BIOMAS
-- (Floresta, Deserto, Pântano, Montanha de Neve, Vulcão e o Céu Celestial flutuando),
-- caminhos de pedra, praça do spawn com o Portal Celestial, Arena de Duelo e decoração.
-- As bases (tycoons) são construídas pelo TycoonService.

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

local CARTOON = Config.MapStyle ~= "Realista"

-- cores do estilo "Desenho" para cada material de terreno
local CARTOON_COLORS = {
	[M.Grass] = RGB(120, 205, 90),
	[M.LeafyGrass] = RGB(95, 190, 80),
	[M.Sand] = RGB(250, 222, 140),
	[M.Mud] = RGB(125, 105, 75),
	[M.Snow] = RGB(240, 248, 255),
	[M.Basalt] = RGB(70, 62, 72),
	[M.Rock] = RGB(160, 155, 165),
	[M.Salt] = RGB(225, 235, 255),
	[M.Cobblestone] = RGB(215, 205, 185),
	[M.CrackedLava] = RGB(255, 120, 30),
	[M.Water] = RGB(80, 180, 240),
}

local groundFolder -- peças do chão no estilo "Desenho"

-- No estilo "Realista" usa o terreno do Roblox; no "Desenho" cria peças lisas.
-- lift = sobe um pouquinho a peça para ela aparecer por cima das outras (sem piscar)
local function fillBlock(cf: CFrame, size: Vector3, material, lift: number?)
	if not CARTOON then
		terrain:FillBlock(cf, size, material)
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf + V(0, lift or 0, 0)
	p.Color = CARTOON_COLORS[material] or RGB(200, 200, 200)
	p.Material = if material == M.CrackedLava then M.Neon else M.SmoothPlastic
	if material == M.Water then
		p.Transparency = 0.15
		p.CanCollide = false
	end
	p.Parent = groundFolder
end

local function fillBall(pos: Vector3, radius: number, material)
	if not CARTOON then
		terrain:FillBall(pos, radius, material)
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * radius * 2
	p.CFrame = CFrame.new(pos)
	p.Color = CARTOON_COLORS[material] or RGB(200, 200, 200)
	p.Material = if material == M.CrackedLava then M.Neon else M.SmoothPlastic
	p.Parent = groundFolder
end

-- Deixa tudo liso (sem texturas de madeira, tijolo, grama...) no estilo "Desenho"
local KEEP_MATERIALS = {
	[M.Neon] = true, [M.Glass] = true, [M.ForceField] = true, [M.SmoothPlastic] = true, [M.Metal] = true,
}
function WorldBuilder.applyStyle(root: Instance)
	if not CARTOON then
		return
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and not KEEP_MATERIALS[d.Material] then
			d.Material = M.SmoothPlastic
		end
	end
end

local ISLAND = 1120
local BEACH = 40
local HUB = V(-170, 0, 0)

---------------------------------------------------------------------
-- Ajudantes
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
		label.RichText = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = gui
		gui.Parent = board
	end
end

local blocked = {}
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

local function path(x1, z1, x2, z2, width)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local sx = math.abs(x2 - x1) + width
	local sz = math.abs(z2 - z1) + width
	fillBlock(CFrame.new(cx, -2, cz), V(sx, 4, sz), M.Cobblestone, 0.1)
	block(cx, cz, sx, sz)
end

local function unlockText(biome): string
	local u = biome.unlock or {}
	local parts = {}
	if u.level then
		table.insert(parts, "Nível " .. u.level)
	end
	if u.boss then
		local boss = Config.getBoss(u.boss)
		table.insert(parts, "Derrote " .. (if boss then boss.name else u.boss))
	end
	if u.rebirths then
		table.insert(parts, u.rebirths .. " Rebirth")
	end
	if #parts == 0 then
		return "Livre"
	end
	return "🔒 " .. table.concat(parts, " + ")
end

-- ponto aleatório dentro do bioma, longe das entradas e do chefão
local function biomePoint(biome, margin: number)
	local c = biome.center
	for _ = 1, 20 do
		local x = c.X + rng:NextNumber(-biome.size.X / 2 + margin, biome.size.X / 2 - margin)
		local z = c.Z + rng:NextNumber(-biome.size.Y / 2 + margin, biome.size.Y / 2 - margin)
		local ok = true
		local relX, relZ = x - c.X, z - c.Z
		if (math.abs(relX) < 16 and math.abs(math.abs(relZ) - biome.size.Y / 2) < 20)
			or (math.abs(relZ) < 16 and math.abs(math.abs(relX) - biome.size.X / 2) < 20) then
			ok = false -- perto de uma entrada
		end
		for _, boss in ipairs(Config.Bosses) do
			if boss.biome == biome.id and (V(x, 0, z) - V(boss.position.X, 0, boss.position.Z)).Magnitude < 30 then
				ok = false
			end
		end
		if biome.id == "Floresta" and V(relX, 0, relZ).Magnitude < 22 then
			ok = false -- estátua
		end
		if ok then
			return V(x, c.Y, z)
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Peças de decoração
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

local function pineTree(parent, pos: Vector3, snowy: boolean?)
	local height = rng:NextNumber(4, 6)
	cyl(parent, 1.4, height, pos + V(0, height / 2, 0), RGB(100, 65, 40), M.Wood)
	local green = RGB(40, rng:NextInteger(110, 140), 60)
	local y = height
	for i = 0, 3 do
		local d = 9 - i * 2
		cyl(parent, d, 2.2, pos + V(0, y + 1.1, 0), green, M.Grass).CanCollide = false
		if snowy then
			cyl(parent, d * 0.9, 0.5, pos + V(0, y + 2.3, 0), RGB(245, 250, 255), M.Snow).CanCollide = false
		end
		y += 2
	end
end

local function flowers(parent, center: Vector3, count: number)
	local colors = { RGB(255, 90, 120), RGB(255, 220, 60), RGB(255, 255, 255), RGB(170, 110, 255), RGB(255, 150, 60) }
	local color = colors[rng:NextInteger(1, #colors)]
	for _ = 1, count do
		local pos = center + V(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		part(parent, { Size = V(0.15, 0.8, 0.15), CFrame = CFrame.new(pos + V(0, 0.4, 0)), Color = RGB(60, 140, 50), CanCollide = false, CastShadow = false })
		ball(parent, 0.6, pos + V(0, 0.9, 0), color).CastShadow = false
	end
end

local function rock(parent, pos: Vector3, color: Color3?, material)
	local size = V(rng:NextNumber(2, 5), rng:NextNumber(1.5, 3.5), rng:NextNumber(2, 5))
	part(parent, {
		Size = size, CFrame = CFrame.new(pos + V(0, size.Y / 2 - 0.4, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		Color = color or RGB(130, 125, 120), Material = material or M.Slate,
	})
end

local function cactus(parent, pos: Vector3)
	local green = RGB(70, 150, 70)
	local height = rng:NextNumber(5, 9)
	cyl(parent, 1.6, height, pos + V(0, height / 2, 0), green, M.Grass)
	ball(parent, 1.6, pos + V(0, height, 0), green, M.Grass)
	for _, s in ipairs({ -1, 1 }) do
		if rng:NextNumber() < 0.75 then
			local armY = rng:NextNumber(height * 0.35, height * 0.65)
			part(parent, { Shape = Enum.PartType.Cylinder, Size = V(1.6, 1, 1), CFrame = CFrame.new(pos + V(s * 1.2, armY, 0)), Color = green, Material = M.Grass })
			cyl(parent, 1, 2.4, pos + V(s * 2, armY + 1.2, 0), green, M.Grass)
			ball(parent, 1, pos + V(s * 2, armY + 2.4, 0), green, M.Grass)
		end
	end
end

local function deadTree(parent, pos: Vector3)
	local dark = RGB(70, 55, 45)
	local height = rng:NextNumber(8, 13)
	cyl(parent, 1.5, height, pos + V(0, height / 2, 0), dark, M.Wood)
	for _ = 1, 3 do
		local y = rng:NextNumber(height * 0.5, height)
		local a = rng:NextNumber(0, 6.28)
		part(parent, {
			Size = V(0.5, 0.5, 4), CFrame = CFrame.new(pos + V(0, y, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-30), 0, 0) * CFrame.new(0, 0, -2),
			Color = dark, Material = M.Wood,
		})
	end
end

local function snowman(parent, pos: Vector3)
	ball(parent, 4, pos + V(0, 1.8, 0), RGB(250, 250, 255), M.Snow).CanCollide = true
	ball(parent, 3, pos + V(0, 4.6, 0), RGB(250, 250, 255), M.Snow)
	ball(parent, 2.2, pos + V(0, 6.6, 0), RGB(250, 250, 255), M.Snow)
	part(parent, { Size = V(0.3, 0.3, 1), CFrame = CFrame.new(pos + V(0, 6.6, -1.4)), Color = RGB(255, 140, 40), CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		ball(parent, 0.3, pos + V(s * 0.4, 7, -1), RGB(20, 20, 20))
	end
	cyl(parent, 1.6, 1.2, pos + V(0, 8, 0), RGB(30, 30, 30))
end

local function crystal(parent, pos: Vector3, color: Color3)
	local height = rng:NextNumber(3, 7)
	part(parent, {
		Size = V(1.2, height, 1.2), CFrame = CFrame.new(pos + V(0, height / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		Color = color, Material = M.Neon, Transparency = 0.2, CanCollide = false,
	})
end

local function lavaPool(parent, pos: Vector3)
	local size = rng:NextNumber(8, 16)
	local pool = cyl(parent, size, 0.3, pos + V(0, 0.1, 0), RGB(255, 100, 20), M.Neon)
	pool.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 8
	fire.Parent = pool
	local light = Instance.new("PointLight")
	light.Color = RGB(255, 120, 40)
	light.Range = size
	light.Brightness = 2
	light.Parent = pool
end

local function cloud(parent, pos: Vector3, size: number)
	for _ = 1, 4 do
		local p = ball(parent, size * rng:NextNumber(0.6, 1), pos + V(rng:NextNumber(-size, size) * 0.6, rng:NextNumber(-1, 1), rng:NextNumber(-size, size) * 0.4),
			RGB(255, 255, 255), M.SmoothPlastic)
		p.Transparency = 0.15
		p.CastShadow = false
	end
end

local function lamp(parent, pos: Vector3)
	cyl(parent, 0.6, 9, pos + V(0, 4.5, 0), RGB(50, 50, 55), M.Metal)
	local bulb = ball(parent, 1.4, pos + V(0, 9.5, 0), RGB(255, 235, 170), M.Neon)
	local light = Instance.new("PointLight")
	light.Color = RGB(255, 220, 160)
	light.Range = 22
	light.Brightness = 1.5
	light.Parent = bulb
end

local function fence(parent, x1, z1, x2, z2, gapCenter: number?, gapSize: number, y: number, color: Color3)
	local dir = V(x2 - x1, 0, z2 - z1)
	local length = dir.Magnitude
	local unit = dir.Unit
	local start = V(x1, y, z1)
	local function segment(a: number, b: number)
		if b - a < 1 then
			return
		end
		local mid = start + unit * ((a + b) / 2)
		local cf = CFrame.lookAt(mid, mid + unit)
		for _, h in ipairs({ 1.3, 2.5 }) do
			part(parent, { Size = V(0.3, 0.35, b - a), CFrame = cf + V(0, h, 0), Color = color, Material = M.WoodPlanks })
		end
		local d = a
		while d <= b do
			part(parent, { Size = V(0.6, 3.2, 0.6), CFrame = CFrame.new(start + unit * d + V(0, 1.6, 0)), Color = color, Material = M.Wood })
			d += 10
		end
	end
	if gapCenter then
		segment(0, gapCenter - gapSize / 2)
		segment(gapCenter + gapSize / 2, length)
	else
		segment(0, length)
	end
end

local function fenceBiome(parent, biome, color: Color3)
	local c = biome.center
	local hx, hz = biome.size.X / 2, biome.size.Y / 2
	local gap = 22
	fence(parent, c.X - hx, c.Z - hz, c.X + hx, c.Z - hz, hx, gap, c.Y, color)
	fence(parent, c.X - hx, c.Z + hz, c.X + hx, c.Z + hz, hx, gap, c.Y, color)
	fence(parent, c.X - hx, c.Z - hz, c.X - hx, c.Z + hz, hz, gap, c.Y, color)
	fence(parent, c.X + hx, c.Z - hz, c.X + hx, c.Z + hz, hz, gap, c.Y, color)
end

local function arch(parent, pos: Vector3, facing: Vector3, title: string, subtitle: string, color: Color3)
	local cf = CFrame.lookAt(pos, pos + facing)
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Size = V(2, 14, 2), CFrame = cf * CFrame.new(s * 9, 7, 0), Color = RGB(200, 190, 175), Material = M.Brick })
		ball(parent, 2.2, (cf * CFrame.new(s * 9, 14.5, 0)).Position, color, M.Neon)
	end
	local beam = part(parent, { Size = V(22, 5, 1.2), CFrame = cf * CFrame.new(0, 12.5, 0), Color = RGB(70, 45, 30), Material = M.Wood })
	textOn(beam, title .. "\n<font size=\"40\">" .. subtitle .. "</font>", color, { Enum.NormalId.Front, Enum.NormalId.Back })
end

---------------------------------------------------------------------
-- Terreno
---------------------------------------------------------------------
local function buildTerrain()
	terrain:SetMaterialColor(M.Grass, RGB(100, 180, 75))
	terrain:SetMaterialColor(M.LeafyGrass, RGB(80, 160, 65))
	terrain:SetMaterialColor(M.Cobblestone, RGB(160, 150, 135))
	terrain:SetMaterialColor(M.Sand, RGB(235, 215, 155))
	terrain:SetMaterialColor(M.Mud, RGB(85, 75, 55))
	terrain:SetMaterialColor(M.Basalt, RGB(55, 50, 50))
	terrain:SetMaterialColor(M.Rock, RGB(125, 120, 115))
	terrain:SetMaterialColor(M.Salt, RGB(240, 245, 255))
	terrain.WaterColor = RGB(40, 150, 210)
	terrain.WaterTransparency = 0.4
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 8
	pcall(function()
		terrain.Decoration = true
	end)

	terrain:FillBlock(CFrame.new(0, -24, 0), V(1800, 4, 1800), M.Sand)
	terrain:FillBlock(CFrame.new(0, -12, 0), V(1800, 20, 1800), M.Water)
	fillBlock(CFrame.new(0, -8, 0), V(ISLAND + BEACH * 2, 16, ISLAND + BEACH * 2), M.Sand, -0.3)
	fillBlock(CFrame.new(0, -8, 0), V(ISLAND, 16, ISLAND), M.Grass, 0)

	local materials = {
		Floresta = M.LeafyGrass, Deserto = M.Sand, Pantano = M.Mud, Neve = M.Snow, Vulcao = M.Basalt,
	}
	for _, biome in ipairs(Config.Biomes) do
		local c = biome.center
		if biome.id == "Ceu" then
			fillBlock(CFrame.new(c.X, c.Y - 5, c.Z), V(biome.size.X, 10, biome.size.Y), M.Salt, 0)
			fillBall(c + V(0, -55, 0), 50, M.Rock)
			fillBall(c + V(-50, -35, 30), 28, M.Rock)
			fillBall(c + V(55, -38, -25), 30, M.Rock)
		else
			fillBlock(CFrame.new(c.X, -2, c.Z), V(biome.size.X, 4, biome.size.Y), materials[biome.id] or M.Grass, 0.05)
			block(c.X, c.Z, biome.size.X + 10, biome.size.Y + 10)
		end
	end

	-- poças no pântano e lava rachada no vulcão
	local swamp = Config.getBiome("Pantano")
	if swamp then
		for _ = 1, 10 do
			local p = biomePoint(swamp, 20)
			if p then
				fillBlock(CFrame.new(p.X, -1, p.Z), V(rng:NextInteger(3, 6) * 4, 2, rng:NextInteger(3, 5) * 4), M.Water, 0.12)
			end
		end
	end
	local volcano = Config.getBiome("Vulcao")
	if volcano then
		for _ = 1, 14 do
			local p = biomePoint(volcano, 15)
			if p then
				fillBlock(CFrame.new(p.X, -2, p.Z), V(rng:NextInteger(2, 5) * 4, 4, rng:NextInteger(2, 5) * 4), M.CrackedLava, 0.12)
			end
		end
	end

	-- caminhos de pedra
	for _, info in ipairs(Config.Tycoon.Plots) do
		local p = info.position
		block(p.X, p.Z, Config.Tycoon.PlotSize + 6, Config.Tycoon.PlotSize + 6)
		local dir = if p.Z > 0 then -1 else 1
		local front = p.Z + dir * Config.Tycoon.PlotSize / 2
		path(p.X, front, p.X, front + dir * 14, 10)
	end
	for _, s in ipairs({ -1, 1 }) do
		path(-140, s * 136, 140, s * 136, 10)
		path(0, s * 136, 0, s * 112, 10)
	end
	path(110, 0, 230, 0, 10) -- floresta -> deserto
	path(-230, 0, -110, 0, 10) -- pântano -> praça -> floresta
	path(65, -136, 65, -312, 10) -- até a neve
	path(65, -312, 0, -312, 10)
	path(-65, 136, -65, 312, 10) -- até o vulcão
	path(-65, 312, 0, 312, 10)
	path(170, 0, 170, -56, 8) -- arena
	block(HUB.X, HUB.Z, 60, 110)
	block(Config.Duel.Arena.X, Config.Duel.Arena.Z, 80, 80)

	-- montanhas
	local function mountain(pos: Vector3, radius: number, top)
		fillBall(pos, radius, if CARTOON then M.Grass else M.Rock)
		fillBall(pos + V(0, -radius * 0.25, 0), radius * 0.95, top or M.Grass)
		block(pos.X, pos.Z, radius * 2, radius * 2)
	end
	mountain(V(-480, -12, -480), 50)
	mountain(V(480, -12, -480), 50)
	mountain(V(-480, -12, 480), 50)
	mountain(V(480, -12, 480), 50)
	for _, x in ipairs({ -330, 330 }) do
		fillBall(V(x, -10, -430), 58, M.Rock)
		fillBall(V(x, 26, -430), 26, M.Snow)
		block(x, -430, 116, 116)
	end
	for _, x in ipairs({ -330, 330 }) do
		fillBall(V(x, -14, 430), 62, M.Basalt)
		fillBall(V(x, 40, 430), 14, M.CrackedLava)
		block(x, 430, 124, 124)
	end
end

---------------------------------------------------------------------
-- Biomas
---------------------------------------------------------------------
local function decorateBiome(parent, biome)
	local folder = Instance.new("Folder")
	folder.Name = biome.id
	folder.Parent = parent
	local function scatter(count: number, margin: number, fn)
		for _ = 1, count do
			local p = biomePoint(biome, margin)
			if p then
				fn(p)
			end
		end
	end

	if biome.id == "Floresta" then
		scatter(22, 8, function(p)
			if rng:NextNumber() < 0.6 then
				roundTree(folder, p)
			else
				pineTree(folder, p)
			end
		end)
		scatter(30, 4, function(p)
			flowers(folder, p, rng:NextInteger(4, 8))
		end)
		scatter(8, 6, function(p)
			rock(folder, p)
		end)
	elseif biome.id == "Deserto" then
		scatter(26, 8, function(p)
			cactus(folder, p)
		end)
		scatter(16, 6, function(p)
			rock(folder, p, RGB(200, 160, 110), M.Sandstone)
		end)
		scatter(6, 6, function(p)
			part(folder, { Size = V(0.6, 0.6, 3), CFrame = CFrame.new(p + V(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
				Color = RGB(240, 235, 220), CanCollide = false })
		end)
	elseif biome.id == "Pantano" then
		scatter(18, 8, function(p)
			deadTree(folder, p)
		end)
		scatter(30, 4, function(p)
			for _ = 1, 4 do
				cyl(folder, 0.2, rng:NextNumber(2, 4), p + V(rng:NextNumber(-1.5, 1.5), 1.2, rng:NextNumber(-1.5, 1.5)), RGB(90, 120, 60)).CanCollide = false
			end
		end)
		scatter(14, 4, function(p)
			cyl(folder, 0.5, 1.2, p + V(0, 0.6, 0), RGB(230, 220, 200))
			cyl(folder, 2, 0.5, p + V(0, 1.3, 0), RGB(200, 60, 60)).CanCollide = false
		end)
	elseif biome.id == "Neve" then
		scatter(28, 8, function(p)
			pineTree(folder, p, true)
		end)
		scatter(14, 6, function(p)
			crystal(folder, p, RGB(150, 220, 255))
		end)
		scatter(5, 10, function(p)
			snowman(folder, p)
		end)
	elseif biome.id == "Vulcao" then
		scatter(12, 10, function(p)
			lavaPool(folder, p)
		end)
		scatter(20, 6, function(p)
			rock(folder, p, RGB(40, 35, 35), M.Basalt)
		end)
		scatter(8, 6, function(p)
			crystal(folder, p, RGB(255, 120, 40))
		end)
	elseif biome.id == "Ceu" then
		scatter(16, 6, function(p)
			crystal(folder, p, RGB(130, 240, 255))
		end)
		scatter(20, 4, function(p)
			flowers(folder, p, rng:NextInteger(4, 7))
		end)
		for i = 0, 7 do
			local a = i * math.pi / 4
			local c = biome.center
			local pos = c + V(math.cos(a) * 85, 0, math.sin(a) * 85)
			cyl(folder, 2.5, 14, pos + V(0, 7, 0), RGB(255, 225, 130), M.Marble)
			ball(folder, 3, pos + V(0, 15, 0), RGB(130, 240, 255), M.Neon)
		end
		for _ = 1, 14 do
			local a = rng:NextNumber(0, 6.28)
			local r = rng:NextNumber(110, 170)
			cloud(folder, biome.center + V(math.cos(a) * r, rng:NextNumber(-25, 15), math.sin(a) * r), rng:NextNumber(8, 14))
		end
	end
end

local function biomeEntrances(parent)
	local colors = {
		Floresta = RGB(130, 230, 110), Deserto = RGB(255, 210, 110), Pantano = RGB(150, 200, 90),
		Neve = RGB(180, 230, 255), Vulcao = RGB(255, 120, 60), Ceu = RGB(130, 240, 255),
	}
	-- direção da entrada principal de cada bioma (para onde o portal olha)
	local mainGate = { Deserto = V(-1, 0, 0), Pantano = V(1, 0, 0), Neve = V(0, 0, 1), Vulcao = V(0, 0, -1) }
	for _, biome in ipairs(Config.Biomes) do
		local color = colors[biome.id] or RGB(255, 255, 255)
		if biome.id ~= "Ceu" then
			fenceBiome(parent, biome, if biome.id == "Neve" then RGB(220, 225, 235) else RGB(150, 105, 65))
		end
		local c = biome.center
		local title = biome.icon .. " " .. string.upper(biome.name)
		if biome.id == "Floresta" then
			local hx, hz = biome.size.X / 2, biome.size.Y / 2
			for _, dir in ipairs({ V(0, 0, 1), V(0, 0, -1), V(1, 0, 0), V(-1, 0, 0) }) do
				arch(parent, c + V(dir.X * hx, 0, dir.Z * hz), dir, title, "Livre", color)
			end
		elseif mainGate[biome.id] then
			local dir = mainGate[biome.id]
			local pos = c + V(dir.X * biome.size.X / 2, 0, dir.Z * biome.size.Y / 2)
			arch(parent, pos, dir, title, unlockText(biome), color)
		end
	end
end

---------------------------------------------------------------------
-- Praça do spawn, portais e arena
---------------------------------------------------------------------
local function buildHub(parent)
	-- piso
	part(parent, { Name = "HubFloor", Size = V(50, 0.4, 100), CFrame = CFrame.new(HUB + V(0, 0.2, 0)), Color = RGB(225, 220, 210), Material = M.Marble })
	local board = part(parent, { Name = "InfoBoard", Size = V(22, 11, 1), CFrame = CFrame.new(HUB + V(-22, 6.5, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = RGB(60, 45, 35), Material = M.Wood })
	textOn(board, "🏏 BRAINROT TYCOON\n<font size=\"30\">Bata • Capture • Evolua • Roube • Duele</font>\n"
		.. "<font size=\"24\">Menu 🗺 Áreas para viajar</font>", RGB(255, 230, 120), { Enum.NormalId.Front })

	-- portal para o Céu Celestial
	local portalPos = HUB + V(0, 0, 36)
	local pad = cyl(parent, 12, 0.6, portalPos + V(0, 0.4, 0), RGB(130, 240, 255), M.Neon)
	pad.Name = "PortalCeu"
	pad.CanCollide = false
	local ring = part(parent, { Shape = Enum.PartType.Cylinder, Size = V(0.6, 16, 16),
		CFrame = CFrame.new(portalPos + V(0, 8.5, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = RGB(255, 230, 120), Material = M.Neon, CanCollide = false, Transparency = 0.3 })
	ring.Name = "PortalRing"
	local sign = part(parent, { Size = V(18, 3, 0.6), CFrame = CFrame.new(portalPos + V(0, 18, 0)), Color = RGB(40, 40, 70), Material = M.SmoothPlastic })
	textOn(sign, "☁ PORTAL CELESTIAL\n<font size=\"30\">" .. unlockText(Config.getBiome("Ceu") or { unlock = {} }) .. "</font>",
		RGB(150, 240, 255), { Enum.NormalId.Front, Enum.NormalId.Back })
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(RGB(150, 240, 255))
	sparkle.LightEmission = 1
	sparkle.Rate = 20
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Size = NumberSequence.new(0.4)
	sparkle.Parent = pad

	for _, z in ipairs({ -40, 40 }) do
		lamp(parent, HUB + V(18, 0, z))
		lamp(parent, HUB + V(-18, 0, z))
	end

	-- portal de volta no Céu
	local sky = Config.getBiome("Ceu")
	if sky then
		local back = cyl(parent, 10, 0.6, sky.center + V(0, 0.4, sky.size.Y / 2 - 15), RGB(255, 230, 120), M.Neon)
		back.Name = "PortalVolta"
		back.CanCollide = false
		local backSign = part(parent, { Size = V(14, 3, 0.6), CFrame = CFrame.new(back.Position + V(0, 8, 0)), Color = RGB(40, 40, 70) })
		textOn(backSign, "⬇ VOLTAR", RGB(255, 230, 120), { Enum.NormalId.Front, Enum.NormalId.Back })
	end
end

local function buildArena(parent)
	local c = Config.Duel.Arena
	part(parent, { Name = "ArenaFloor", Size = V(70, 1, 70), CFrame = CFrame.new(c + V(0, 0.5, 0)), Color = RGB(180, 70, 70), Material = M.Concrete })
	part(parent, { Name = "ArenaCircle", Shape = Enum.PartType.Cylinder, Size = V(0.2, 40, 40),
		CFrame = CFrame.new(c + V(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = RGB(255, 255, 255), Material = M.SmoothPlastic, CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Size = V(70, 6, 2), CFrame = CFrame.new(c + V(0, 3, s * 35)), Color = RGB(90, 60, 50), Material = M.Brick })
		part(parent, { Size = V(2, 6, 70), CFrame = CFrame.new(c + V(s * 35, 3, 0)), Color = RGB(90, 60, 50), Material = M.Brick })
		cyl(parent, 8, 0.4, c + V(s * Config.Duel.PadOffset, 1.2, 0), if s < 0 then RGB(80, 160, 255) else RGB(255, 90, 90), M.Neon).CanCollide = false
	end
	-- entrada (buraco na parede de baixo, do lado do caminho)
	local sign = part(parent, { Size = V(26, 5, 1), CFrame = CFrame.new(c + V(0, 10, 36)), Color = RGB(60, 30, 30), Material = M.Wood })
	textOn(sign, "⚔ ARENA DE DUELO", RGB(255, 200, 90), { Enum.NormalId.Front, Enum.NormalId.Back })
end

local function statue(parent, center: Vector3)
	local def = Config.getBrainrot("TungTung") or Config.Brainrots[1]
	cyl(parent, 14, 2, center + V(0, 1, 0), RGB(190, 185, 175), M.Marble)
	cyl(parent, 11, 2, center + V(0, 3, 0), RGB(210, 205, 195), M.Marble)
	local plaque = part(parent, { Size = V(8, 1.6, 0.4), CFrame = CFrame.new(center + V(0, 2.6, -5.6)), Color = RGB(255, 205, 60), Material = M.Metal })
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
	effect("Atmosphere", { Density = if CARTOON then 0.18 else 0.28, Offset = 0.2, Color = RGB(200, 225, 255),
		Decay = RGB(110, 145, 190), Glare = 0.2, Haze = if CARTOON then 0.5 else 1 })
	effect("BloomEffect", { Intensity = 0.4, Size = 24, Threshold = 1.6 })
	effect("ColorCorrectionEffect", { Saturation = if CARTOON then 0.3 else 0.18, Contrast = 0.06,
		Brightness = if CARTOON then 0.04 else 0.02, TintColor = RGB(255, 255, 255) })
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

	groundFolder = Instance.new("Folder")
	groundFolder.Name = "Chao"
	groundFolder.Parent = map

	buildTerrain()
	setupLighting()

	local decor = Instance.new("Folder")
	decor.Name = "Decoracao"
	decor.Parent = map
	for _, biome in ipairs(Config.Biomes) do
		decorateBiome(decor, biome)
	end
	biomeEntrances(map)
	statue(map, Config.getBiome("Floresta") and Config.getBiome("Floresta").center or V(0, 0, 0))
	buildHub(map)
	buildArena(map)

	-- floresta em volta (fora dos biomas, bases e caminhos)
	local half = ISLAND / 2 - 8
	local placed = 0
	for _ = 1, 1500 do
		if placed >= 160 then
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

	for _, s in ipairs({ -1, 1 }) do
		for x = -130, 130, 40 do
			lamp(map, V(x, 0, s * 136 + s * 7))
		end
	end

	local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Parent = map
	end
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Anchored = true
	spawnLocation.Size = V(14, 1, 14)
	spawnLocation.CFrame = CFrame.new(HUB + V(0, 0.5, -25))
	spawnLocation.Material = M.Marble
	spawnLocation.Color = RGB(240, 240, 240)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 3

	WorldBuilder.applyStyle(map)
end

return WorldBuilder
