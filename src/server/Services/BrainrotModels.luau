-- Monta o visual de cada brainrot.
--
-- MODELOS 3D DE VERDADE (recomendado):
--   1. No Studio: View → Toolbox → pesquise o nome (ex.: "Tung Tung Tung Sahur").
--   2. Coloque o modelo dentro de uma pasta chamada "BrainrotModels" em ServerStorage.
--   3. Renomeie o modelo para o "id" que está na Config (ex.: "TungTung", "Tralalero").
--   O jogo ajusta o tamanho sozinho, cria a caixa de acerto e APAGA os scripts do modelo
--   (modelos da Toolbox podem ter vírus).
--
-- Sem modelo na pasta, o jogo monta um boneco com peças no formato de cada brainrot.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BrainrotModels = {}

local V = Vector3.new
local RGB = Color3.fromRGB
local rad = math.rad

local WHITE = RGB(255, 255, 255)
local BLACK = RGB(20, 20, 20)
local DARK_MOUTH = RGB(60, 20, 20)
local SKIN = RGB(240, 200, 165)
local WOOD = Enum.Material.Wood
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon

---------------------------------------------------------------------
-- Ajudante para criar peças
-- shape: "Block", "Ball", "Wedge", "Cyl" (cilindro em pé: size = diâmetro, altura, diâmetro),
--        "CylX" (deitado no eixo X: size = comprimento, diâmetro, diâmetro), "CylZ" (deitado no eixo Z)
---------------------------------------------------------------------
local function maker(model: Model)
	return function(shape: string, size, where, color: Color3, material: Enum.Material?, transparency: number?)
		local part = if shape == "Wedge" then Instance.new("WedgePart") else Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false -- quem recebe os acertos é a caixa "Root"
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Material = material or Enum.Material.SmoothPlastic
		part.Color = color
		part.Transparency = transparency or 0

		local cf = if typeof(where) == "CFrame" then where else CFrame.new(where)
		if typeof(size) == "number" then
			size = V(size, size, size)
		end
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
			part.Size = V(size.X, size.X, size.X)
		elseif shape == "Cyl" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = V(size.Y, size.X, size.X)
			cf = cf * CFrame.Angles(0, 0, rad(90))
		elseif shape == "CylX" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = V(size.X, size.Y, size.Y)
		elseif shape == "CylZ" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = V(size.Z, size.X, size.X)
			cf = cf * CFrame.Angles(0, rad(90), 0)
		else
			part.Size = size
		end
		part.CFrame = cf
		part.Parent = model
		return part
	end
end

-- dois olhos (bola branca + pupila preta) olhando para a frente (-Z)
local function eyes(P, center: Vector3, spacing: number, size: number)
	for _, s in ipairs({ -1, 1 }) do
		local pos = center + V(s * spacing, 0, 0)
		P("Ball", size, pos, WHITE)
		P("Ball", size * 0.5, pos + V(0, 0, -size * 0.32), BLACK)
	end
end

---------------------------------------------------------------------
-- Os brainrots (chão em y = 0, frente = -Z)
---------------------------------------------------------------------
local builders = {}

builders.TungTung = function(P)
	local wood = RGB(200, 155, 105)
	local dark = RGB(105, 70, 40)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.35, 1.4, 0.35), V(s * 0.5, 0.7, 0), wood, WOOD)
		P("Block", V(0.55, 0.3, 0.8), V(s * 0.5, 0.15, -0.15), dark)
		P("Cyl", V(0.3, 1.8, 0.3), CFrame.new(s * 1.35, 3.6, 0) * CFrame.Angles(0, 0, rad(s * 25)), wood, WOOD)
	end
	P("Cyl", V(2.4, 5, 2.4), V(0, 3.9, 0), wood, WOOD) -- a tora
	P("Cyl", V(2.0, 0.05, 2.0), V(0, 6.41, 0), RGB(230, 195, 145), WOOD) -- anel da madeira
	P("Cyl", V(1.2, 0.06, 1.2), V(0, 6.43, 0), RGB(180, 135, 90), WOOD)
	eyes(P, V(0, 5.1, -1.12), 0.5, 0.65)
	P("Block", V(1.3, 0.2, 0.2), V(0, 4.15, -1.17), RGB(50, 25, 15)) -- sorriso
	-- o famoso taco
	local batCF = CFrame.new(1.95, 3.4, -0.35) * CFrame.Angles(rad(-15), 0, rad(-12))
	P("Cyl", V(0.3, 1.6, 0.3), batCF, dark, WOOD)
	P("Cyl", V(0.55, 2.0, 0.55), batCF * CFrame.new(0, 1.7, 0), dark, WOOD)
end

builders.Tralalero = function(P)
	local blue = RGB(95, 145, 200)
	local shoe = RGB(30, 100, 255)
	P("CylZ", V(2.4, 2.4, 4.2), V(0, 2.7, 0.3), blue) -- corpo do tubarão
	P("Ball", 2.4, V(0, 2.7, -1.8), blue) -- focinho
	P("Block", V(1.5, 0.5, 4.4), V(0, 1.75, -0.3), WHITE) -- barriga
	P("Ball", 1.6, V(0, 2.8, 2.6), blue) -- final do corpo
	P("Wedge", V(0.35, 1.6, 1.2), CFrame.new(0, 3.9, 3.2), blue) -- cauda de cima
	P("Wedge", V(0.35, 1.0, 1.0), CFrame.new(0, 2.0, 3.3) * CFrame.Angles(0, 0, rad(180)), blue) -- cauda de baixo
	P("Wedge", V(0.3, 1.4, 1.5), CFrame.new(0, 4.5, 0.4), blue) -- barbatana
	for _, s in ipairs({ -1, 1 }) do
		P("Block", V(1.2, 0.15, 0.7), CFrame.new(s * 1.5, 2.2, -0.6) * CFrame.Angles(0, 0, rad(-s * 25)), blue)
		P("Ball", 0.5, V(s * 0.95, 3.15, -2.3), WHITE)
		P("Ball", 0.28, V(s * 1.05, 3.15, -2.45), BLACK)
	end
	P("Block", V(1.4, 0.25, 0.3), V(0, 2.1, -2.95), DARK_MOUTH)
	for i = 0, 4 do
		P("Wedge", V(0.15, 0.2, 0.12), CFrame.new(-0.5 + i * 0.25, 2.18, -3.08) * CFrame.Angles(rad(180), 0, 0), WHITE)
	end
	-- 3 pernas com tênis azul
	for _, pos in ipairs({ V(-0.6, 0, -0.9), V(0.6, 0, -0.9), V(0, 0, 1.2) }) do
		P("Cyl", V(0.35, 1.3, 0.35), pos + V(0, 0.95, 0), SKIN)
		P("Block", V(0.7, 0.4, 1.2), pos + V(0, 0.32, -0.15), shoe)
		P("Block", V(0.75, 0.12, 1.25), pos + V(0, 0.06, -0.15), WHITE)
		P("Block", V(0.05, 0.15, 0.6), pos + V(0.37, 0.34, -0.1), WHITE)
		P("Block", V(0.05, 0.15, 0.6), pos + V(-0.37, 0.34, -0.1), WHITE)
	end
end

