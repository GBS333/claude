-- Config: todos os números do jogo ficam aqui.
-- Mude à vontade para balancear (vida, chance de captura, preços, renda...).

local Config = {}

local V = Vector3.new
local RGB = Color3.fromRGB

-- Se true, o servidor constrói o mapa sozinho (terreno, biomas, bases...).
Config.BuildMap = true

-- Estilo do mapa: "Desenho" (cores lisas e vivas, estilo cartoon) ou "Realista" (terreno com texturas)
Config.MapStyle = "Desenho"

Config.DataStoreName = "BrainrotTycoon_v1"
Config.AutoSaveInterval = 120

Config.StartingCash = 50
Config.StartingBalls = { Basica = 10 }

-- Comandos de teste no chat (só no Studio ou para o dono do jogo): /ajuda
Config.AdminCommands = true

---------------------------------------------------------------------
-- RARIDADES (spawnWeight menor = aparece menos)
---------------------------------------------------------------------
Config.RarityOrder = { "Comum", "Raro", "Epico", "Lendario", "Mitico", "Celestial" }

Config.Rarities = {
	Comum = { display = "Comum", color = RGB(200, 200, 200), spawnWeight = 55, faintReward = 5, xpReward = 10, wildLevels = { 1, 5 } },
	Raro = { display = "Raro", color = RGB(70, 150, 255), spawnWeight = 27, faintReward = 15, xpReward = 25, wildLevels = { 3, 8 } },
	Epico = { display = "Épico", color = RGB(175, 85, 255), spawnWeight = 12, faintReward = 40, xpReward = 60, wildLevels = { 6, 12 } },
	Lendario = { display = "Lendário", color = RGB(255, 170, 0), spawnWeight = 5, faintReward = 120, xpReward = 150, wildLevels = { 10, 16 } },
	Mitico = { display = "Mítico", color = RGB(255, 60, 100), spawnWeight = 0.6, faintReward = 400, xpReward = 400, wildLevels = { 15, 20 } },
	Celestial = { display = "Celestial", color = RGB(130, 240, 255), spawnWeight = 0.15, faintReward = 1500, xpReward = 1200, wildLevels = { 22, 30 } },
}

---------------------------------------------------------------------
-- BIOMAS (cada brainrot nasce no bioma dele)
-- unlock: o que precisa para entrar
--   level = nível do jogador, boss = id do chefão derrotado, rebirths = quantidade de rebirths
---------------------------------------------------------------------
Config.Biomes = {
	{ id = "Floresta", name = "Floresta", icon = "🌳", center = V(0, 0, 0), size = Vector2.new(220, 220), maxAlive = 14,
		unlock = {} },
	{ id = "Deserto", name = "Deserto", icon = "🏜", center = V(350, 0, 0), size = Vector2.new(240, 300), maxAlive = 10,
		unlock = { level = 5 } },
	{ id = "Pantano", name = "Pântano", icon = "🐊", center = V(-350, 0, 0), size = Vector2.new(240, 300), maxAlive = 10,
		unlock = { level = 12 } },
	{ id = "Neve", name = "Montanha de Neve", icon = "❄", center = V(0, 0, -420), size = Vector2.new(440, 200), maxAlive = 10,
		unlock = { boss = "TungGigante" } },
	{ id = "Vulcao", name = "Vulcão", icon = "🌋", center = V(0, 0, 420), size = Vector2.new(440, 200), maxAlive = 10,
		unlock = { boss = "FrigoTita" } },
	{ id = "Ceu", name = "Céu Celestial", icon = "☁", center = V(720, 160, 0), size = Vector2.new(200, 200), maxAlive = 8,
		unlock = { boss = "BombardiroImperador", rebirths = 1 } },
}

