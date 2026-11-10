-- Config: todos os números do jogo ficam aqui.
-- Mude à vontade para balancear (vida, chance de captura, preços, renda...).

local Config = {}

-- Se true, o servidor constrói o mapa sozinho (chão, zona de caça, bases).
-- Coloque false se você montar o seu próprio mapa no Studio (veja o README).
Config.BuildMap = true

Config.DataStoreName = "BrainrotTycoon_v1"
Config.AutoSaveInterval = 120

Config.StartingCash = 50
Config.StartingBalls = { Basica = 10, Super = 0, Ultra = 0, Suprema = 0 }

---------------------------------------------------------------------
-- RARIDADES
---------------------------------------------------------------------
Config.RarityOrder = { "Comum", "Raro", "Epico", "Lendario", "Mitico" }

Config.Rarities = {
	Comum = { display = "Comum", color = Color3.fromRGB(200, 200, 200), spawnWeight = 55, faintReward = 5, xpReward = 10, wildLevels = { 1, 5 } },
	Raro = { display = "Raro", color = Color3.fromRGB(70, 150, 255), spawnWeight = 27, faintReward = 15, xpReward = 25, wildLevels = { 3, 8 } },
	Epico = { display = "Épico", color = Color3.fromRGB(175, 85, 255), spawnWeight = 12, faintReward = 40, xpReward = 60, wildLevels = { 6, 12 } },
	Lendario = { display = "Lendário", color = Color3.fromRGB(255, 170, 0), spawnWeight = 5, faintReward = 120, xpReward = 150, wildLevels = { 10, 16 } },
	Mitico = { display = "Mítico", color = Color3.fromRGB(255, 60, 100), spawnWeight = 1, faintReward = 400, xpReward = 400, wildLevels = { 15, 20 } },
}