builders.Bombardiro = function(P)
	local plane = RGB(85, 110, 65)
	local croc = RGB(70, 150, 70)
	local grey = RGB(120, 120, 130)
	P("CylZ", V(2.2, 2.2, 5), V(0, 3, 0.5), plane) -- fuselagem
	P("Block", V(1.9, 1.3, 1.6), V(0, 3.2, -2.6), croc) -- cabeça
	P("Block", V(1.4, 0.5, 2.2), V(0, 3.4, -4.4), croc) -- focinho
	P("Block", V(1.3, 0.35, 2.0), V(0, 2.75, -4.3), croc) -- mandíbula
	for i = 0, 4 do
		P("Wedge", V(0.15, 0.25, 0.15), CFrame.new(-0.55 + i * 0.27, 3.0, -4.9) * CFrame.Angles(rad(180), 0, 0), WHITE)
	end
	for _, s in ipairs({ -1, 1 }) do
		P("Ball", 0.75, V(s * 0.55, 3.95, -2.9), croc)
		P("Ball", 0.45, V(s * 0.55, 4.1, -3.15), RGB(250, 220, 60))
		P("Block", V(0.08, 0.3, 0.05), V(s * 0.55, 4.1, -3.38), BLACK)
		-- motores e hélices
		P("CylZ", V(0.8, 0.8, 1.6), V(s * 2.6, 2.9, -0.3), grey, METAL)
		P("Block", V(0.15, 1.8, 0.1), V(s * 2.6, 2.9, -1.15), BLACK)
		P("Block", V(1.8, 0.15, 0.1), V(s * 2.6, 2.9, -1.15), BLACK)
		-- bombas
		P("CylZ", V(0.5, 0.5, 1.3), V(s * 1.4, 2.25, 0.6), RGB(50, 55, 50), METAL)
		P("Ball", 0.5, V(s * 1.4, 2.25, -0.05), RGB(50, 55, 50), METAL)
	end
	P("Block", V(9, 0.3, 1.8), V(0, 3.1, 0.2), plane) -- asas
	P("Block", V(3, 0.2, 1), V(0, 3.3, 3.2), plane) -- asa de trás
	P("Wedge", V(0.25, 1.4, 1.2), CFrame.new(0, 4.2, 3.3), plane) -- leme
	P("Cyl", V(0.6, 0.05, 0.6), CFrame.new(-2.5, 3.26, 0.2), WHITE) -- estrela
end

builders.Ballerina = function(P)
	local pink = RGB(255, 160, 205)
	local cup = RGB(250, 250, 250)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.32, 2.2, 0.32), V(s * 0.3, 1.15, 0), SKIN)
		P("Block", V(0.4, 0.3, 0.7), V(s * 0.3, 0.15, -0.1), pink)
		P("Cyl", V(0.25, 1.7, 0.25), CFrame.new(s * 0.8, 4.4, 0) * CFrame.Angles(0, 0, rad(-s * 30)), SKIN) -- braços para cima
		P("Ball", 0.3, V(s * 0.45, 5.2, -0.9), RGB(255, 170, 190)) -- bochechas
	end
	P("Cyl", V(3.4, 0.45, 3.4), V(0, 2.4, 0), pink) -- tutu
	P("Cyl", V(2.8, 0.35, 2.8), V(0, 2.75, 0), RGB(255, 200, 225))
	P("Block", V(1.1, 1.3, 0.8), V(0, 3.35, 0), pink) -- corpo
	P("Cyl", V(0.4, 0.4, 0.4), V(0, 4.1, 0), SKIN) -- pescoço
	P("Cyl", V(1.9, 1.7, 1.9), V(0, 5.0, 0), cup) -- a xícara
	P("Cyl", V(1.75, 0.08, 1.75), V(0, 5.85, 0), RGB(125, 80, 45)) -- café
	P("Cyl", V(0.8, 0.1, 0.8), V(0, 5.88, 0), RGB(240, 220, 190)) -- espuma
	P("Block", V(0.25, 0.9, 0.2), V(1.15, 5.0, 0), cup) -- alça
	P("Block", V(0.4, 0.2, 0.2), V(1.0, 5.4, 0), cup)
	P("Block", V(0.4, 0.2, 0.2), V(1.0, 4.6, 0), cup)
	eyes(P, V(0, 5.25, -0.92), 0.38, 0.45)
	P("Block", V(0.4, 0.1, 0.1), V(0, 4.7, -0.96), DARK_MOUTH)
end

builders.CappuccinoAssassino = function(P)
	local cup = RGB(250, 250, 250)
	local silver = RGB(210, 215, 225)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.3, 1.2, 0.3), V(s * 0.4, 0.6, 0), BLACK)
		P("Block", V(0.45, 0.3, 0.8), V(s * 0.4, 0.15, -0.15), BLACK)
		P("Cyl", V(0.25, 1.2, 0.25), CFrame.new(s * 1.3, 2.6, -0.3) * CFrame.Angles(rad(-40), 0, 0), cup)
		-- katanas
		local swordCF = CFrame.new(s * 1.4, 3.5, -1.2) * CFrame.Angles(rad(-35), 0, rad(-s * 15))
		P("Block", V(0.12, 2.6, 0.3), swordCF, silver, METAL)
		P("Block", V(0.5, 0.1, 0.5), swordCF * CFrame.new(0, -1.3, 0), BLACK)
		P("Block", V(0.18, 0.6, 0.18), swordCF * CFrame.new(0, -1.65, 0), RGB(120, 20, 20))
		P("Block", V(0.15, 0.8, 0.12), CFrame.new(s * 0.35, 3.3, 1.35) * CFrame.Angles(rad(30), 0, rad(s * 20)), BLACK) -- faixa
	end
	P("Cyl", V(2.2, 2.8, 2.2), V(0, 2.6, 0), cup) -- xícara
	P("Cyl", V(2.05, 0.08, 2.05), V(0, 4.02, 0), RGB(125, 80, 45)) -- café
	P("Cyl", V(2.3, 0.7, 2.3), V(0, 3.2, 0), BLACK) -- máscara ninja
	for _, s in ipairs({ -1, 1 }) do
		P("Ball", 0.45, V(s * 0.38, 3.22, -1.08), WHITE)
		P("Ball", 0.22, V(s * 0.36, 3.2, -1.25), RGB(200, 30, 30))
	end
	P("Block", V(0.5, 0.1, 0.1), V(0, 2.4, -1.1), DARK_MOUTH)
end

