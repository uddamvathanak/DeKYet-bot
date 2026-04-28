-- DeKYet: team engage boost.
-- When ≥4 allies are grouped and we're not behind, bump existing team_roam
-- target desire so the bot commits to the fight instead of drifting back to
-- farm/lane. Existing target selection and smoke-pickup logic in
-- mode_team_roam_generic stays unchanged; we only nudge the desire scalar.
-- Kill switch: set M.ENABLED = false to make boost return 0.

local M = {}
M.ENABLED = true

local J = require(GetScriptDirectory()..'/FunLib/jmz_func')
local Log = require(GetScriptDirectory()..'/FunLib/dekyet_debug_log')

function M.GetTeamRoamBoost(bot)
    if not M.ENABLED then return 0 end
    if bot == nil or not bot:IsAlive() then return 0 end

    -- Don't override during laning phase.
    if J.IsInLaningPhase() then return 0 end

    -- Need a real group: 4+ allies within 1600 of this bot.
    local nAllies = J.GetAlliesNearLoc(bot:GetLocation(), 1600)
    if nAllies == nil or #nAllies < 4 then return 0 end

    -- Don't engage if we're behind on networth.
    local teamNW, enemyNW = J.GetInventoryNetworth()
    if (teamNW - enemyNW) < 0 then return 0 end

    return 0.10
end

Log.RegisterLayer('team_engage', M.ENABLED)
return M