---------------------------------------------------------------------
-- BRAINROTS
-- maxHealth  = vida
-- catchRate  = chance base de captura (0.5 = 50%) com vida cheia e Bola Básica
-- income     = dinheiro por segundo quando está no pedestal da sua base
-- sellPrice  = quanto você ganha vendendo
-- speed      = velocidade andando
-- damage     = dano que ele te dá quando fica bravo
-- shape      = "Ball", "Block" ou "Cylinder"
-- accessory  = "Antena", "Chapeu", "Orelhas", "Asas", "Disco", "Capacete", "Coroa"
-- evolutions = nomes da 2ª e 3ª evolução
-- signature  = nome do golpe especial (aprende no nível 30)
-- (vida, dano e renda aumentam com o nível; veja Config.Levels)
---------------------------------------------------------------------
Config.Brainrots = {
	{
		id = "Bananito", name = "Bananito Telefonino", rarity = "Comum",
		maxHealth = 50, catchRate = 0.50, income = 1, sellPrice = 20, speed = 10, damage = 5,
		shape = "Cylinder", size = Vector3.new(2.6, 4, 2.6),
		bodyColor = Color3.fromRGB(255, 225, 60), accentColor = Color3.fromRGB(40, 40, 40), accessory = "Antena",
		evolutions = { "Bananito Telefonino 5G", "Bananito Smartphonissimo" }, signature = "Ligação Explosiva",
	},
	{
		id = "Sapo", name = "Sapo Tamburello", rarity = "Comum",
		maxHealth = 60, catchRate = 0.45, income = 2, sellPrice = 30, speed = 12, damage = 6,
		shape = "Ball", size = Vector3.new(3.4, 3.4, 3.4),
		bodyColor = Color3.fromRGB(80, 200, 80), accentColor = Color3.fromRGB(255, 140, 40), accessory = "Disco",
		evolutions = { "Sapo Tamburello Rock", "Sapone Batterista" }, signature = "Batuque Sônico",
	},
	{
		id = "Pizzaroni", name = "Pizzaroni Turbonelli", rarity = "Comum",
		maxHealth = 70, catchRate = 0.40, income = 3, sellPrice = 40, speed = 14, damage = 7,
		shape = "Block", size = Vector3.new(3.4, 3, 3),
		bodyColor = Color3.fromRGB(255, 160, 60), accentColor = Color3.fromRGB(210, 40, 40), accessory = "Chapeu",
		evolutions = { "Pizzaroni Calzonelli", "Pizzarone Quattro Formaggi" }, signature = "Fatia Turbo",
	},
	{
		id = "Tostadino", name = "Tostadino Volante", rarity = "Raro",
		maxHealth = 120, catchRate = 0.28, income = 8, sellPrice = 120, speed = 16, damage = 10,
		shape = "Block", size = Vector3.new(3.6, 3.2, 2.4),
		bodyColor = Color3.fromRGB(190, 190, 200), accentColor = Color3.fromRGB(140, 90, 50), accessory = "Asas",
		evolutions = { "Tostadino Jato", "Tostadone Supersonico" }, signature = "Torrada Voadora",
	},
	{
		id = "Mucca", name = "Mucca Skateboardina", rarity = "Raro",
		maxHealth = 140, catchRate = 0.25, income = 10, sellPrice = 150, speed = 15, damage = 12,
		shape = "Block", size = Vector3.new(3.8, 3.2, 3.8),
		bodyColor = Color3.fromRGB(245, 245, 245), accentColor = Color3.fromRGB(30, 30, 30), accessory = "Orelhas",
		evolutions = { "Mucca Skate Pro", "Muccona Radicale" }, signature = "Manobra Radical",
	},
	{
		id = "Melancino", name = "Melancino Patinetto", rarity = "Raro",
		maxHealth = 130, catchRate = 0.26, income = 9, sellPrice = 140, speed = 17, damage = 11,
		shape = "Ball", size = Vector3.new(3.8, 3.8, 3.8),
		bodyColor = Color3.fromRGB(40, 150, 60), accentColor = Color3.fromRGB(235, 60, 70), accessory = "Antena",
		evolutions = { "Melancino Turbo", "Melancione Motociclone" }, signature = "Chuva de Sementes",
	},
	{
		id = "Pinguino", name = "Pinguino Spaghettino", rarity = "Epico",
		maxHealth = 250, catchRate = 0.14, income = 25, sellPrice = 450, speed = 18, damage = 18,
		shape = "Ball", size = Vector3.new(4, 4, 4),
		bodyColor = Color3.fromRGB(35, 35, 45), accentColor = Color3.fromRGB(255, 220, 90), accessory = "Chapeu",
		evolutions = { "Pinguino Lasagnino", "Pinguinone Carbonarone" }, signature = "Chicote de Espaguete",
	},
	{
		id = "Girafino", name = "Girafino Lampadino", rarity = "Epico",
		maxHealth = 280, catchRate = 0.12, income = 30, sellPrice = 520, speed = 16, damage = 20,
		shape = "Cylinder", size = Vector3.new(2.8, 5.5, 2.8),
		bodyColor = Color3.fromRGB(240, 180, 70), accentColor = Color3.fromRGB(255, 255, 150), accessory = "Antena",
		evolutions = { "Girafino LED", "Girafone Lampione Neon" }, signature = "Flash Ofuscante",
	},
	{
		id = "Polpo", name = "Polpo Saxofono", rarity = "Lendario",
		maxHealth = 500, catchRate = 0.07, income = 80, sellPrice = 1500, speed = 19, damage = 30,
		shape = "Ball", size = Vector3.new(4.6, 4.6, 4.6),
		bodyColor = Color3.fromRGB(150, 60, 200), accentColor = Color3.fromRGB(255, 200, 50), accessory = "Disco",
		evolutions = { "Polpo Jazzista", "Polpone Orchestrone" }, signature = "Solo de Saxofone",
	},
	{
		id = "Croissantino", name = "Dinossauro Croissantino", rarity = "Lendario",
		maxHealth = 550, catchRate = 0.06, income = 90, sellPrice = 1700, speed = 20, damage = 32,
		shape = "Block", size = Vector3.new(4.4, 4.6, 4.4),
		bodyColor = Color3.fromRGB(90, 170, 90), accentColor = Color3.fromRGB(220, 170, 100), accessory = "Orelhas",
		evolutions = { "Dino Croissant Rex", "Dinossaurone Baguettone" }, signature = "Mordida Amanteigada",
	},
	{
		id = "Gattino", name = "Gattino Cosmonauta", rarity = "Mitico",
		maxHealth = 1000, catchRate = 0.03, income = 250, sellPrice = 6000, speed = 22, damage = 45,
		shape = "Ball", size = Vector3.new(4.4, 4.4, 4.4),
		bodyColor = Color3.fromRGB(250, 250, 255), accentColor = Color3.fromRGB(80, 230, 255), accessory = "Capacete",
		evolutions = { "Gatto Galattico", "Gattone Universale" }, signature = "Miado Cósmico",
	},
}