---------------------------------------------------------------------
-- CHEFÕES (derrote para desbloquear áreas; não dá para capturar)
---------------------------------------------------------------------
Config.Bosses = {
	{ id = "TungGigante", name = "Tung Tung Gigante", brainrot = "TungTung", biome = "Floresta", position = V(0, 0, 60),
		maxHealth = 2500, damage = 20, scale = 3.2, respawn = 150, reward = 2500, xp = 800 },
	{ id = "FrigoTita", name = "Frigo Camelo Titã", brainrot = "FrigoCamelo", biome = "Neve", position = V(0, 0, -420),
		maxHealth = 12000, damage = 40, scale = 3.2, respawn = 210, reward = 15000, xp = 4000 },
	{ id = "BombardiroImperador", name = "Bombardiro Imperador", brainrot = "Bombardiro", biome = "Vulcao", position = V(0, 0, 420),
		maxHealth = 50000, damage = 65, scale = 2.6, respawn = 300, reward = 80000, xp = 15000 },
}
Config.Boss = {
	SlamInterval = 6, -- pancada no chão que acerta todo mundo em volta
	SlamRadius = 20,
	SlamKnockback = 90,
	WanderRadius = 35,
	RegenDelay = 15,
	RegenPercentPerSecond = 0.02,
}

---------------------------------------------------------------------
-- BRAINROTS
-- id         = nome interno (use esse nome no modelo em ServerStorage/BrainrotModels)
-- biome      = onde ele nasce
-- maxHealth  = vida      catchRate = chance base de captura (0.5 = 50%)
-- income     = $/s no pedestal       sellPrice = preço de venda
-- speed      = velocidade            damage = dano que ele dá
-- size       = (largura, ALTURA, comprimento). Modelos da Toolbox são ajustados para essa altura
-- modelYaw   = (opcional) gira o modelo da Toolbox em graus se ele andar de costas/de lado
-- evolutions = nomes da 2ª e 3ª evolução     signature = golpe especial (nível 30)
---------------------------------------------------------------------
local function B(id, name, rarity, biome, hp, catch, income, sell, speed, damage, size, evo1, evo2, signature)
	return {
		id = id, name = name, rarity = rarity, biome = biome, maxHealth = hp, catchRate = catch, income = income,
		sellPrice = sell, speed = speed, damage = damage, size = size, evolutions = { evo1, evo2 }, signature = signature,
	}
end