builders.Lirili = function(P)
	local grey = RGB(150, 150, 160)
	local cactus = RGB(70, 150, 70)
	local brown = RGB(130, 85, 45)
	for _, s in ipairs({ -1, 1 }) do
		P("Block", V(0.8, 0.15, 1.3), V(s * 0.5, 0.08, -0.1), brown) -- sandália
		P("Block", V(0.6, 0.4, 1.0), V(s * 0.5, 0.35, -0.1), grey)
		P("Block", V(0.82, 0.12, 0.15), V(s * 0.5, 0.45, -0.35), brown)
		P("Cyl", V(0.5, 0.8, 0.5), V(s * 0.5, 0.9, 0), grey)
		P("Cyl", V(0.55, 0.9, 0.55), CFrame.new(s * 1.3, 2.6, 0) * CFrame.Angles(0, 0, rad(90)), cactus)
		P("Cyl", V(0.55, 1.2, 0.55), V(s * 1.65, 3.15, 0), cactus)
		P("Block", V(0.2, 1.7, 1.4), CFrame.new(s * 1.35, 4.8, 0.2) * CFrame.Angles(0, rad(s * 20), 0), grey) -- orelhas
		P("Block", V(0.1, 1.2, 0.9), CFrame.new(s * 1.27, 4.8, 0.15) * CFrame.Angles(0, rad(s * 20), 0), RGB(230, 170, 180))
		P("Cyl", V(0.18, 0.6, 0.18), CFrame.new(s * 0.45, 3.85, -1.1) * CFrame.Angles(rad(-60), 0, 0), WHITE) -- presas
	end
	P("Cyl", V(1.9, 2.6, 1.9), V(0, 2.5, 0), cactus) -- corpo de cacto
	for _, pos in ipairs({ V(0.5, 2.0, -0.92), V(-0.5, 2.8, -0.92), V(0.2, 3.4, -0.92), V(-0.3, 1.6, -0.92) }) do
		P("Ball", 0.15, pos, RGB(250, 240, 150))
	end
	P("Ball", 2.4, V(0, 4.7, 0), grey) -- cabeça de elefante
	P("Cyl", V(0.55, 1.6, 0.55), CFrame.new(0, 3.9, -1.35) * CFrame.Angles(rad(25), 0, 0), grey) -- tromba
	eyes(P, V(0, 5.0, -1.02), 0.5, 0.45)
end

builders.Ambalabu = function(P)
	local frog = RGB(90, 175, 70)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.35, 1.4, 0.35), V(s * 0.45, 0.85, 0), SKIN)
		P("Block", V(0.55, 0.35, 0.9), V(s * 0.45, 0.17, -0.15), RGB(220, 50, 50))
		P("Ball", 0.8, V(s * 0.5, 5.65, -0.35), frog)
		P("Ball", 0.55, V(s * 0.5, 5.72, -0.62), WHITE)
		P("Ball", 0.28, V(s * 0.5, 5.72, -0.85), BLACK)
	end
	P("CylZ", V(2.8, 2.8, 1.1), V(0, 2.9, 0), RGB(30, 30, 30)) -- o pneu
	P("CylZ", V(1.3, 1.3, 1.15), V(0, 2.9, 0), RGB(170, 170, 180), METAL)
	P("CylZ", V(0.4, 0.4, 1.2), V(0, 2.9, 0), RGB(90, 90, 100), METAL)
	P("Ball", 2.0, V(0, 4.75, 0), frog) -- cabeça de sapo
	P("Block", V(1.4, 0.12, 0.2), V(0, 4.45, -0.92), DARK_MOUTH)
end

builders.TrippiTroppi = function(P)
	local shrimp = RGB(255, 140, 110)
	local grey = RGB(165, 165, 175)
	P("Ball", 1.9, V(0, 1.9, -1.0), shrimp) -- cabeça
	P("Ball", 1.7, V(0, 1.8, 0.3), shrimp)
	P("Ball", 1.45, V(0, 1.9, 1.4), shrimp)
	P("Ball", 1.1, V(0, 2.2, 2.3), shrimp)
	P("Wedge", V(1.4, 0.25, 0.9), CFrame.new(0, 2.6, 2.95) * CFrame.Angles(rad(-40), 0, 0), RGB(230, 110, 90))
	P("Ball", 1.2, V(0, 1.85, -1.55), grey) -- cara de gato
	for _, s in ipairs({ -1, 1 }) do
		P("Wedge", V(0.25, 0.7, 0.6), CFrame.new(s * 0.5, 2.95, -1.1), grey) -- orelhas
		P("Ball", 0.4, V(s * 0.3, 2.1, -2.0), WHITE)
		P("Ball", 0.22, V(s * 0.3, 2.1, -2.15), RGB(80, 160, 60))
		for _, k in ipairs({ -1, 1 }) do
			P("Block", V(0.8, 0.04, 0.04), CFrame.new(s * 0.6, 1.72 + k * 0.08, -2.0) * CFrame.Angles(0, 0, rad(k * 10)), WHITE)
		end
		P("Cyl", V(0.07, 1.8, 0.07), CFrame.new(s * 0.35, 2.9, -1.6) * CFrame.Angles(rad(-30), 0, rad(s * 15)), shrimp)
		for i = 0, 2 do
			P("Cyl", V(0.12, 1.0, 0.12), CFrame.new(s * 0.55, 0.6, -0.6 + i * 0.7) * CFrame.Angles(0, 0, rad(s * 20)), shrimp)
		end
	end
	P("Ball", 0.2, V(0, 1.8, -2.15), RGB(255, 150, 170)) -- nariz
end

builders.Chimpanzini = function(P)
	local yellow = RGB(255, 220, 60)
	local chimp = RGB(110, 70, 40)
	local face = RGB(225, 185, 140)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.4, 0.9, 0.4), V(s * 0.45, 0.45, 0), chimp)
		P("Block", V(0.55, 0.25, 0.8), V(s * 0.45, 0.12, -0.15), chimp)
		P("Ball", 0.55, V(s * 0.9, 4.6, 0), face) -- orelhas
	end
	P("Cyl", V(2.1, 3.0, 2.1), V(0, 2.4, 0), yellow) -- banana
	for _, angle in ipairs({ 0, 120, 240 }) do
		P("Wedge", V(0.2, 1.6, 1.0), CFrame.new(0, 4.2, 0) * CFrame.Angles(0, rad(angle), 0) * CFrame.new(0, 0, 1.0)
			* CFrame.Angles(rad(-25), 0, 0), yellow)
	end
	P("Ball", 0.3, V(0.6, 2.0, -0.85), RGB(120, 90, 40))
	P("Ball", 0.25, V(-0.5, 2.8, -0.9), RGB(120, 90, 40))
	P("Ball", 1.7, V(0, 4.5, 0), chimp) -- cabeça
	P("Ball", 1.15, V(0, 4.35, -0.45), face)
	eyes(P, V(0, 4.75, -0.95), 0.28, 0.32)
	P("Block", V(0.5, 0.08, 0.1), V(0, 4.05, -1.0), DARK_MOUTH)
end

builders.Patapim = function(P)
	local trunk = RGB(115, 80, 50)
	local skin = RGB(225, 170, 130)
	local leaves = RGB(70, 150, 60)
	for _, s in ipairs({ -1, 1 }) do
		P("Block", V(1.1, 0.5, 2.2), V(s * 0.65, 0.25, -0.35), skin) -- pezão
		for t = 0, 2 do
			P("Ball", 0.38, V(s * 0.65 - 0.35 + t * 0.35, 0.3, -1.45), skin)
		end
		P("Cyl", V(0.45, 1.0, 0.45), V(s * 0.6, 0.95, 0), trunk, WOOD)
		P("Cyl", V(0.3, 1.6, 0.3), CFrame.new(s * 1.4, 3.4, 0) * CFrame.Angles(0, 0, rad(-s * 40)), trunk, WOOD) -- galhos
	end
	P("Cyl", V(2.1, 3.0, 2.1), V(0, 2.9, 0), trunk, WOOD) -- tronco
	P("Ball", 1.4, V(0, 3.4, -0.65), skin)
	P("Ball", 0.8, V(0, 3.3, -1.38), RGB(230, 140, 120)) -- narigão
	eyes(P, V(0, 3.95, -1.05), 0.35, 0.38)
	P("Block", V(0.5, 0.08, 0.1), V(0, 2.85, -1.25), DARK_MOUTH)
	P("Ball", 2.6, V(0, 5.3, 0), leaves, Enum.Material.Grass) -- folhas
	P("Ball", 1.6, V(0.95, 5.0, 0.4), leaves, Enum.Material.Grass)
	P("Ball", 1.6, V(-0.95, 5.1, -0.2), leaves, Enum.Material.Grass)
