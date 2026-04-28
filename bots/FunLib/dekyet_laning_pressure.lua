-- DeKYet: per-hero laning aggression multiplier.
-- Read-only side module. Called from GetDesire() in mode_laning_generic.lua.
-- Never touches Think(). Kill-switch: set M.ENABLED = false.

local Log = require(GetScriptDirectory()..'/FunLib/dekyet_debug_log')

local M = {}
M.ENABLED = true
M.DEBUG   = true  -- prints once per hero per game to verify it's wired

-- Bullies: press regardless of spike.
M.LANE_BULLY = {
    npc_dota_hero_bristleback   = true,
    npc_dota_hero_viper         = true,
    npc_dota_hero_huskar        = true,
    npc_dota_hero_undying       = true,
    npc_dota_hero_batrider      = true,
    npc_dota_hero_razor         = true,
    npc_dota_hero_bloodseeker   = true,
    npc_dota_hero_clinkz        = true,
    npc_dota_hero_night_stalker = true,
    npc_dota_hero_pudge         = true,
    npc_dota_hero_lina          = true,
    npc_dota_hero_queenofpain   = true,
    npc_dota_hero_zuus          = true,
    npc_dota_hero_dragon_knight = true,
    npc_dota_hero_centaur       = true,
}

-- Passive carries: farm safe pre-spike.
M.PASSIVE_EARLY = {
    npc_dota_hero_medusa          = true,
    npc_dota_hero_spectre         = true,
    npc_dota_hero_antimage        = true,
    npc_dota_hero_terrorblade     = true,
    npc_dota_hero_phantom_lancer  = true,
    npc_dota_hero_naga_siren      = true,
    npc_dota_hero_morphling       = true,
    npc_dota_hero_alchemist       = true,
    npc_dota_hero_riki            = true,
    npc_dota_hero_faceless_void   = true,
}

-- Level at which each hero becomes a kill threat (default 6).
M.LEVEL_SPIKE = {
    npc_dota_hero_lina             = 6,
    npc_dota_hero_lion             = 6,
    npc_dota_hero_nevermore        = 6,
    npc_dota_hero_legion_commander = 6,
    npc_dota_hero_queenofpain      = 6,
    npc_dota_hero_sniper           = 11,
    npc_dota_hero_medusa           = 11,
    npc_dota_hero_antimage         = 11,
    npc_dota_hero_spectre          = 16,
}

local announced = {}

-- Returns a multiplier in [0.5, 1.6] to apply to the bot's laning desire.
-- 1.0 = no change. >1 = press harder. <1 = farm safer.
function M.GetAggressionMultiplier(botName, level)
    if not M.ENABLED then return 1.0 end

    local mult = 1.0
    local tier = 'NORMAL'

    if M.LANE_BULLY[botName] then
        mult = 1.25
        tier = 'BULLY'
    elseif M.PASSIVE_EARLY[botName] then
        mult = 0.70
        tier = 'PASSIVE'
    end

    local spike = M.LEVEL_SPIKE[botName] or 6
    if level and level >= spike then
        mult = mult * 1.10
        tier = tier..'+SPIKE'
    end

    if mult < 0.5 then mult = 0.5 end
    if mult > 1.6 then mult = 1.6 end

    if M.DEBUG and not announced[botName] and level and level >= 1 then
        announced[botName] = true
        local _rawPrint = _G.__DEKYET_RAWPRINT or _G.__DEKYET_RAW_PRINT or print
        _rawPrint(string.format(
            '[DeKYet] laning_pressure %s tier=%s mult=%.2f (lvl=%d, spike=%d)',
            botName, tier, mult, level, spike))
    end

    return mult
end

Log.RegisterLayer('laning_pressure', M.ENABLED)
return M
