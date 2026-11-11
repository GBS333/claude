-- Status dos brainrots por nível, evolução e mutação (servidor e interface usam o mesmo cálculo)

local Config = require(script.Parent.Config)

local L = Config.Levels
local Stats = {}

local function mutationMult(mutation: string?, field: string): number
	local m = Config.getMutation(mutation)
	return if m then m[field] or 1 else 1
end
Stats.mutationMult = mutationMult

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

function Stats.displayName(def, level: number, mutation: string?): string
	local stage = Stats.stage(level)
	local name = def.name
	if stage > 1 and def.evolutions and def.evolutions[stage - 1] then
		name = def.evolutions[stage - 1]
	end
	local m = Config.getMutation(mutation)
	if m then
		name = m.icon .. " " .. name
	end
	return name
end

local function levelMult(level: number, perLevel: number): number
	return 1 + perLevel * (level - 1)
end

-- stageOverride: os selvagens não evoluem, então eles usam 1
function Stats.maxHealth(def, level: number, stageOverride: number?, mutation: string?): number
	local stage = stageOverride or Stats.stage(level)
	return math.floor(def.maxHealth * levelMult(level, L.HealthPerLevel) * L.StageHealth[stage] * mutationMult(mutation, "health"))
end

function Stats.power(def, level: number, stageOverride: number?, mutation: string?): number
	local stage = stageOverride or Stats.stage(level)
	return def.damage * levelMult(level, L.PowerPerLevel) * L.StagePower[stage] * mutationMult(mutation, "power")
end

function Stats.income(def, level: number, mutation: string?): number
	local stage = Stats.stage(level)
	local value = def.income * levelMult(level, L.IncomePerLevel) * L.StageIncome[stage] * mutationMult(mutation, "income")
	return math.floor(value * 10 + 0.5) / 10
end

function Stats.sellPrice(def, level: number, mutation: string?): number
	local stage = Stats.stage(level)
	return math.floor(def.sellPrice * levelMult(level, L.SellPerLevel) * L.StageIncome[stage] * mutationMult(mutation, "income"))
end

function Stats.scale(level: number): number
	return L.StageScale[Stats.stage(level)]
end

function Stats.xpToNext(level: number): number
	return math.floor(L.XpBase * level ^ L.XpExponent)
end

function Stats.companionMaxHealth(def, level: number, mutation: string?): number
	return math.floor(Stats.maxHealth(def, level, nil, mutation) * Config.Companion.HealthMultiplier)
end

function Stats.companionPower(def, level: number, mutation: string?): number
	return Stats.power(def, level, nil, mutation) * Config.Companion.DamageMultiplier
end

function Stats.moveName(move, def): string
	if move.signature and def and def.signature then
		return def.signature
	end
	return move.name
end

function Stats.knownMoves(level: number)
	local list = {}
	for _, move in ipairs(Config.Moves) do
		if level >= move.level then
			table.insert(list, move)
		end
	end
	return list
end

-- XP ganho ao derrotar um selvagem
function Stats.xpReward(def, level: number): number
	local rarity = Config.getRarity(def.rarity)
	return math.floor(rarity.xpReward * (1 + 0.5 * (level - 1)))
end

---------------------------------------------------------------------
-- Jogador
---------------------------------------------------------------------
function Stats.playerXpToNext(level: number): number
	local P = Config.PlayerLevels
	return math.floor(P.XpBase * level ^ P.XpExponent)
end

-- quantos pedestais o jogador pode ter (aumenta com rebirth)
function Stats.maxSlots(rebirths: number): number
	local T = Config.Tycoon
	return math.min(T.SlotCount, T.BaseMaxSlots + T.SlotsPerRebirth * (rebirths or 0))
end

function Stats.rebirthIncomeMultiplier(rebirths: number): number
	return 1 + Config.Rebirth.IncomeBonus * (rebirths or 0)
end

-- progress = { level = n, bosses = { [id] = true }, rebirths = n }
-- Retorna true se pode entrar no bioma, ou false + motivo
function Stats.canEnter(progress, biome): (boolean, string?)
	local unlock = biome.unlock or {}
	if unlock.level and (progress.level or 1) < unlock.level then
		return false, "Precisa do nível " .. unlock.level
	end
	if unlock.boss and not (progress.bosses and progress.bosses[unlock.boss]) then
		local boss = Config.getBoss(unlock.boss)
		local where = boss and Config.getBiome(boss.biome)
		return false, "Derrote o chefão " .. (if boss then boss.name else unlock.boss)
			.. (if where then " (" .. where.name .. ")" else "")
	end
	if unlock.rebirths and (progress.rebirths or 0) < unlock.rebirths then
		return false, "Precisa de " .. unlock.rebirths .. " rebirth(s)"
	end
	return true, nil
end

-- Em qual bioma está essa posição (ou nil)
function Stats.biomeAt(position: Vector3)
	for _, biome in ipairs(Config.Biomes) do
		local c = biome.center
		if math.abs(position.X - c.X) <= biome.size.X / 2 and math.abs(position.Z - c.Z) <= biome.size.Y / 2
			and position.Y > c.Y - 40 and position.Y < c.Y + 120 then
			return biome
		end
	end
	return nil
end

return Stats