end

builders.Gusini = function(P)
	local orange = RGB(255, 150, 40)
	local grey = RGB(130, 130, 140)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.18, 1.0, 0.18), V(s * 0.45, 0.55, 0), orange)
		P("Block", V(0.6, 0.12, 0.7), V(s * 0.45, 0.06, -0.2), orange)
		P("Block", V(0.25, 0.9, 1.6), CFrame.new(s * 1.2, 2.3, 0.3) * CFrame.Angles(0, 0, rad(s * 10)), RGB(230, 230, 235))
		P("Ball", 0.28, V(s * 0.32, 4.55, -1.22), BLACK)
		-- motores a jato
		P("CylZ", V(0.7, 0.7, 1.8), V(s * 0.75, 3.1, 0.9), grey, METAL)
		P("CylZ", V(0.5, 0.5, 0.3), V(s * 0.75, 3.1, 1.85), orange, NEON)
	end
	P("Ball", 2.4, V(0, 2.1, 0.2), WHITE) -- corpo de ganso
	P("Wedge", V(0.8, 0.6, 0.7), V(0, 2.5, 1.5), WHITE)
	P("Cyl", V(0.55, 1.6, 0.55), CFrame.new(0, 3.5, -0.75) * CFrame.Angles(rad(-10), 0, 0), WHITE) -- pescoço
	P("Ball", 1.0, V(0, 4.4, -0.9), WHITE)
	P("Block", V(0.4, 0.25, 0.7), V(0, 4.3, -1.6), orange) -- bico
end

builders.FrigoCamelo = function(P)
	local fridge = RGB(235, 235, 240)
	local camel = RGB(205, 165, 105)
	local grey = RGB(150, 150, 160)
	for _, pos in ipairs({ V(-0.8, 0, -0.6), V(0.8, 0, -0.6), V(-0.8, 0, 0.6), V(0.8, 0, 0.6) }) do
		P("Cyl", V(0.35, 1.6, 0.35), pos + V(0, 1.0, 0), camel)
		P("Block", V(0.5, 0.45, 0.7), pos + V(0, 0.22, -0.08), RGB(40, 40, 40)) -- botas
	end
	P("Block", V(2.4, 3.0, 1.9), V(0, 3.3, 0), fridge) -- geladeira
	P("Block", V(2.3, 0.06, 0.05), V(0, 3.9, -0.97), grey)
	P("Block", V(0.12, 0.8, 0.12), V(0.9, 4.4, -1.05), grey, METAL)
	P("Block", V(0.12, 0.8, 0.12), V(0.9, 3.2, -1.05), grey, METAL)
	P("Ball", 1.1, V(0, 4.95, -0.1), camel) -- corcovas
	P("Ball", 1.1, V(0, 4.95, 0.7), camel)
	P("Cyl", V(0.6, 1.6, 0.6), CFrame.new(0, 5.4, -1.1) * CFrame.Angles(rad(-25), 0, 0), camel) -- pescoço
	P("Block", V(0.9, 0.85, 1.5), V(0, 6.15, -1.65), camel) -- cabeça
	P("Block", V(0.7, 0.5, 0.4), V(0, 6.0, -2.4), RGB(170, 130, 80))
	for _, s in ipairs({ -1, 1 }) do
		P("Ball", 0.35, V(s * 0.42, 6.35, -1.95), WHITE)
		P("Ball", 0.18, V(s * 0.47, 6.35, -2.08), BLACK)
		P("Block", V(0.2, 0.35, 0.2), V(s * 0.35, 6.7, -1.2), camel)
	end
end

builders.VacaSaturno = function(P)
	local planet = RGB(235, 205, 150)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.4, 1.6, 0.4), V(s * 0.5, 0.95, 0), SKIN)
		P("Block", V(0.6, 0.35, 0.95), V(s * 0.5, 0.17, -0.15), WHITE)
		P("Cyl", V(0.22, 0.7, 0.22), CFrame.new(s * 0.8, 5.0, -0.3) * CFrame.Angles(0, 0, rad(-s * 30)), RGB(250, 240, 210)) -- chifres
		P("Block", V(0.7, 0.25, 0.4), CFrame.new(s * 1.65, 4.3, -0.2) * CFrame.Angles(0, 0, rad(s * 20)), planet) -- orelhas
		P("Ball", 0.2, V(s * 0.25, 2.95, -2.05), RGB(120, 60, 60)) -- narinas
	end
	P("Ball", 3.2, V(0, 3.4, 0), planet) -- planeta
	for _, pos in ipairs({ V(-0.9, 4.2, -1.0), V(1.0, 3.0, -1.1), V(0.3, 4.7, 0.6), V(-1.2, 2.9, 0.5), V(1.1, 4.1, 0.6) }) do
		P("Ball", 0.8, pos, BLACK) -- manchas de vaca
	end
	P("Cyl", V(5.6, 0.12, 5.6), CFrame.new(0, 3.4, 0) * CFrame.Angles(rad(15), 0, rad(-12)), RGB(200, 170, 120), nil, 0.15) -- anel
	P("Cyl", V(4.4, 0.13, 4.4), CFrame.new(0, 3.4, 0) * CFrame.Angles(rad(15), 0, rad(-12)), RGB(160, 120, 80), nil, 0.3)
	P("Ball", 1.3, V(0, 3.0, -1.45), RGB(250, 180, 180)) -- focinho
	eyes(P, V(0, 3.95, -1.42), 0.45, 0.45)
end

builders.Orangutini = function(P)
	local fur = RGB(200, 105, 40)
	local face = RGB(230, 170, 120)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.45, 1.2, 0.45), V(s * 0.5, 0.6, 0), fur)
		P("Block", V(0.6, 0.3, 0.9), V(s * 0.5, 0.15, -0.15), fur)
		P("Cyl", V(0.4, 2.4, 0.4), CFrame.new(s * 1.45, 2.6, 0) * CFrame.Angles(0, 0, rad(s * 15)), fur)
		P("Ball", 0.5, V(s * 0.85, 4.85, 0), face)
	end
	P("Ball", 2.6, V(0, 2.6, 0), RGB(240, 190, 50)) -- corpo de abacaxi
	for i = 0, 5 do
		local a = i * math.pi / 3
		P("Block", V(0.15, 2.0, 0.15), CFrame.new(math.cos(a) * 1.22, 2.6, math.sin(a) * 1.22), RGB(190, 140, 40))
	end
	P("Ball", 1.7, V(0, 4.6, 0), fur)
	P("Ball", 1.15, V(0, 4.45, -0.45), face)
	eyes(P, V(0, 4.8, -0.95), 0.3, 0.32)
	P("Block", V(0.6, 0.08, 0.1), V(0, 4.1, -1.0), DARK_MOUTH)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		P("Wedge", V(0.2, 1.2, 0.6), CFrame.new(math.cos(a) * 0.3, 5.75, math.sin(a) * 0.3) * CFrame.Angles(0, a, rad(15)), RGB(60, 150, 60))
	end
