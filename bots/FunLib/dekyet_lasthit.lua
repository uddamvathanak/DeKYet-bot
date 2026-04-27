-- DeKYet: last-hit accuracy nudge.
-- Estimates how much extra damage allied creeps will land on a target during
-- the bot's attack-projectile-delay window, so the laning helper's kill
-- threshold accounts for ally damage that lands in the same swing.
-- Read by mode_laning_generic.GetBestLastHitCreep / GetBestDenyCreep only.
-- Kill switch: set M.ENABLED = false to make GetIncomingAllyDamage return 0
-- (restoring ryndrb's original behavior exactly).

local M = {}
M.ENABLED = true

local J = require(GetScriptDirectory()..'/FunLib/jmz_func')

-- Sum of allied creep auto-attack damage that will land on hTarget within
-- nDelay seconds. Approximates ryndrb's existing creep-damage model used in
-- J.WillKillTarget but on the *ally* side.
function M.GetIncomingAllyDamage(hTarget, nDelay)
    if not M.ENABLED then return 0 end
    if hTarget == nil or nDelay == nil or nDelay <= 0 then return 0 end

    local total = 0
    local nAllyCreeps = GetUnitList(UNIT_LIST_ALLIED_CREEPS)
    if nAllyCreeps == nil then return 0 end

    for _, creep in pairs(nAllyCreeps) do
        if J.IsValid(creep)
        and creep:GetAttackTarget() == hTarget
        and J.IsInRange(creep, hTarget, creep:GetAttackRange() + 100)
        then
            -- One swing's worth of damage if the swing lands in the window.
            -- Conservative: scale by min(1, nDelay * attackSpeed / 1.0).
            local atkSpeed = creep:GetAttackSpeed()
            if atkSpeed == nil or atkSpeed <= 0 then atkSpeed = 1 end
            local swingsInWindow = math.min(1.0, nDelay * atkSpeed)
            total = total + creep:GetAttackDamage() * swingsInWindow
        end
    end

    return total
end

return M
