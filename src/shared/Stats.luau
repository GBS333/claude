-- Status dos brainrots por nível e evolução (servidor e interface usam o mesmo cálculo)

local Config = require(script.Parent.Config)

local L = Config.Levels
local Stats = {}

-- 1 = forma normal, 2 = primeira evolução, 3 = evolução final
function Stats.stage(level: number): number
	local stage = 1
	for i, evolveLevel in ipairs(L.EvolveLevels) do
		if level >= evolveLevel then
			stage = i + 1
		end
	end
	return stage
end

function Stats.displayName(def, level: number): string
	local stage = Stats.stage(level)
	if stage > 1 and def.evolutions and def.evolutions[stage - 1] then
		return def.evolutions[stage - 1]
	end
	return def.name
end

local function levelMult(level: number, perLevel: number): number
	return 1 + perLevel * (level - 1)
end

-- stageOverride: os selvagens não evoluem, então eles usam 1
function Stats.maxHealth(def, level: number, stageOverride: number?): number
	local stage = stageOverride or Stats.stage(level)
	return math.floor(def.maxHealth * levelMult(level, L.HealthPerLevel) * L.StageHealth[stage])
end

function Stats.power(def, level: number, stageOverride: number?): number
	local stage = stageOverride or Stats.stage(level)
	return def.damage * levelMult(level, L.PowerPerLevel) * L.StagePower[stage]
end

function Stats.income(def, level: number): number
	local stage = Stats.stage(level)
	return math.floor(def.income * levelMult(level, L.IncomePerLevel) * L.StageIncome[stage] * 10 + 0.5) / 10
end

function Stats.sellPrice(def, level: number): number
	local stage = Stats.stage(level)
	return math.floor(def.sellPrice * levelMult(level, L.SellPerLevel) * L.StageIncome[stage])
end

function Stats.scale(level: number): number
	return L.StageScale[Stats.stage(level)]
end

-- XP para passar do nível atual para o próximo
function Stats.xpToNext(level: number): number
	return math.floor(L.XpBase * level ^ L.XpExponent)
end

function Stats.companionMaxHealth(def, level: number): number
	return math.floor(Stats.maxHealth(def, level) * Config.Companion.HealthMultiplier)
end

function Stats.companionPower(def, level: number): number
	return Stats.power(def, level) * Config.Companion.DamageMultiplier
end

function Stats.moveName(move, def): string
	if move.signature and def and def.signature then
		return def.signature
	end
	return move.name
end

-- ataques que o brainrot já aprendeu
function Stats.knownMoves(level: number)
	local list = {}
	for _, move in ipairs(Config.Moves) do
		if level >= move.level then
			table.insert(list, move)
		end
	end
	return list
end

-- quantos XP ganha ao derrotar um selvagem
function Stats.xpReward(def, level: number): number
	local rarity = Config.getRarity(def.rarity)
	return math.floor(rarity.xpReward * (1 + 0.5 * (level - 1)))
end

return Stats