Config.Brainrots = {
	-- 🌳 FLORESTA
	B("Lirili", "Lirilì Larilà", "Comum", "Floresta", 50, 0.50, 1, 20, 10, 5, V(2.6, 6, 2.6), "Lirilì Larilà Gigante", "Lirilì Larilà Supremo", "Espinhos de Cacto"),
	B("Ambalabu", "Boneca Ambalabu", "Comum", "Floresta", 55, 0.48, 1.5, 25, 12, 5, V(2.8, 6, 2.6), "Boneca Ambalabu Turbo", "Boneca Ambalabu Rei do Pneu", "Pneu Rolante"),
	B("TrippiTroppi", "Trippi Troppi", "Comum", "Floresta", 60, 0.45, 2, 30, 13, 6, V(2, 3.4, 4), "Trippi Troppi Troppa", "Trippi Troppi Supremo", "Miado Camarão"),
	B("Chimpanzini", "Chimpanzini Bananini", "Comum", "Floresta", 70, 0.40, 3, 40, 14, 7, V(2.2, 5.4, 2.2), "Chimpanzini Bananini Forte", "Chimpanzone Bananone", "Casca Escorregadia"),
	B("TungTung", "Tung Tung Tung Sahur", "Raro", "Floresta", 130, 0.27, 9, 140, 16, 12, V(2.6, 6.5, 2.6), "Tung Tung Tung Tung Sahur", "Tung Tung Sahur Supremo", "Tung Tung Tung!"),
	B("Patapim", "Brr Brr Patapim", "Raro", "Floresta", 140, 0.25, 10, 150, 15, 11, V(2.6, 6.6, 2.6), "Brr Brr Patapim Ancião", "Brr Brr Patapim da Floresta", "Pisão Gigante"),
	B("Orangutini", "Orangutini Ananassini", "Epico", "Floresta", 240, 0.14, 24, 430, 17, 17, V(2.8, 5.6, 2.6), "Orangutini Ananassone", "Orangutini Tropicale", "Chuva de Abacaxi"),

	-- 🏜 DESERTO
	B("CactoHipopotamo", "Il Cacto Hipopotamo", "Comum", "Deserto", 80, 0.40, 4, 60, 11, 8, V(3, 5, 3.4), "Il Cacto Hipopotamo Spinoso", "Il Cacto Hipopotamo Re", "Abraço Espinhoso"),
	B("RhinoToasterino", "Rhino Toasterino", "Raro", "Deserto", 170, 0.24, 13, 200, 17, 14, V(3, 4.6, 4.2), "Rhino Toasterino Turbo", "Rhino Toasterino Supremo", "Torrada Atômica"),
	B("TricTrac", "Tric Trac Baraboom", "Epico", "Deserto", 270, 0.13, 30, 520, 18, 19, V(2.8, 5, 2.8), "Tric Trac Baraboom Mega", "Tric Trac Baraboom Supremo", "Baraboom!"),
	B("FrigoCamelo", "Frigo Camelo", "Epico", "Deserto", 280, 0.12, 32, 540, 16, 19, V(2.4, 6.6, 3), "Frigo Camelo Freezer", "Frigo Camelo Polar", "Sopro Congelante"),
	B("UdinDinDun", "Udin Din Din Dun", "Lendario", "Deserto", 520, 0.07, 85, 1600, 20, 30, V(2.6, 6, 2.6), "Udin Din Din Din Dun", "Udin Supremo", "Din Din Dun!"),

	-- 🐊 PÂNTANO
	B("Glorbo", "Glorbo Fruttodrillo", "Comum", "Pantano", 90, 0.38, 5, 70, 10, 9, V(3, 3.6, 4.4), "Glorbo Fruttodrillo Maduro", "Glorbo Supremo", "Mordida Frutada"),
	B("Bobritto", "Bobritto Bandito", "Raro", "Pantano", 180, 0.23, 15, 230, 16, 15, V(2.6, 5, 2.6), "Bobritto Bandito Chefe", "Bobritto Bandito Lendário", "Assalto Relâmpago"),
	B("Burbaloni", "Burbaloni Luliloli", "Epico", "Pantano", 300, 0.12, 36, 600, 15, 20, V(3.6, 4.4, 3.6), "Burbaloni Luliloli Gordo", "Burbaloni Supremo", "Bolha Gigante"),
	B("Tralalero", "Tralalero Tralala", "Lendario", "Pantano", 540, 0.07, 95, 1800, 20, 31, V(2.6, 4.6, 6), "Tralalero Tralala Turbo", "Tralalero Tralala Supremo", "Tsunami Tralala"),

	-- ❄ NEVE
	B("Bicus", "Brri Brri Bicus Dicus", "Comum", "Neve", 110, 0.36, 7, 100, 13, 11, V(2.4, 4.6, 2.6), "Brri Brri Bicus Dicus Bombicus", "Bicus Supremo", "Bicada de Gelo"),
	B("Ballerina", "Ballerina Cappuccina", "Epico", "Neve", 320, 0.12, 40, 650, 18, 21, V(2.6, 6, 2.6), "Ballerina Cappuccina Prima", "Ballerina Cappuccina Suprema", "Pirueta Espresso"),
	B("Cocofanto", "Cocofanto Elefanto", "Lendario", "Neve", 600, 0.06, 110, 2100, 18, 34, V(3.4, 5.4, 3.6), "Cocofanto Elefanto Gigante", "Cocofanto Supremo", "Coco Bomba"),

	-- 🌋 VULCÃO
	B("TaTaSahur", "Ta Ta Ta Ta Sahur", "Raro", "Vulcao", 220, 0.22, 18, 280, 17, 17, V(2.6, 5.6, 2.6), "Ta Ta Ta Ta Ta Sahur", "Ta Ta Sahur Supremo", "Ta Ta Ta Ta!"),
	B("CappuccinoAssassino", "Cappuccino Assassino", "Epico", "Vulcao", 340, 0.11, 42, 700, 19, 23, V(2.8, 4.6, 2.6), "Cappuccino Assassino Sombra", "Cappuccino Assassino Mestre", "Corte Duplo"),
	B("Bombardiro", "Bombardiro Crocodilo", "Lendario", "Vulcao", 650, 0.06, 120, 2300, 21, 36, V(4, 5, 7), "Bombardiro Crocodilo Ás", "Bombardiro Crocodilo Supremo", "Bombardeio"),
	B("Svinino", "Svinino Bombondino", "Mitico", "Vulcao", 1100, 0.03, 260, 6500, 20, 46, V(3.2, 4.4, 3.8), "Svinino Bombondino Atômico", "Svinino Supremo", "Explosão Suína"),

	-- ☁ CÉU CELESTIAL
	B("Gusini", "Bombombini Gusini", "Raro", "Ceu", 260, 0.22, 20, 320, 18, 18, V(2.4, 5, 3), "Bombombini Gusini Turbo", "Bombombini Gusini Supersônico", "Rasante a Jato"),
	B("VacaSaturno", "La Vaca Saturno Saturnita", "Mitico", "Ceu", 1200, 0.03, 280, 7000, 22, 48, V(3.4, 5.2, 3.4), "La Vaca Saturno Galáctica", "La Vaca Saturno Suprema", "Anel de Saturno"),
	B("GirafaCelestre", "Girafa Celestre", "Celestial", "Ceu", 2500, 0.015, 900, 25000, 22, 70, V(2.8, 8, 3.4), "Girafa Celestre Divina", "Girafa Celestre Suprema", "Pescoço Estelar"),
	B("OdinDinDun", "Odin Din Din Dun", "Celestial", "Ceu", 2800, 0.012, 1000, 30000, 21, 75, V(3, 6.6, 3), "Odin Din Din Din Dun", "Odin Supremo", "Martelo dos Deuses"),
}

