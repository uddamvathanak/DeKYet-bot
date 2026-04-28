-- DeKYet: laning aggression / hero spike awareness.
-- Returns a multiplier applied to the per-enemy fMultiplier score inside
-- mode_attack_generic.GetDesire during early game / laning phase only.
-- Lane bullies press harder; passive farmers back off early.
-- Kill switch: set M.ENABLED = false to return 1.0 always (neutral).

local Log = require(GetScriptDirectory()..'/FunLib/dekyet_debug_log')

local M = {}
M.ENABLED = true

-- Heroes that are threatening from level 1 and should always press.
M.LANE_BULLY = {
    npc_dota_hero_viper          = true,
    npc_dota_hero_bristleback    = true,
    npc_dota_hero_huskar         = true,
    npc_dota_hero_undying        = true,
    npc_dota_hero_axe            = true,
    npc_dota_hero_dragon_knight  = true,
    npc_dota_hero_batrider       = true,
    npc_dota_hero_ursa           = true,
    npc_dota_hero_life_stealer   = true,
}

-- Heroes that should play passively and farm early (pre-level 11).
M.PASSIVE_EARLY = {
    npc_dota_hero_medusa         = true,
    npc_dota_hero_spectre        = true,
    npc_dota_hero_antimage       = true,
    npc_dota_hero_naga_siren     = true,
    npc_dota_hero_morphling      = true,
    npc_dota_hero_phantom_assassin = true,
    npc_dota_hero_phantom_lancer = true,
    npc_dota_hero_luna           = true,
    npc_dota_hero_gyrocopter     = true,
}

-- Heroes whose first kill-threat spike is at a specific level (beyond level 1).
-- Key is full hero unit name; value is the level at which they become dangerous.
M.LEVEL_SPIKE = {
    npc_dota_hero_pudge          = 6,
    npc_dota_hero_lion           = 6,
    npc_dota_hero_lina           = 6,
    npc_dota_hero_earthshaker    = 6,
    npc_dota_hero_sand_king      = 6,
    npc_dota_hero_tidehunter     = 6,
    npc_dota_hero_enigma         = 6,
    npc_dota_hero_faceless_void  = 6,
    npc_dota_hero_shadow_shaman  = 6,
    npc_dota_hero_witch_doctor   = 6,
    npc_dota_hero_drow_ranger    = 6,
    npc_dota_hero_templar_assassin = 7,
    npc_dota_hero_invoker        = 7,
    npc_dota_hero_storm_spirit   = 6,
    npc_dota_hero_queenofpain    = 6,
    npc_dota_hero_slark          = 6,
}

-- Returns a multiplier (0.50–1.60) for mode_attack_generic's fMultiplier.
-- Applied only during early game / laning phase via a caller-side guard.
function M.GetAttackMultiplier(botName, botLevel)
    if not M.ENABLED then return 1.0 end

    -- Passive farmers: reduce aggression before their power spike.
    if M.PASSIVE_EARLY[botName] and botLevel < 11 then
        return 0.60
    end

    -- Lane bullies: always more aggressive.
    if M.LANE_BULLY[botName] then
        return 1.25
    end

    -- Heroes at their level spike: press the advantage.
    local spike = M.LEVEL_SPIKE[botName]
    if spike ~= nil and botLevel >= spike then
        return 1.40
    end

    return 1.0
end

Log.RegisterLayer('laning_pressure', M.ENABLED)
return M