end

builders.CactoHipopotamo = function(P)
	local hippo = RGB(150, 130, 160)
	local cactus = RGB(70, 150, 70)
	for _, pos in ipairs({ V(-0.9, 0, -0.9), V(0.9, 0, -0.9), V(-0.9, 0, 0.9), V(0.9, 0, 0.9) }) do
		P("Cyl", V(0.8, 1.2, 0.8), pos + V(0, 0.6, 0), hippo)
	end
	P("Block", V(2.8, 2.0, 3.4), V(0, 2.1, 0.2), hippo)
	P("Block", V(2.4, 1.6, 1.6), V(0, 2.5, -1.9), hippo)
	P("Block", V(2.2, 0.9, 0.6), V(0, 2.0, -2.85), RGB(180, 160, 185))
	for _, s in ipairs({ -1, 1 }) do
		P("Ball", 0.25, V(s * 0.45, 2.2, -3.17), BLACK)
		P("Ball", 0.5, V(s * 0.6, 3.3, -2.4), WHITE)
		P("Ball", 0.25, V(s * 0.6, 3.32, -2.62), BLACK)
		P("Ball", 0.45, V(s * 0.9, 3.4, -1.5), hippo)
	end
	P("Cyl", V(1.0, 2.2, 1.0), V(0, 4.2, 0.6), cactus) -- cacto nas costas
	P("Cyl", V(0.5, 0.8, 0.5), CFrame.new(0.7, 4.2, 0.6) * CFrame.Angles(0, 0, rad(90)), cactus)
	P("Cyl", V(0.5, 0.9, 0.5), V(1.05, 4.6, 0.6), cactus)
	P("Ball", 0.5, V(0, 5.35, 0.6), RGB(255, 120, 160))
end

builders.RhinoToasterino = function(P)
	local rhino = RGB(140, 140, 150)
	local bread = RGB(210, 160, 90)
	for _, pos in ipairs({ V(-0.9, 0, -1.0), V(0.9, 0, -1.0), V(-0.9, 0, 1.0), V(0.9, 0, 1.0) }) do
		P("Cyl", V(0.7, 1.2, 0.7), pos + V(0, 0.6, 0), rhino)
	end
	P("Block", V(2.6, 2.2, 3.2), V(0, 2.3, 0.4), RGB(200, 200, 210), METAL) -- torradeira
	for _, x in ipairs({ -0.6, 0.6 }) do
		P("Block", V(0.4, 0.1, 2.4), V(x, 3.42, 0.4), BLACK)
		P("Block", V(0.35, 0.9, 1.6), V(x, 3.7, 0.4), bread)
	end
	P("Block", V(0.2, 0.6, 0.15), V(1.35, 2.6, 1.2), BLACK)
	P("Block", V(2.0, 1.6, 1.6), V(0, 2.4, -1.9), rhino)
	P("Wedge", V(0.5, 1.2, 0.8), CFrame.new(0, 3.6, -2.4), RGB(230, 225, 210)) -- chifre
	for _, s in ipairs({ -1, 1 }) do
		P("Ball", 0.42, V(s * 0.75, 2.8, -2.7), WHITE)
		P("Ball", 0.22, V(s * 0.78, 2.8, -2.88), BLACK)
		P("Block", V(0.3, 0.5, 0.3), V(s * 0.7, 3.35, -1.5), rhino)
	end
end

builders.TricTrac = function(P)
	local red = RGB(220, 50, 50)
	local grey = RGB(60, 60, 60)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.35, 1.2, 0.35), V(s * 0.45, 0.6, 0), grey)
		P("Block", V(0.55, 0.3, 0.8), V(s * 0.45, 0.15, -0.15), BLACK)
		P("Cyl", V(0.3, 1.4, 0.3), CFrame.new(s * 1.25, 2.6, 0) * CFrame.Angles(0, 0, rad(s * 30)), grey)
	end
	P("Cyl", V(2.2, 3.0, 2.2), V(0, 2.7, 0), red) -- bombinha
	P("Cyl", V(2.25, 0.3, 2.25), V(0, 2.2, 0), RGB(250, 220, 60))
	P("Cyl", V(2.25, 0.3, 2.25), V(0, 3.4, 0), RGB(250, 220, 60))
	P("Cyl", V(0.15, 0.9, 0.15), CFrame.new(0.2, 4.6, 0) * CFrame.Angles(0, 0, rad(-20)), RGB(90, 70, 50)) -- pavio
	P("Ball", 0.5, V(0.4, 5.05, 0), RGB(255, 200, 80), NEON)
	eyes(P, V(0, 3.0, -1.08), 0.42, 0.45)
	P("Block", V(0.9, 0.15, 0.1), V(0, 2.4, -1.1), DARK_MOUTH)
end

builders.UdinDinDun = function(P)
	local stick = RGB(230, 200, 150)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.4, 1.6, 0.4), V(s * 0.5, 0.8, 0), SKIN)
		P("Block", V(0.6, 0.3, 0.9), V(s * 0.5, 0.15, -0.15), RGB(60, 40, 30))
		P("Cyl", V(0.3, 1.6, 0.3), CFrame.new(s * 1.5, 3.0, -0.3) * CFrame.Angles(rad(-30), 0, rad(s * 20)), SKIN)
		P("Cyl", V(0.15, 1.8, 0.15), CFrame.new(s * 1.7, 3.9, -0.9) * CFrame.Angles(rad(-60), 0, 0), stick) -- baquetas
		P("Ball", 0.35, V(s * 1.7, 4.3, -1.6), stick)
	end
	P("Cyl", V(2.6, 2.4, 2.6), V(0, 2.8, 0), RGB(200, 40, 40)) -- tambor
	P("Cyl", V(2.65, 0.15, 2.65), V(0, 4.0, 0), WHITE)
	P("Cyl", V(2.65, 0.15, 2.65), V(0, 1.6, 0), WHITE)
	for i = 0, 5 do
		local a = i * math.pi / 3
		P("Block", V(0.08, 2.4, 0.08), CFrame.new(math.cos(a) * 1.32, 2.8, math.sin(a) * 1.32), RGB(250, 220, 60))
	end
	P("Ball", 1.6, V(0, 4.9, 0), SKIN)
	eyes(P, V(0, 5.1, -0.7), 0.3, 0.35)
	P("Block", V(0.6, 0.1, 0.1), V(0, 4.5, -0.78), DARK_MOUTH)
	P("Cyl", V(1.7, 0.2, 1.7), V(0, 5.6, 0), RGB(40, 40, 40)) -- chapéu
	P("Cyl", V(1.1, 0.6, 1.1), V(0, 5.95, 0), RGB(40, 40, 40))
end