---------------------------------------------------------------------
-- MUTAÇÕES (deixam o brainrot mais forte e com MAIS renda)
-- chance = chance de nascer assim a qualquer hora (as de evento só aparecem no evento)
---------------------------------------------------------------------
Config.MutationOrder = { "Dourado", "Diamante", "Radioativo", "Magma", "ArcoIris" }
Config.Mutations = {
	Dourado = { name = "Dourado", icon = "✨", color = RGB(255, 210, 60), income = 2, power = 1.2, health = 1.2, chance = 0.03 },
	Diamante = { name = "Diamante", icon = "💎", color = RGB(120, 230, 255), income = 4, power = 1.5, health = 1.5, chance = 0.007 },
	Radioativo = { name = "Radioativo", icon = "☢", color = RGB(120, 255, 80), income = 3, power = 1.8, health = 1.6 },
	Magma = { name = "Magma", icon = "🌋", color = RGB(255, 110, 30), income = 4, power = 2.2, health = 2 },
	ArcoIris = { name = "Arco-Íris", icon = "🌈", color = RGB(255, 120, 220), income = 6, power = 1.5, health = 1.5 },
}

---------------------------------------------------------------------
-- EVENTOS (de tempos em tempos o mapa muda e os brainrots ganham mutações)
---------------------------------------------------------------------
Config.Events = {
	FirstDelay = 120, -- segundos até o primeiro evento
	Interval = 420, -- tempo entre eventos
	Duration = 180, -- quanto tempo o evento dura
	List = {
		{ id = "Radiacao", name = "☢ Chuva Radioativa", mutation = "Radioativo", chance = 0.45,
			tint = RGB(190, 255, 170), atmosphere = RGB(150, 230, 120), text = "Brainrots RADIOATIVOS: mais fortes e 3x mais dinheiro!" },
		{ id = "Magma", name = "🌋 Erupção de Magma", mutation = "Magma", chance = 0.35,
			tint = RGB(255, 200, 165), atmosphere = RGB(255, 140, 90), text = "Brainrots de MAGMA: muito fortes e 4x mais dinheiro!" },
		{ id = "ArcoIris", name = "🌈 Arco-Íris Brainrot", mutation = "ArcoIris", chance = 0.25,
			tint = RGB(255, 225, 255), atmosphere = RGB(255, 195, 240), text = "Brainrots ARCO-ÍRIS: 6x mais dinheiro!" },
	},
}