---------------------------------------------------------------------
-- BOLAS DE CAPTURA
-- multiplier = multiplica a chance de captura
---------------------------------------------------------------------
Config.Balls = {
	{ id = "Basica", name = "Bola Básica", multiplier = 1, price = 15, color = Color3.fromRGB(230, 50, 50) },
	{ id = "Super", name = "Super Bola", multiplier = 1.75, price = 60, color = Color3.fromRGB(50, 120, 255) },
	{ id = "Ultra", name = "Ultra Bola", multiplier = 2.75, price = 200, color = Color3.fromRGB(255, 200, 30) },
	{ id = "Suprema", name = "Bola Suprema", multiplier = 6, price = 1500, color = Color3.fromRGB(170, 60, 255) },
}

---------------------------------------------------------------------
-- TACOS DE BEISEBOL
-- Taco forte demais pode NOCAUTEAR o brainrot (aí ele foge e você não captura)!
---------------------------------------------------------------------
Config.Bats = {
	{ id = "Madeira", name = "Taco de Madeira", damage = 10, cooldown = 0.6, range = 9, price = 0,
		color = Color3.fromRGB(160, 105, 55), material = Enum.Material.Wood },
	{ id = "Metal", name = "Taco de Metal", damage = 22, cooldown = 0.55, range = 9.5, price = 600,
		color = Color3.fromRGB(170, 175, 185), material = Enum.Material.Metal },
	{ id = "Ouro", name = "Taco de Ouro", damage = 45, cooldown = 0.5, range = 10, price = 4000,
		color = Color3.fromRGB(255, 200, 40), material = Enum.Material.Metal },
	{ id = "Diamante", name = "Taco de Diamante", damage = 90, cooldown = 0.45, range = 11, price = 20000,
		color = Color3.fromRGB(110, 230, 255), material = Enum.Material.Glass },
}

---------------------------------------------------------------------
-- CAPTURA
-- chance = catchRate * multiplicador da bola * bônus de vida
-- bônus de vida vai de 1x (vida cheia) até (1 + HealthBonusMax)x (quase sem vida)
---------------------------------------------------------------------
Config.Catch = {
	HealthBonusMax = 2, -- quase sem vida = 3x mais chance
	MinChance = 0.01,
	MaxChance = 0.98,
	ThrowCooldown = 1,
	ThrowSpeed = 85,
	Gravity = 60,
	MaxThrowDistance = 120,
}

---------------------------------------------------------------------
-- BRAINROTS SELVAGENS
---------------------------------------------------------------------
Config.Wild = {
	MaxAlive = 14,
	SpawnInterval = 3,
	ZoneCenter = Vector3.new(0, 0, 0),
	ZoneSize = Vector2.new(220, 220), -- X, Z
	GroundY = 0,
	RegenDelay = 8, -- segundos sem apanhar até começar a regenerar
	RegenPercentPerSecond = 0.03,
	AggroTime = 8, -- quanto tempo ele fica bravo depois de apanhar
	AttackRange = 6,
	AttackCooldown = 1.5,
	Knockback = 3,
}

---------------------------------------------------------------------
-- TYCOON (BASES)
---------------------------------------------------------------------
Config.Tycoon = {
	PlotSize = 80,
	SlotCount = 12,
	StartingSlots = 3,
	-- preço para desbloquear cada pedestal (os 3 primeiros são grátis)
	SlotPrices = { 0, 0, 0, 100, 250, 500, 1000, 2000, 4000, 8000, 15000, 30000 },
	IncomeTick = 1,
	-- posição e rotação de cada base (de frente para a zona de caça)
	Plots = {
		{ position = Vector3.new(-130, 0, 190), angle = 180 },
		{ position = Vector3.new(0, 0, 190), angle = 180 },
		{ position = Vector3.new(130, 0, 190), angle = 180 },
		{ position = Vector3.new(-130, 0, -190), angle = 0 },
		{ position = Vector3.new(0, 0, -190), angle = 0 },
		{ position = Vector3.new(130, 0, -190), angle = 0 },
	},
}