builders.Glorbo = function(P)
	local croc = RGB(70, 150, 70)
	P("Ball", 3.0, V(0, 2.0, 0.4), RGB(40, 140, 50)) -- melancia
	for i = 0, 3 do
		P("CylX", V(0.2, 3.04, 3.04), CFrame.new(0, 2.0, 0.4) * CFrame.Angles(0, rad(i * 45), 0), RGB(20, 90, 30))
	end
	P("Block", V(1.6, 0.9, 2.2), V(0, 2.1, -1.9), croc)
	P("Block", V(1.2, 0.5, 1.4), V(0, 2.0, -3.3), croc)
	for i = 0, 3 do
		P("Wedge", V(0.15, 0.25, 0.15), CFrame.new(-0.4 + i * 0.27, 1.7, -3.9) * CFrame.Angles(rad(180), 0, 0), WHITE)
	end
	for _, s in ipairs({ -1, 1 }) do
		P("Ball", 0.6, V(s * 0.45, 2.75, -2.3), croc)
		P("Ball", 0.38, V(s * 0.45, 2.85, -2.5), WHITE)
		P("Ball", 0.2, V(s * 0.45, 2.85, -2.66), BLACK)
		for _, z in ipairs({ -0.6, 1.2 }) do
			P("Block", V(0.5, 0.8, 0.7), V(s * 1.2, 0.4, z), croc)
		end
	end
	P("Wedge", V(0.8, 0.6, 2.2), CFrame.new(0, 1.4, 2.6) * CFrame.Angles(0, math.pi, 0), croc) -- rabo
end

builders.Bobritto = function(P)
	local fur = RGB(130, 85, 50)
	local hat = RGB(60, 40, 30)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.45, 1.0, 0.45), V(s * 0.5, 0.5, 0), fur)
		P("Block", V(0.6, 0.3, 0.9), V(s * 0.5, 0.15, -0.2), hat)
		P("Cyl", V(0.35, 1.4, 0.35), CFrame.new(s * 1.2, 2.5, -0.2) * CFrame.Angles(rad(-30), 0, rad(s * 20)), fur)
		P("Ball", 0.3, V(s * 0.35, 4.05, -0.98), WHITE)
	end
	P("Ball", 2.3, V(0, 2.3, 0), fur)
	P("Ball", 1.7, V(0, 3.9, -0.1), fur)
	P("Block", V(1.5, 0.35, 0.3), V(0, 4.05, -0.85), BLACK) -- máscara de bandido
	P("Block", V(0.5, 0.5, 0.15), V(0, 3.4, -0.88), WHITE) -- dentões
	P("Cyl", V(2.6, 0.15, 2.6), V(0, 4.7, -0.1), hat)
	P("Cyl", V(1.4, 0.8, 1.4), V(0, 5.1, -0.1), hat)
	P("Block", V(1.4, 0.25, 2.4), CFrame.new(0, 0.5, 1.6) * CFrame.Angles(rad(-20), 0, 0), RGB(90, 60, 40)) -- rabo
	P("Ball", 0.9, V(1.5, 1.6, -0.6), RGB(90, 150, 70)) -- saco de dinheiro
	P("Block", V(0.4, 0.4, 0.05), V(1.5, 1.6, -1.06), RGB(250, 220, 60))
end

builders.Burbaloni = function(P)
	local capy = RGB(160, 110, 70)
	P("Ball", 3.6, V(0, 1.9, 0), RGB(110, 75, 45)) -- coco
	P("Cyl", V(3.0, 0.3, 3.0), V(0, 3.0, 0), RGB(250, 245, 235))
	P("Ball", 2.2, V(0, 3.3, 0), capy) -- capivara
	P("Block", V(1.4, 1.0, 1.0), V(0, 3.2, -1.1), capy)
	P("Ball", 0.35, V(0, 3.4, -1.62), BLACK)
	for _, s in ipairs({ -1, 1 }) do
		P("Ball", 0.4, V(s * 0.55, 3.95, -0.95), BLACK)
		P("Ball", 0.45, V(s * 0.75, 4.35, 0), capy)
	end
	P("Ball", 0.6, V(0.4, 4.45, 0.2), RGB(255, 170, 60)) -- laranja na cabeça
end

builders.Bicus = function(P)
	local bird = RGB(120, 130, 150)
	local beak = RGB(255, 170, 50)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.15, 1.0, 0.15), V(s * 0.4, 0.5, 0), beak)
		P("Block", V(0.5, 0.1, 0.6), V(s * 0.4, 0.05, -0.2), beak)
		P("Block", V(0.25, 1.2, 1.4), CFrame.new(s * 1.05, 2.2, 0.2) * CFrame.Angles(0, 0, rad(s * 10)), RGB(90, 100, 120))
		P("Ball", 0.35, V(s * 0.33, 3.6, -0.78), WHITE)
		P("Ball", 0.18, V(s * 0.33, 3.6, -0.93), BLACK)
	end
	P("Ball", 2.0, V(0, 2.1, 0), bird)
	P("Ball", 1.4, V(0, 3.5, -0.2), bird)
	P("Wedge", V(0.4, 0.3, 0.7), CFrame.new(0, 3.35, -1.15) * CFrame.Angles(rad(180), 0, 0), beak)
	P("Cyl", V(1.5, 0.6, 1.5), V(0, 4.1, -0.2), RGB(210, 170, 60), METAL) -- capacete
	P("Block", V(0.2, 0.7, 1.4), V(0, 4.7, -0.2), RGB(200, 40, 40)) -- penacho
	P("Block", V(0.1, 1.6, 0.25), CFrame.new(1.4, 2.6, -0.6) * CFrame.Angles(rad(-20), 0, 0), RGB(210, 215, 225), METAL) -- espada
end

builders.Cocofanto = function(P)
	local grey = RGB(150, 150, 165)
	for _, pos in ipairs({ V(-0.9, 0, -0.8), V(0.9, 0, -0.8), V(-0.9, 0, 0.9), V(0.9, 0, 0.9) }) do
		P("Cyl", V(0.9, 1.4, 0.9), pos + V(0, 0.7, 0), grey)
	end
	P("Ball", 3.4, V(0, 2.9, 0.3), RGB(110, 75, 45)) -- corpo de coco
	P("Ball", 2.2, V(0, 3.9, -1.5), grey)
	for _, s in ipairs({ -1, 1 }) do
		P("Block", V(0.2, 1.8, 1.5), CFrame.new(s * 1.3, 4.0, -1.2) * CFrame.Angles(0, rad(s * 25), 0), grey)
		P("Cyl", V(0.18, 0.7, 0.18), CFrame.new(s * 0.45, 3.1, -2.4) * CFrame.Angles(rad(-60), 0, 0), WHITE)
	end
	P("Cyl", V(0.55, 2.0, 0.55), CFrame.new(0, 2.8, -2.55) * CFrame.Angles(rad(20), 0, 0), grey) -- tromba
	eyes(P, V(0, 4.25, -2.5), 0.45, 0.4)
	for i = 0, 3 do
		local a = i * math.pi / 2
		P("Wedge", V(0.2, 0.3, 1.8), CFrame.new(math.cos(a) * 0.7, 4.7, 0.3 + math.sin(a) * 0.7) * CFrame.Angles(0, -a, 0), RGB(70, 160, 70))
	end
end