---------------------------------------------------------------------
-- BOLAS DE CAPTURA (rebirth = quantos rebirths precisa para comprar)
---------------------------------------------------------------------
Config.Balls = {
	{ id = "Basica", name = "Bola Básica", multiplier = 1, price = 15, color = RGB(230, 50, 50), rebirth = 0 },
	{ id = "Super", name = "Super Bola", multiplier = 1.75, price = 60, color = RGB(50, 120, 255), rebirth = 0 },
	{ id = "Ultra", name = "Ultra Bola", multiplier = 2.75, price = 200, color = RGB(255, 200, 30), rebirth = 1 },
	{ id = "Suprema", name = "Bola Suprema", multiplier = 6, price = 1500, color = RGB(170, 60, 255), rebirth = 2 },
	{ id = "Celestial", name = "Bola Celestial", multiplier = 15, price = 12000, color = RGB(130, 240, 255), rebirth = 3 },
}

---------------------------------------------------------------------
-- OBJETOS DE BATER
-- damage = dano nos brainrots   pvpDamage = dano em jogadores   knockback = empurrão em jogadores
-- look = "bat" (taco), "pan" (frigideira), "hammer" (martelo)
-- Cuidado: arma forte demais pode NOCAUTEAR o brainrot antes de você capturar!
---------------------------------------------------------------------
Config.Bats = {
	{ id = "Madeira", name = "Taco de Madeira", look = "bat", damage = 10, pvpDamage = 8, knockback = 35, cooldown = 0.6, range = 9,
		price = 0, rebirth = 0, color = RGB(160, 105, 55), material = Enum.Material.Wood },
	{ id = "Frigideira", name = "Frigideira", look = "pan", damage = 15, pvpDamage = 10, knockback = 75, cooldown = 0.65, range = 8.5,
		price = 350, rebirth = 0, color = RGB(45, 45, 50), material = Enum.Material.Metal },
	{ id = "Metal", name = "Taco de Metal", look = "bat", damage = 22, pvpDamage = 12, knockback = 45, cooldown = 0.55, range = 9.5,
		price = 600, rebirth = 0, color = RGB(170, 175, 185), material = Enum.Material.Metal },
	{ id = "Martelo", name = "Martelo de Borracha", look = "hammer", damage = 32, pvpDamage = 12, knockback = 110, cooldown = 0.8, range = 9,
		price = 2500, rebirth = 0, color = RGB(230, 60, 60), material = Enum.Material.SmoothPlastic },
	{ id = "Ouro", name = "Taco de Ouro", look = "bat", damage = 45, pvpDamage = 15, knockback = 55, cooldown = 0.5, range = 10,
		price = 4000, rebirth = 0, color = RGB(255, 200, 40), material = Enum.Material.Metal },
	{ id = "Diamante", name = "Taco de Diamante", look = "bat", damage = 90, pvpDamage = 18, knockback = 65, cooldown = 0.45, range = 11,
		price = 20000, rebirth = 0, color = RGB(110, 230, 255), material = Enum.Material.Glass },
	{ id = "Lava", name = "Martelo de Lava", look = "hammer", damage = 170, pvpDamage = 22, knockback = 120, cooldown = 0.6, range = 11,
		price = 90000, rebirth = 1, color = RGB(255, 110, 30), material = Enum.Material.Neon },
	{ id = "CelestialBat", name = "Taco Celestial", look = "bat", damage = 320, pvpDamage = 26, knockback = 130, cooldown = 0.45, range = 12,
		price = 450000, rebirth = 2, color = RGB(130, 240, 255), material = Enum.Material.Neon },
	{ id = "Cosmico", name = "Martelo Cósmico", look = "hammer", damage = 650, pvpDamage = 32, knockback = 170, cooldown = 0.55, range = 13,
		price = 2500000, rebirth = 3, color = RGB(150, 80, 255), material = Enum.Material.Neon },
}

