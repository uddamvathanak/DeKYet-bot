-- Game Strategy Module
-- Central strategy brain that all modes consult for desire multipliers.
-- Rock-Paper-Scissors (user-defined semantics):
--   ROCK     = Losing / base threatened -> HG defend, stay grouped, survive.
--   PAPER    = Winning -> smoke/gank/push to end the game. Only split-farm
--              if a core is missing a key power-spike item (BKB / Scepter /
--              Refresher) AND game isn't already late, else push 5-man.
--   SCISSORS = Even game, enemy appears split (fog/vision) -> smoke gank
--              the isolated side. Vision-driven counter to split-farming.

local J = require(GetScriptDirectory()..'/FunLib/jmz_func')

local M = {}

M.STRATEGY_ROCK     = 2  -- defensive
M.STRATEGY_PAPER    = 1  -- aggressive push when ahead
M.STRATEGY_SCISSORS = 3  -- gank isolated / vision-driven

-- Backwards-compat aliases (older code referenced these names).
M.STRATEGY_AGGRESSIVE = M.STRATEGY_PAPER
M.STRATEGY_DEFENSIVE  = M.STRATEGY_ROCK
M.STRATEGY_SPLIT_FARM = M.STRATEGY_SCISSORS

local strategyCache = nil
-- Longer TTL acts as desire hysteresis: prevents strategy thrashing every
-- few seconds which causes bots to walk-turn-walk-turn between push/defend.
local CACHE_TTL = 8

-- --------------------------------------------------------------------------
-- Helpers
-- --------------------------------------------------------------------------

-- Does our team have a core still missing a "power-spike" item they need
-- before we can reasonably push 5-man? Conservative list on purpose -- only
-- pos 1/2 and only BKB/Scepter (Refresher on a few ults).
local KEY_ITEMS = {
    'item_black_king_bar',
    'item_ultimate_scepter',
    'item_refresher',
}

local function HasAnyItem(hero, names)
    for _, n in ipairs(names) do
        if hero:HasItem(n) or hero:HasModifier('modifier_item_ultimate_scepter_consumed') then
            return true
        end
    end
    return false
end

local function CoreMissingKeyItem()
    local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES)
    for _, a in pairs(allies) do
        if a ~= nil and not a:IsIllusion() and a.GetAssignedLane ~= nil then
            local pos = J.Role and J.Role.GetPosition and J.Role.GetPosition(a) or 0
            if pos == 1 or pos == 2 then
                if not HasAnyItem(a, KEY_ITEMS) and a:GetNetWorth() < 18000 then
                    return true
                end
            end
        end
    end
    return false
end

-- Heuristic for "enemy is split farming": look at last-seen positions of
-- alive enemy heroes. If max pairwise distance is large (enemies are spread
-- across the map), they're split -> favor smoke gank the isolated one.
local function EnemyIsSplit()
    local pids = GetTeamPlayers(GetOpposingTeam())
    local locs = {}
    local now = DotaTime()
    for _, id in ipairs(pids) do
        if IsHeroAlive(id) then
            local info = GetHeroLastSeenInfo(id)
            if info and info[1] and info[1].time_since_seen ~= nil
               and info[1].time_since_seen < 20 then
                table.insert(locs, info[1].location)
            end
        end
    end
    if #locs < 3 then return false end
    local maxD = 0
    for i = 1, #locs - 1 do
        for k = i + 1, #locs do
            local d = GetUnitToLocationDistance and nil -- not valid API for loc/loc
            local dx = locs[i].x - locs[k].x
            local dy = locs[i].y - locs[k].y
            d = math.sqrt(dx * dx + dy * dy)
            if d > maxD then maxD = d end
        end
    end
    -- Map is ~15000 diagonally. 7000+ spread across 3+ enemies = split farm.
    return maxD > 7000
end

