-- Game Strategy Module
-- Central strategy brain that all modes consult for desire multipliers.
-- Implements Rock-Paper-Scissors macro strategy:
--   AGGRESSIVE (Scissors) = Smoke ganks, push, end game
--   DEFENSIVE  (Rock)     = HG defense, hold, wait for pickoffs
--   SPLIT_FARM (Paper)    = Split push, map control, outfarm

local J = require(GetScriptDirectory()..'/FunLib/jmz_func')

local M = {}

M.STRATEGY_AGGRESSIVE = 1
M.STRATEGY_DEFENSIVE  = 2
M.STRATEGY_SPLIT_FARM = 3

-- Cache to avoid recalculating every frame (refresh every 3 seconds)
local strategyCache = nil
local CACHE_TTL = 3

function M.GetTeamStrategy()
	local now = DotaTime()
	if strategyCache and now - strategyCache.lastUpdate < CACHE_TTL then
		return strategyCache
	end

	local teamNW, enemyNW = J.GetInventoryNetworth()
	local nwAdvantage = (teamNW or 0) - (enemyNW or 0)
	local aliveAllies  = J.GetNumOfAliveHeroes(false)
	local aliveEnemies = J.GetNumOfAliveHeroes(true)
	local aliveAdv = aliveAllies - aliveEnemies
	local avgLevel = J.GetAverageLevel(false)
	local enemyAvgLevel = J.GetAverageLevel(true)
	local levelAdv = avgLevel - enemyAvgLevel
	local hasAegis = J.DoesTeamHaveAegis()
	local isTurbo = GetGameMode() == 23
	local isLate = J.IsLateGame()

	-- Count our remaining T3+ towers as proxy for "how safe is our base"
	local team = GetTeam()
	local ourT3Alive = 0
	for _, towerID in ipairs({TOWER_TOP_3, TOWER_MID_3, TOWER_BOT_3}) do
		local tower = GetTower(team, towerID)
		if tower ~= nil and tower:IsAlive() then
			ourT3Alive = ourT3Alive + 1
		end
	end

	-- Count enemy T3 towers (how close we are to their base)
	local enemyTeam = GetOpposingTeam()
	local enemyT3Alive = 0
	for _, towerID in ipairs({TOWER_TOP_3, TOWER_MID_3, TOWER_BOT_3}) do
		local tower = GetTower(enemyTeam, towerID)
		if tower ~= nil and tower:IsAlive() then
			enemyT3Alive = enemyT3Alive + 1
		end
	end

	-- Score each strategy (highest score wins)
	local aggScore  = 0
	local defScore  = 0
	local farmScore = 0

	-- Net worth advantage
	if nwAdvantage > 5000 then
		aggScore = aggScore + 2
	elseif nwAdvantage > 2000 then
		aggScore = aggScore + 1
	elseif nwAdvantage < -8000 then
		defScore = defScore + 2
		farmScore = farmScore + 1
	elseif nwAdvantage < -3000 then
		farmScore = farmScore + 2
	end

	-- Alive hero advantage
	if aliveAdv >= 2 then
		aggScore = aggScore + 3
	elseif aliveAdv >= 1 then
		aggScore = aggScore + 1
	elseif aliveAdv <= -2 then
		defScore = defScore + 3
		farmScore = farmScore + 1
	elseif aliveAdv <= -1 then
		defScore = defScore + 1
		farmScore = farmScore + 1
	end

	-- Aegis holder = go aggressive
	if hasAegis then
		aggScore = aggScore + 3
	end

	-- Level advantage
	if levelAdv > 2 then
		aggScore = aggScore + 1
	elseif levelAdv < -2 then
		farmScore = farmScore + 1
	end

	-- Tower state: if our T3s are threatened, defend
	if ourT3Alive < 3 then
		defScore = defScore + (3 - ourT3Alive)
	end

	-- If enemy T3s are down, push to end
	if enemyT3Alive < 3 then
		aggScore = aggScore + (3 - enemyT3Alive)
	end

	-- Late game scaling: if behind but late, farm matters less — fight or defend
	if isLate and nwAdvantage < -5000 then
		defScore = defScore + 1
		farmScore = farmScore - 1
	end

	-- Turbo mode: always bias aggressive — games should end fast
	if isTurbo then
		aggScore = aggScore + 2
		defScore = defScore - 1
		farmScore = farmScore - 1
	end

	-- Pick the winning strategy
	local strategy = M.STRATEGY_AGGRESSIVE
	local maxScore = aggScore
	if defScore > maxScore then
		strategy = M.STRATEGY_DEFENSIVE
		maxScore = defScore
	end
	if farmScore > maxScore then
		strategy = M.STRATEGY_SPLIT_FARM
	end

	-- Build multipliers based on strategy
	local push_mult, defend_mult, farm_mult, roam_mult

	if strategy == M.STRATEGY_AGGRESSIVE then
		push_mult   = 1.3
		defend_mult = 0.7
		farm_mult   = 0.6
		roam_mult   = 1.4
	elseif strategy == M.STRATEGY_DEFENSIVE then
		push_mult   = 0.6
		defend_mult = 1.3
		farm_mult   = 0.8
		roam_mult   = 0.7
	else -- SPLIT_FARM
		push_mult   = 0.9
		defend_mult = 0.8
		farm_mult   = 1.3
		roam_mult   = 0.9
	end

	strategyCache = {
		lastUpdate  = now,
		strategy    = strategy,
		push_mult   = push_mult,
		defend_mult = defend_mult,
		farm_mult   = farm_mult,
		roam_mult   = roam_mult,
		nwAdvantage = nwAdvantage,
		aliveAdv    = aliveAdv,
	}

	return strategyCache
end

-- Human-readable strategy name for debug prints
function M.GetStrategyName(strategy)
	if strategy == M.STRATEGY_AGGRESSIVE then return "AGGRESSIVE"
	elseif strategy == M.STRATEGY_DEFENSIVE then return "DEFENSIVE"
	else return "SPLIT_FARM"
	end
end

return M
