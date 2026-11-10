-- Fórmula de captura (usada pelo servidor e pela interface do jogador)

local Config = require(script.Parent.Config)

local CatchMath = {}

-- Retorna um número de 0 a 1.
-- Quanto MENOS vida o brainrot tem, MAIOR a chance.
function CatchMath.getChance(catchRate: number, health: number, maxHealth: number, ballMultiplier: number): number
	local ratio = math.clamp(health / math.max(maxHealth, 1), 0, 1)
	local healthBonus = 1 + Config.Catch.HealthBonusMax * (1 - ratio)
	local chance = catchRate * ballMultiplier * healthBonus
	return math.clamp(chance, Config.Catch.MinChance, Config.Catch.MaxChance)
end

function CatchMath.formatNumber(n: number): string
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

return CatchMath