builders.TaTaSahur = function(P)
	local metal = RGB(190, 195, 205)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.35, 1.4, 0.35), V(s * 0.5, 0.7, 0), SKIN)
		P("Block", V(0.55, 0.3, 0.8), V(s * 0.5, 0.15, -0.15), RGB(60, 40, 30))
		P("Cyl", V(0.3, 1.6, 0.3), CFrame.new(s * 1.5, 2.8, 0) * CFrame.Angles(0, 0, rad(s * 30)), SKIN)
	end
	P("Ball", 3.0, V(0, 3.0, 0), metal, METAL) -- chaleira
	P("Cyl", V(1.4, 0.5, 1.4), V(0, 4.45, 0), metal, METAL)
	P("Ball", 0.5, V(0, 4.85, 0), BLACK)
	P("Cyl", V(0.5, 1.6, 0.5), CFrame.new(1.6, 3.4, 0) * CFrame.Angles(0, 0, rad(-50)), metal, METAL) -- bico
	P("Block", V(0.3, 1.6, 0.3), V(0, 3.2, 1.65), BLACK) -- alça
	eyes(P, V(0, 3.4, -1.3), 0.5, 0.55)
	P("Block", V(1.0, 0.15, 0.1), V(0, 2.6, -1.4), DARK_MOUTH)
	P("Ball", 0.6, V(2.4, 4.5, 0), WHITE, nil, 0.4) -- vapor
	P("Ball", 0.8, V(2.7, 5.1, 0), WHITE, nil, 0.5)
end

builders.Svinino = function(P)
	local pink = RGB(255, 170, 180)
	for _, pos in ipairs({ V(-0.8, 0, -0.7), V(0.8, 0, -0.7), V(-0.8, 0, 0.8), V(0.8, 0, 0.8) }) do
		P("Cyl", V(0.6, 1.0, 0.6), pos + V(0, 0.5, 0), pink)
	end
	P("Ball", 3.2, V(0, 2.6, 0), RGB(40, 40, 45), METAL) -- bomba
	P("Ball", 1.4, V(0, 2.7, -1.3), pink)
	P("CylZ", V(0.8, 0.8, 0.4), V(0, 2.5, -1.95), RGB(255, 140, 160)) -- focinho
	for _, s in ipairs({ -1, 1 }) do
		P("Ball", 0.15, V(s * 0.18, 2.5, -2.16), BLACK)
		P("Ball", 0.3, V(s * 0.35, 3.0, -1.92), BLACK)
		P("Wedge", V(0.15, 0.6, 0.5), CFrame.new(s * 0.9, 4.0, -0.6), pink)
	end
	P("Cyl", V(0.6, 0.4, 0.6), V(0, 4.25, 0), RGB(150, 150, 150), METAL)
	P("Cyl", V(0.12, 0.9, 0.12), CFrame.new(0.2, 4.8, 0) * CFrame.Angles(0, 0, rad(-25)), RGB(90, 70, 50))
	P("Ball", 0.5, V(0.45, 5.2, 0), RGB(255, 160, 40), NEON)
end

builders.GirafaCelestre = function(P)
	local body = RGB(250, 230, 170)
	for _, pos in ipairs({ V(-0.7, 0, -0.9), V(0.7, 0, -0.9), V(-0.7, 0, 1.0), V(0.7, 0, 1.0) }) do
		P("Cyl", V(0.45, 2.6, 0.45), pos + V(0, 1.3, 0), body)
	end
	P("Block", V(2.0, 1.6, 3.0), V(0, 3.3, 0.1), body)
	P("Cyl", V(0.8, 3.2, 0.8), CFrame.new(0, 5.3, -1.2) * CFrame.Angles(rad(-15), 0, 0), body) -- pescoço
	P("Block", V(1.0, 0.9, 1.6), V(0, 7.0, -1.9), body)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.15, 0.6, 0.15), V(s * 0.3, 7.7, -1.7), body)
		P("Ball", 0.3, V(s * 0.3, 8.0, -1.7), RGB(255, 230, 90), NEON)
		P("Ball", 0.35, V(s * 0.4, 7.2, -2.55), WHITE)
		P("Ball", 0.18, V(s * 0.42, 7.2, -2.7), RGB(60, 120, 255))
		P("Block", V(0.3, 1.6, 2.6), CFrame.new(s * 1.3, 3.8, 0.2) * CFrame.Angles(0, 0, rad(s * 40)), WHITE, NEON, 0.3) -- asas de luz
	end
	for _, pos in ipairs({ V(0.6, 3.6, -0.8), V(-0.5, 3.3, 0.6), V(0.4, 3.0, 1.2), V(-0.7, 3.8, -0.3) }) do
		P("Ball", 0.6, pos, RGB(130, 200, 255), NEON) -- manchas de estrela
	end
	P("Cyl", V(1.6, 0.1, 1.6), V(0, 8.4, -1.8), RGB(255, 230, 90), NEON, 0.2) -- auréola
end

builders.OdinDinDun = function(P)
	local gold = RGB(255, 210, 70)
	for _, s in ipairs({ -1, 1 }) do
		P("Cyl", V(0.5, 1.8, 0.5), V(s * 0.55, 0.9, 0), RGB(80, 80, 110))
		P("Block", V(0.7, 0.4, 1.0), V(s * 0.55, 0.2, -0.15), gold, METAL)
		P("Cyl", V(0.4, 1.8, 0.4), CFrame.new(s * 1.6, 3.3, 0) * CFrame.Angles(0, 0, rad(s * 25)), SKIN)
		P("Wedge", V(0.15, 0.8, 1.0), CFrame.new(s * 0.95, 6.1, 0) * CFrame.Angles(0, rad(s * 90), 0), WHITE) -- asas do elmo
	end
	P("Cyl", V(2.8, 2.6, 2.8), V(0, 3.1, 0), RGB(70, 60, 140)) -- tambor
	P("Cyl", V(2.85, 0.2, 2.85), V(0, 4.4, 0), gold, METAL)
	P("Cyl", V(2.85, 0.2, 2.85), V(0, 1.8, 0), gold, METAL)
	P("Ball", 1.7, V(0, 5.25, 0), SKIN)
	P("Cyl", V(1.8, 0.7, 1.8), V(0, 5.95, 0), gold, METAL) -- elmo
	eyes(P, V(0, 5.3, -0.75), 0.3, 0.35)
	P("Block", V(1.0, 0.8, 0.3), V(0, 4.6, -0.7), WHITE) -- barba
	P("Cyl", V(0.25, 2.4, 0.25), V(2.2, 3.0, -0.4), RGB(120, 80, 50)) -- martelo
	P("Block", V(1.2, 0.8, 0.8), V(2.2, 4.3, -0.4), RGB(180, 190, 210), METAL)
end

