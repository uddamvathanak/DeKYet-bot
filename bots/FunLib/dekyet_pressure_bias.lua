-- DeKYet: pressure bias.
-- When the team has tempo (NW lead, allies up, wave on enemy half), discourage
-- non-carry heroes from peeling off to jungle and bias them toward pushing.
-- Read in GetDesire() only. No Think() interaction.
-- Kill switch: set M.ENABLED = false to make all helpers return neutral values.

local M = {}
M.ENABLED = true

local J = require(GetScriptDirectory()..'/FunLib/jmz_func')

-- Returns true if this bot should NOT take farm desire right now because the
-- team would benefit more from wave pressure / grouping. Used as an early
-- guard at the top of mode_farm_generic.GetDesire.
function M.ShouldSuppressFarm(bot)
    if not M.ENABLED then return false end
    if bot == nil or not bot:IsAlive() then return false end

    -- Carries (pos 1) keep farming; this fix targets supports/offlane/mid drift.
    local pos = J.GetPosition(bot)
    if pos == 1 then return false end

    -- Don't override during laning; let ryndrb's laning loop run.
    if J.IsInLaningPhase() then return false end

    -- Need at least 3 allies alive to have anything resembling group pressure.
    if J.GetNumOfAliveHeroes(false) < 3 then return false end

    -- Need a real NW lead. If we're not ahead, farming is fine.
    local teamNW, enemyNW = J.GetInventoryNetworth()
    if (teamNW - enemyNW) < 3000 then return false end

    -- Wave must be on the enemy side of the map for "pressure" to mean anything.
    local lane = bot:GetAssignedLane()
    if lane == nil then return false end
    local vFront = GetLaneFrontLocation(GetTeam(), lane, 0)
    local vTeamFountain = J.GetTeamFountain()
    local vEnemyFountain = J.GetEnemyFountain()
    if vFront == nil or vTeamFountain == nil or vEnemyFountain == nil then return false end
    if J.GetDistance(vFront, vTeamFountain) <= J.GetDistance(vFront, vEnemyFountain) then
        return false
    end

    return true
end

-- Returns a small additive boost (0.0–0.20) for aba_push.GetPushDesire.
-- Applied just before the final clamp/return so existing logic still gates.
function M.GetPushBoost(bot, lane)
    if not M.ENABLED then return 0 end
    if bot == nil or not bot:IsAlive() then return 0 end
    if lane == nil then return 0 end
    if bot:GetLevel() < 7 then return 0 end

    local vFront = GetLaneFrontLocation(GetTeam(), lane, 0)
    local vTeamFountain = J.GetTeamFountain()
    local vEnemyFountain = J.GetEnemyFountain()
    if vFront == nil or vTeamFountain == nil or vEnemyFountain == nil then return 0 end
    if J.GetDistance(vFront, vTeamFountain) <= J.GetDistance(vFront, vEnemyFountain) then
        return 0
    end

    local nAllies = J.GetAlliesNearLoc(vFront, 2500)
    if nAllies == nil or #nAllies < 3 then return 0 end

    if #nAllies >= 4 then return 0.20 end
    return 0.10
end

return M