-- --------------------------------------------------------------------------
-- Strategy selection
-- --------------------------------------------------------------------------

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

    local team = GetTeam()
    local ourT3Alive, enemyT3Alive = 0, 0
    for _, towerID in ipairs({TOWER_TOP_3, TOWER_MID_3, TOWER_BOT_3}) do
        local t = GetTower(team, towerID)
        if t ~= nil and t:IsAlive() then ourT3Alive = ourT3Alive + 1 end
        local et = GetTower(GetOpposingTeam(), towerID)
        if et ~= nil and et:IsAlive() then enemyT3Alive = enemyT3Alive + 1 end
    end

    -- Score each strategy
    local paperScore    = 0  -- push when ahead
    local rockScore     = 0  -- HG defend
    local scissorsScore = 0  -- gank isolated

    -- Net worth advantage
    if nwAdvantage >= 8000 then
        paperScore = paperScore + 3
    elseif nwAdvantage >= 3000 then
        paperScore = paperScore + 2
    elseif nwAdvantage >= 1000 then
        paperScore = paperScore + 1
    elseif nwAdvantage <= -8000 then
        rockScore = rockScore + 3
    elseif nwAdvantage <= -3000 then
        rockScore = rockScore + 2
    elseif nwAdvantage <= -1000 then
        rockScore = rockScore + 1
    else
        scissorsScore = scissorsScore + 1
    end

    -- Alive hero advantage -> paper (ahead) or rock (behind)
    if aliveAdv >= 2 then
        paperScore = paperScore + 3
    elseif aliveAdv >= 1 then
        paperScore = paperScore + 1
    elseif aliveAdv <= -2 then
        rockScore = rockScore + 3
    elseif aliveAdv <= -1 then
        rockScore = rockScore + 1
    end

    -- Aegis holder -> push
    if hasAegis then paperScore = paperScore + 2 end

    -- Level advantage nudge
    if levelAdv > 2 then
        paperScore = paperScore + 1
    elseif levelAdv < -2 then
        rockScore = rockScore + 1
    end

    -- Tower state: our base threatened -> rock; enemy base exposed -> paper
    if ourT3Alive < 3 then rockScore = rockScore + (3 - ourT3Alive) end
    if enemyT3Alive < 3 then paperScore = paperScore + (3 - enemyT3Alive) end

    -- Vision / split-farm detection -> scissors
    if EnemyIsSplit() then scissorsScore = scissorsScore + 3 end

    -- Turbo bias: end games fast
    if isTurbo then
        paperScore    = paperScore + 2
        rockScore     = rockScore - 1
        scissorsScore = scissorsScore + 1
    end

    -- Late and behind = rock (survive HG); cannot out-farm forever
    if isLate and nwAdvantage < -5000 then
        rockScore = rockScore + 2
    end

    -- Pick winner. Default to scissors (neutral, vision-driven) when tied.
    local strategy = M.STRATEGY_SCISSORS
    local maxScore = scissorsScore
    if paperScore > maxScore then
        strategy = M.STRATEGY_PAPER
        maxScore = paperScore
    end
    if rockScore > maxScore then
        strategy = M.STRATEGY_ROCK
    end

    -- Build multipliers
    local push_mult, defend_mult, farm_mult, roam_mult

    if strategy == M.STRATEGY_PAPER then
        -- Winning: push 5-man, smoke, end the game. Only let farm live if a
        -- core still needs a key item and we're NOT late.
        local needItem = (not isLate) and CoreMissingKeyItem()
        push_mult   = 1.35
        defend_mult = 0.6
        farm_mult   = needItem and 1.0 or 0.45
        roam_mult   = 1.45
    elseif strategy == M.STRATEGY_ROCK then
        -- Losing / base threatened: HG defend, stay grouped, wait for picks.
        push_mult   = 0.55
        defend_mult = 1.4
        farm_mult   = 0.85
        roam_mult   = 0.75
    else -- SCISSORS
        -- Even game, enemy split: smoke gank the isolated side.
        push_mult   = 1.0
        defend_mult = 0.95
        farm_mult   = 0.9
        roam_mult   = 1.3
    end

    strategyCache = {
        lastUpdate   = now,
        strategy     = strategy,
        push_mult    = push_mult,
        defend_mult  = defend_mult,
        farm_mult    = farm_mult,
        roam_mult    = roam_mult,
        nwAdvantage  = nwAdvantage,
        aliveAdv     = aliveAdv,
        enemySplit   = scissorsScore >= 3,
    }

    return strategyCache
end

function M.GetStrategyName(strategy)
    if strategy == M.STRATEGY_PAPER then return "PAPER (push/smoke)"
    elseif strategy == M.STRATEGY_ROCK then return "ROCK (HG defend)"
    else return "SCISSORS (gank split)"
    end
end

return M