---------------------------------------------------------------------
-- Boneco genérico (para brainrots novos sem modelo e sem formato próprio)
---------------------------------------------------------------------
local function genericBuilder(def)
	return function(P)
		local size = def.size
		local body = def.bodyColor or Config.getRarity(def.rarity).color
		local accent = def.accentColor or WHITE
		local legH = 0.7
		local cy = legH + size.Y / 2
		local shape = def.shape or "Ball"
		if shape == "Ball" then
			P("Ball", size.X, V(0, legH + size.X / 2, 0), body)
			cy = legH + size.X / 2
		elseif shape == "Cylinder" then
			P("Cyl", V(size.X, size.Y, size.X), V(0, cy, 0), body)
		else
			P("Block", size, V(0, cy, 0), body)
		end
		local top = if shape == "Ball" then legH + size.X else legH + size.Y
		local front = -size.Z / 2
		eyes(P, V(0, cy + size.Y * 0.18, front * 0.85), size.X * 0.22, math.max(size.X * 0.28, 0.6))
		P("Block", V(size.X * 0.4, 0.25, 0.2), V(0, cy - size.Y * 0.12, front * 0.92), DARK_MOUTH)
		for _, s in ipairs({ -1, 1 }) do
			P("Block", V(0.9, 0.7, 1.2), V(s * size.X * 0.25, 0.35, 0), accent)
		end
		local acc = def.accessory
		if acc == "Antena" then
			P("Cyl", V(0.2, 1.6, 0.2), V(0, top + 0.8, 0), BLACK)
			P("Ball", 0.7, V(0, top + 1.7, 0), accent, NEON)
		elseif acc == "Chapeu" then
			P("Cyl", V(size.X * 0.9, 0.2, size.X * 0.9), V(0, top, 0), accent)
			P("Cyl", V(size.X * 0.55, 1.4, size.X * 0.55), V(0, top + 0.7, 0), accent)
		elseif acc == "Orelhas" then
			for _, s in ipairs({ -1, 1 }) do
				P("Block", V(0.5, 1.2, 0.8), V(s * size.X * 0.35, top + 0.4, 0), accent)
			end
		elseif acc == "Asas" then
			for _, s in ipairs({ -1, 1 }) do
				P("Block", V(2.2, 0.2, 1.4), CFrame.new(s * (size.X / 2 + 1), cy, 0) * CFrame.Angles(0, 0, rad(s * 25)), WHITE)
			end
		elseif acc == "Disco" then
			P("CylX", V(0.3, 2, 2), V(size.X / 2 + 0.3, cy, 0), accent, METAL)
		elseif acc == "Capacete" or acc == "Coroa" then
			P("Block", V(size.X * 0.5, 0.5, size.X * 0.5), V(0, top + 0.3, 0), RGB(255, 210, 40), NEON)
		end
	end
end

---------------------------------------------------------------------
-- Montagem final: caixa de acerto "Root" + altura até o chão
---------------------------------------------------------------------
local function finalize(model: Model)
	model.WorldPivot = CFrame.new()
	local bbCF, bbSize = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.Transparency = 1
	root.Size = bbSize
	root.CFrame = CFrame.new(bbCF.Position)
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("HipHeight", bbCF.Position.Y) -- o chão estava em y = 0
	return model
end

local function buildFromParts(def)
	local model = Instance.new("Model")
	model.Name = def.id
	local builder = builders[def.id] or genericBuilder(def)
	builder(maker(model))
	return finalize(model)
end

-- Prepara um modelo da Toolbox: remove scripts, ancora, ajusta tamanho e cria a caixa de acerto
local function prepareCustom(def, source: Model)
	local model = source:Clone()
	model.Name = def.id
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end

	-- usa só a direção horizontal do modelo (mais o ajuste modelYaw da Config)
	local pivot = model:GetPivot()
	local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	local rotation = if look.Magnitude > 0.01 then CFrame.lookAt(Vector3.zero, look) else CFrame.new()
	rotation *= CFrame.Angles(0, rad(def.modelYaw or 0), 0)
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(pivot.Position) * rotation

	local bbCF, bbSize = model:GetBoundingBox()
	if bbSize.Y > 0.01 then
		model:ScaleTo(model:GetScale() * (def.size.Y / bbSize.Y))
	end
	bbCF, bbSize = model:GetBoundingBox()

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.Transparency = 1
	root.Size = bbSize
	root.CFrame = bbCF
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("HipHeight", bbSize.Y / 2)
	return model
end

---------------------------------------------------------------------
-- Efeitos das evoluções: 2ª evolução brilha, 3ª ganha coroa e aura
---------------------------------------------------------------------
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
		local size = root.Size
		local crown = Instance.new("Part")
		crown.Name = "EvoCrown"
		crown.Anchored = true
		crown.CanCollide = false
		crown.CanTouch = false
		crown.CanQuery = false
		crown.Material = NEON
		crown.Color = RGB(255, 215, 50)
		crown.Size = V(1.4, 0.4, 1.4)
		crown.CFrame = root.CFrame * CFrame.new(0, size.Y / 2 + 0.6, 0)
		crown.Parent = model
		for i = 0, 3 do
			local spike = crown:Clone()
			spike.Name = "EvoSpike"
			spike.Size = V(0.3, 0.7, 0.3)
			local angle = i * math.pi / 2
			spike.CFrame = crown.CFrame * CFrame.new(math.cos(angle) * 0.55, 0.5, math.sin(angle) * 0.55)
			spike.Parent = model
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 14
		light.Brightness = 3
		light.Parent = root
	end
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------
local templates = {} -- modelo pronto de cada brainrot (montado uma vez, depois só clonado)

-- "Lirilì Larilà" -> "lirililarila" (sem maiúsculas, espaços, acentos e símbolos)
local ACCENTS = {
	["á"] = "a", ["à"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
	["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i", ["ó"] = "o", ["ò"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o",
	["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c", ["ñ"] = "n",
}
local function normalize(text: string): string
	text = string.lower(text)
	for accented, plain in pairs(ACCENTS) do
		text = string.gsub(text, accented, plain)
	end
	return (string.gsub(text, "[^%w]", ""))
end

-- acha o modelo pelo id ("Tralalero") ou pelo nome completo ("Tralalero Tralala")
local function findCustomModel(folder: Instance, def)
	local exact = folder:FindFirstChild(def.id)
	if exact and exact:IsA("Model") then
		return exact
	end
	local wanted = { [normalize(def.id)] = true, [normalize(def.name)] = true }
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and wanted[normalize(child.Name)] then
			return child
		end
	end
	return nil
end

local function getTemplate(def)
	local template = templates[def.id]
	if template then
		return template
	end
	local folder = ServerStorage:FindFirstChild("BrainrotModels")
	local custom = folder and findCustomModel(folder, def)
	if custom and custom:IsA("Model") then
		local ok, result = pcall(prepareCustom, def, custom)
		if ok then
			template = result
		else
			warn("[BrainrotModels] Não deu para usar o modelo '" .. def.id .. "': " .. tostring(result))
		end
	end
	template = template or buildFromParts(def)
	templates[def.id] = template
	return template
end

-- Brilho colorido + partículas das mutações (Dourado, Magma, Radioativo...)
function BrainrotModels.applyMutation(model: Model, mutationId: string?)
	local m = Config.getMutation(mutationId)
	local root = model.PrimaryPart
	if not m or not root then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "Mutation"
	highlight.FillColor = m.color
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = m.color
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MutationParticles"
	if mutationId == "ArcoIris" then
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, RGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, RGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, RGB(80, 255, 120)), ColorSequenceKeypoint.new(0.75, RGB(80, 160, 255)),
			ColorSequenceKeypoint.new(1, RGB(220, 90, 255)),
		})
	else
		emitter.Color = ColorSequence.new(m.color)
	end
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Rate = 10
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = root
end

-- Cria um novo modelo do brainrot. scale = tamanho (1 = normal). stage = evolução (1, 2 ou 3).
function BrainrotModels.build(def, scale: number?, stage: number?, mutation: string?)
	scale = scale or 1
	local model = getTemplate(def):Clone()
	if scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
		model:SetAttribute("HipHeight", (model:GetAttribute("HipHeight") or 0) * scale)
	end
	applyStage(model, def, stage or 1)
	BrainrotModels.applyMutation(model, mutation)
	return model
end

return BrainrotModels