---------------------------------------------------------------------
-- NÍVEIS E EVOLUÇÃO
-- Seus brainrots ganham XP derrotando brainrots selvagens com você.
-- Cada nível dá mais vida, força e renda. Nos níveis de EvolveLevels eles evoluem!
---------------------------------------------------------------------
Config.Levels = {
	MaxLevel = 50,
	EvolveLevels = { 15, 30 }, -- nível para virar a 2ª e a 3ª evolução
	HealthPerLevel = 0.08, -- +8% de vida por nível
	PowerPerLevel = 0.08, -- +8% de força por nível
	IncomePerLevel = 0.10, -- +10% de renda por nível
	SellPerLevel = 0.10,
	StageHealth = { 1, 1.3, 1.7 }, -- multiplicador de vida em cada evolução
	StagePower = { 1, 1.3, 1.8 },
	StageIncome = { 1, 1.5, 2.5 },
	StageScale = { 1, 1.25, 1.5 }, -- tamanho do modelo
	XpBase = 25, -- XP para o nível 2
	XpExponent = 1.5, -- quanto mais alto, mais XP precisa
	CaptureXpShare = 0.5, -- o parceiro ganha metade do XP quando você captura
}

---------------------------------------------------------------------
-- ATAQUES DO PARCEIRO
-- kind: "Melee" (corpo a corpo), "Projectile" (de longe), "Area" (todos em volta)
-- power = multiplicador da força do brainrot
---------------------------------------------------------------------
Config.Moves = {
	{ id = "Basico", name = "Ataque", level = 1, power = 1, cooldown = 1.4, range = 6, kind = "Melee", auto = true },
	{ id = "Cabecada", name = "Cabeçada", level = 5, power = 2, cooldown = 6, range = 7, kind = "Melee", key = "Z" },
	{ id = "Rajada", name = "Rajada Brainrot", level = 10, power = 2.5, cooldown = 9, range = 45, kind = "Projectile", key = "X" },
	{ id = "Terremoto", name = "Terremoto", level = 20, power = 2, cooldown = 15, range = 16, kind = "Area", key = "C" },
	-- o nome deste vem do "signature" de cada brainrot
	{ id = "Especial", name = "Golpe Especial", level = 30, power = 4.5, cooldown = 22, range = 45, kind = "Projectile", key = "V", signature = true },
}

---------------------------------------------------------------------
-- PARCEIRO (o brainrot que luta com você)
---------------------------------------------------------------------
Config.Companion = {
	HealthMultiplier = 2, -- parceiros são mais fortes que os selvagens do mesmo nível
	DamageMultiplier = 2,
	FollowDistance = 5,
	MinSpeed = 16,
	LeashDistance = 70, -- longe demais do dono = volta correndo
	TeleportDistance = 120,
	AutoTargetRadius = 30, -- no modo automático ataca brainrots até essa distância de você
	FaintTime = 20, -- segundos para voltar depois de desmaiar
	RegenDelay = 5,
	RegenPercentPerSecond = 0.05,
}

---------------------------------------------------------------------
-- Funções de busca (não precisa mexer)
---------------------------------------------------------------------
local function index(list)
	local map = {}
	for _, item in ipairs(list) do
		map[item.id] = item
	end
	return map
end

local brainrotById = index(Config.Brainrots)
local ballById = index(Config.Balls)
local batById = index(Config.Bats)
local moveById = index(Config.Moves)

function Config.getBrainrot(id)
	return brainrotById[id]
end

function Config.getBall(id)
	return ballById[id]
end

function Config.getBat(id)
	return batById[id]
end

function Config.getMove(id)
	return moveById[id]
end

function Config.getRarity(name)
	return Config.Rarities[name]
end

return Config
