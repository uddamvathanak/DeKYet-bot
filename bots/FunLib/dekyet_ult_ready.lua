-- DeKYet: ultimate readiness boost.
-- Returns an additive desire bonus for mode_team_roam when multiple allied
-- heroes have their ultimates off cooldown — the clearest "we should fight"
-- signal in Dota.
-- Kill switch: set M.ENABLED = false to return 0 always.

local M = {}
M.ENABLED = true

local J = require(GetScriptDirectory()..'/FunLib/jmz_func')

function M.GetUltBoost(bot)
    if not M.ENABLED then return 0 end
    if bot == nil or not bot:IsAlive() then return 0 end
    if J.IsInLaningPhase() then return 0 end

    local readyCount = 0
    for i = 1, 5 do
        local member = GetTeamMember(i)
        if member ~= nil and member:IsAlive() and member:GetLevel() >= 6 then
            local ult = J.GetUltimateAbility(member)
            if ult ~= nil
            and not ult:IsNull()
            and not ult:IsPassive()
            and ult:IsTrained()
            and ult:GetCooldownTimeRemaining() == 0
            then
                readyCount = readyCount + 1
            end
        end
    end

    if readyCount >= 3 then return 0.15 end
    if readyCount >= 2 then return 0.08 end
    return 0
end

return M