---------------------------------------------------------------------
-- EQUIPAMENTOS (compra uma vez e fica para sempre)
---------------------------------------------------------------------
Config.Gear = {
	{ id = "MolaVelocidade", name = "Mola de Velocidade", kind = "speed", value = 30, price = 2500, rebirth = 0,
		color = RGB(60, 200, 255), description = "Segure para correr muito rápido" },
	{ id = "MolaPulo", name = "Mola de Pulo", kind = "jump", value = 95, price = 4000, rebirth = 0,
		color = RGB(120, 255, 120), description = "Segure para pular bem alto" },
	{ id = "EscudoBolha", name = "Escudo de Bolha", kind = "shield", duration = 5, cooldown = 25, price = 8000, rebirth = 0,
		color = RGB(150, 200, 255), description = "Clique: fica imune a dano e empurrões por 5s" },
	{ id = "CapaInvisivel", name = "Capa de Invisibilidade", kind = "invisible", duration = 8, cooldown = 30, price = 15000, rebirth = 0,
		color = RGB(150, 120, 255), description = "Clique: fica invisível por 8s (ótimo para roubar!)" },
}

---------------------------------------------------------------------
-- CAPTURA
---------------------------------------------------------------------
Config.Catch = {
	HealthBonusMax = 2, -- quase sem vida = 3x mais chance
	MinChance = 0.005,
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
	SpawnInterval = 3,
	RegenDelay = 8,
	RegenPercentPerSecond = 0.03,
	AggroTime = 8,
	AttackRange = 6,
	AttackCooldown = 1.5,
	Knockback = 3,
	ActiveDistance = 260, -- só se mexem se tiver jogador perto (economiza servidor)
}

---------------------------------------------------------------------
-- TYCOON (BASES)
---------------------------------------------------------------------
Config.Tycoon = {
	PlotSize = 80,
	SlotCount = 20, -- máximo de pedestais (com rebirths)
	BaseMaxSlots = 12, -- máximo sem rebirth
	SlotsPerRebirth = 2, -- cada rebirth libera mais pedestais
	StartingSlots = 3,
	SlotPrices = { 0, 0, 0, 100, 250, 500, 1000, 2000, 4000, 8000, 15000, 30000,
		50000, 80000, 120000, 180000, 260000, 380000, 550000, 800000 },
	IncomeTick = 1,
	LockDuration = 60, -- trancar a base
	LockCooldown = 180,
	Plots = {
		{ position = V(-130, 0, 190), angle = 180 },
		{ position = V(0, 0, 190), angle = 180 },
		{ position = V(130, 0, 190), angle = 180 },
		{ position = V(-130, 0, -190), angle = 0 },
		{ position = V(0, 0, -190), angle = 0 },
		{ position = V(130, 0, -190), angle = 0 },
	},
}

---------------------------------------------------------------------
-- ROUBO (pegue brainrots da base dos outros e leve para a sua!)
---------------------------------------------------------------------
Config.Steal = {
	HoldDuration = 1.5, -- segurar E para pegar
	TimeLimit = 60, -- segundos para chegar na sua base
	CarrySpeed = 13, -- velocidade carregando
}

---------------------------------------------------------------------
-- PvP (jogadores podem se bater)
---------------------------------------------------------------------
Config.PvP = {
	Enabled = true,
	SafeRadius = 25, -- ninguém apanha perto do spawn
}

---------------------------------------------------------------------
-- DUELO (quem ganha pode levar um brainrot do outro, ou o outro paga para não perder)
---------------------------------------------------------------------
Config.Duel = {
	Arena = V(170, 0, -90),
	PadOffset = 24,
	Countdown = 3,
	MaxTime = 120,
	PickTime = 30,
	RansomTime = 20,
	RansomMultiplier = 2, -- resgate = preço de venda x isso
	CompanionDamageScale = 1,
}

---------------------------------------------------------------------
-- REBIRTH (volta o dinheiro para o começo, mas libera bolas, armas e pedestais e dá +renda)
---------------------------------------------------------------------
Config.Rebirth = {
	Max = 5,
	Costs = { 50000, 250000, 1000000, 5000000, 25000000 },
	Levels = { 15, 25, 35, 45, 60 }, -- nível do jogador necessário
	IncomeBonus = 0.5, -- +50% de renda por rebirth
}

---------------------------------------------------------------------
-- NÍVEL DO JOGADOR (sobe derrotando e capturando brainrots e chefões)
---------------------------------------------------------------------
Config.PlayerLevels = {
	Max = 100,
	XpBase = 40,
	XpExponent = 1.4,
}

---------------------------------------------------------------------
-- NÍVEIS E EVOLUÇÃO DOS BRAINROTS
---------------------------------------------------------------------
Config.Levels = {
	MaxLevel = 50,
	EvolveLevels = { 15, 30 },
	HealthPerLevel = 0.08,
	PowerPerLevel = 0.08,
	IncomePerLevel = 0.10,
	SellPerLevel = 0.10,
	StageHealth = { 1, 1.3, 1.7 },
	StagePower = { 1, 1.3, 1.8 },
	StageIncome = { 1, 1.5, 2.5 },
	StageScale = { 1, 1.25, 1.5 },
	XpBase = 25,
	XpExponent = 1.5,
	CaptureXpShare = 0.5,
}

---------------------------------------------------------------------
-- ATAQUES DO PARCEIRO
---------------------------------------------------------------------
Config.Moves = {
	{ id = "Basico", name = "Ataque", level = 1, power = 1, cooldown = 1.4, range = 6, kind = "Melee", auto = true },
	{ id = "Cabecada", name = "Cabeçada", level = 5, power = 2, cooldown = 6, range = 7, kind = "Melee", key = "Z" },
	{ id = "Rajada", name = "Rajada Brainrot", level = 10, power = 2.5, cooldown = 9, range = 45, kind = "Projectile", key = "X" },
	{ id = "Terremoto", name = "Terremoto", level = 20, power = 2, cooldown = 15, range = 16, kind = "Area", key = "C" },
	{ id = "Especial", name = "Golpe Especial", level = 30, power = 4.5, cooldown = 22, range = 45, kind = "Projectile", key = "V", signature = true },
}

---------------------------------------------------------------------
-- PARCEIRO
---------------------------------------------------------------------
Config.Companion = {
	HealthMultiplier = 2,
	DamageMultiplier = 2,
	FollowDistance = 5,
	MinSpeed = 16,
	LeashDistance = 70,
	TeleportDistance = 120,
	AutoTargetRadius = 30,
	FaintTime = 20,
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
local biomeById = index(Config.Biomes)
local bossById = index(Config.Bosses)
local gearById = index(Config.Gear)
local eventById = index(Config.Events.List)

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
function Config.getBiome(id)
	return biomeById[id]
end
function Config.getBoss(id)
	return bossById[id]
end
function Config.getGear(id)
	return gearById[id]
end
function Config.getEvent(id)
	return eventById[id]
end
function Config.getMutation(id)
	return id and Config.Mutations[id] or nil
end

return Config
