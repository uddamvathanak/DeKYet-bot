-- Draft Style Module
-- Controls team composition drafting bias: "wombo_combo", "snowball", or "auto".
--
-- Pro team inspirations:
--   Wombo Combo  — Tundra Esports (TI11), Team Spirit: structured AoE chain CC,
--                  force big teamfights, win with one coordinated rotation.
--   Snowball     — Xtreme Gaming, Gaimin Gladiators: high early tempo, dominant
--                  lanes, kill the courier, end before the enemy scales.
--   auto         — randomly picks a style each game for variety / practice.
--
-- Parivision style = heavy counter-drafting, already handled by the base
-- counter-pick scoring system (no extra style needed).

local M = {}

-- ============================================================
-- Hero tag tables
-- ============================================================

-- Heroes whose ultimates can lock down 3+ enemies simultaneously
-- (Black Hole, Ravage, Reverse Polarity, Echo Slam, etc.)
-- These are the "wombo" anchors the rest of the team is built around.
M.AOE_LOCKDOWN = {
    npc_dota_hero_enigma         = true,  -- Black Hole
    npc_dota_hero_magnataur      = true,  -- Reverse Polarity
    npc_dota_hero_tidehunter     = true,  -- Ravage
    npc_dota_hero_earthshaker    = true,  -- Echo Slam
    npc_dota_hero_disruptor      = true,  -- Static Storm
    npc_dota_hero_sandking        = true,  -- Epicenter
    npc_dota_hero_faceless_void  = true,  -- Chronosphere
    npc_dota_hero_kunkka         = true,  -- Ghostship
    npc_dota_hero_dark_seer      = true,  -- Wall of Replica
    npc_dota_hero_mars           = true,  -- Arena of Blood
    npc_dota_hero_invoker        = true,  -- Meteor + Sunstrike
    npc_dota_hero_crystal_maiden = true,  -- Freezing Field
    npc_dota_hero_naga_siren     = true,  -- Song of the Siren (setup)
    npc_dota_hero_warlock        = true,  -- Upheaval + Golem
    npc_dota_hero_axe            = true,  -- Berserker's Call grouper
    npc_dota_hero_puck           = true,  -- Dream Coil
    npc_dota_hero_batrider       = true,  -- Flaming Lasso + drag into team
    npc_dota_hero_phoenix        = true,  -- Supernova AoE
    npc_dota_hero_underlord      = true,  -- Firestorm + Atrophy field
}

-- Heroes that amplify or chain off other heroes' combos
-- (Rubick steals the ult, SD sets up RP, Dazzle keeps alive)
M.COMBO_AMPLIFIER = {
    npc_dota_hero_rubick         = true,  -- Steal enemy or ally combo ult
    npc_dota_hero_shadow_demon   = true,  -- Disruption → RP / Ravage setup
    npc_dota_hero_dazzle         = true,  -- Shallow Grave lets core channel freely
    npc_dota_hero_winter_wyvern  = true,  -- Cold Embrace tanks ally inside Chrono
    npc_dota_hero_oracle         = true,  -- False Promise = survive big combos
}

-- High-tempo cores that spike hard before enemies complete their builds
-- Inspired by Xtreme Gaming's mid-pool and Gaimin early aggression
M.SNOWBALL_CORE = {
    npc_dota_hero_void_spirit    = true,
    npc_dota_hero_storm_spirit   = true,
    npc_dota_hero_ember_spirit   = true,
    npc_dota_hero_leshrac        = true,
    npc_dota_hero_death_prophet  = true,
    npc_dota_hero_phantom_assassin = true,
    npc_dota_hero_templar_assassin = true,
    npc_dota_hero_slark          = true,
    npc_dota_hero_ursa           = true,
    npc_dota_hero_juggernaut     = true,
    npc_dota_hero_dragon_knight  = true,
    npc_dota_hero_queenofpain    = true,
    npc_dota_hero_bloodseeker    = true,
    npc_dota_hero_huskar         = true,
    npc_dota_hero_bristleback    = true,
    npc_dota_hero_night_stalker  = true,
    npc_dota_hero_weaver         = true,
    npc_dota_hero_clinkz         = true,
    npc_dota_hero_monkey_king    = true,
    npc_dota_hero_dawnbreaker    = true,
}

-- Supports that create kill opportunities in lane and skirmishes
-- Good snowball enablers: high burst, catch, or lockdown
M.KILL_SUPPORT = {
    npc_dota_hero_lion           = true,
    npc_dota_hero_witch_doctor   = true,
    npc_dota_hero_skywrath_mage  = true,
    npc_dota_hero_pudge          = true,
    npc_dota_hero_bounty_hunter  = true,
    npc_dota_hero_earth_spirit   = true,
    npc_dota_hero_rattletrap     = true,  -- Clockwerk
    npc_dota_hero_spirit_breaker = true,
    npc_dota_hero_ancient_apparition = true,
    npc_dota_hero_jakiro         = true,
    npc_dota_hero_lina           = true,
    npc_dota_hero_vengefulspirit = true,
    npc_dota_hero_silencer       = true,
}

-- Hard carries that scale to 6 slots and win the very late game
-- (penalised in snowball style — too slow to close games early)
M.HARD_CARRY = {
    npc_dota_hero_medusa         = true,
    npc_dota_hero_spectre        = true,
    npc_dota_hero_terrorblade    = true,
    npc_dota_hero_morphling      = true,
    npc_dota_hero_antimage       = true,
    npc_dota_hero_phantom_lancer = true,
    npc_dota_hero_alchemist      = true,
    npc_dota_hero_arc_warden     = true,
}

-- ============================================================
-- Meta hero tier list — patch 7.41 strong heroes
-- Small bonus to heroes that are strong in the current meta.
-- Update this table after each major patch.
-- ============================================================

M.META_HEROES = {
    -- S-tier (strongest in patch, +1.5 bonus)
    S = {
        npc_dota_hero_muerta          = true,  -- high teamfight, spammable
        npc_dota_hero_leshrac         = true,  -- top mid, kills towers
        npc_dota_hero_dark_seer       = true,  -- Wall synergy everywhere
        npc_dota_hero_spirit_breaker  = true,  -- constant pressure
        npc_dota_hero_dawnbreaker     = true,  -- sustain + global
        npc_dota_hero_primal_beast    = true,  -- teamfight initiation
        npc_dota_hero_tidehunter      = true,  -- always relevant
        npc_dota_hero_earthshaker     = true,  -- fissure control
    },
    -- A-tier (consistently strong, +0.75 bonus)
    A = {
        npc_dota_hero_magnataur       = true,
        npc_dota_hero_void_spirit     = true,
        npc_dota_hero_ember_spirit    = true,
        npc_dota_hero_dragon_knight   = true,
        npc_dota_hero_mars            = true,
        npc_dota_hero_lion            = true,
        npc_dota_hero_shadow_demon    = true,
        npc_dota_hero_enigma          = true,
        npc_dota_hero_gyrocopter      = true,
        npc_dota_hero_bane            = true,
        npc_dota_hero_disruptor       = true,
        npc_dota_hero_kunkka          = true,
        npc_dota_hero_medusa          = true,
    },
}

function M.GetMetaBonus(cand)
    if M.META_HEROES.S[cand] then return 1.5 end
    if M.META_HEROES.A[cand] then return 0.75 end
    return 0
end

-- ============================================================
-- Enemy composition detection
-- Reads already-picked enemy heroes and infers their intent.
-- Returns: "late_game", "wombo_combo", "snowball", "push", or "unknown"
-- ============================================================

-- Role-based fallback: classify any hero using HeroRolesMap data.
-- This covers ALL 127 heroes automatically — no manual tagging needed.
-- Explicit tag tables above act as "strong signal" overrides; this fills the gaps.
local function ClassifyHeroByRoles(name, HeroRolesMap)
    local r = HeroRolesMap and HeroRolesMap[name]
    if not r then return nil end

    -- Wombo signal: strong initiator AND disabler (can lock multiple enemies)
    if (r.initiator or 0) >= 2 and (r.disabler or 0) >= 2 then
        return "wombo_combo"
    end

    -- Late-game signal: hard carry with escape (farms to 6 slots)
    if (r.carry or 0) >= 3 and (r.escape or 0) >= 1 then
        return "late_game"
    end
    if (r.carry or 0) >= 2 and (r.durable or 0) >= 1 and (r.nuker or 0) == 0 then
        return "late_game"
    end

    -- Push signal: strong pusher role
    if (r.pusher or 0) >= 2 then
        return "push"
    end

    -- Snowball signal: high nuker or escape-based carry (mobile, kill-threat)
    if (r.nuker or 0) >= 2 and (r.escape or 0) >= 1 then
        return "snowball"
    end
    if (r.carry or 0) >= 2 and (r.escape or 0) >= 2 then
        return "snowball"
    end

    return nil  -- genuinely ambiguous
end

function M.DetectEnemyStyle(enemyNames, HeroRolesMap)
    if #enemyNames == 0 then return "unknown" end

    local scores = { late_game = 0, wombo_combo = 0, snowball = 0, push = 0 }

    for _, name in ipairs(enemyNames) do
        -- Explicit tags: full point (strong signal — these are the archetype heroes)
        if M.HARD_CARRY[name] then
            scores.late_game = scores.late_game + 1
        end
        if M.AOE_LOCKDOWN[name] or M.COMBO_AMPLIFIER[name] then
            scores.wombo_combo = scores.wombo_combo + 1
        end
        if M.SNOWBALL_CORE[name] or M.KILL_SUPPORT[name] then
            scores.snowball = scores.snowball + 1
        end
        if name == "npc_dota_hero_lycan" or name == "npc_dota_hero_furion"
        or name == "npc_dota_hero_broodmother" or name == "npc_dota_hero_shadow_shaman"
        or name == "npc_dota_hero_pugna" or name == "npc_dota_hero_death_prophet" then
            scores.push = scores.push + 1
        end

        -- Role-based fallback: half point (weaker signal — covers untagged heroes)
        local roleClass = ClassifyHeroByRoles(name, HeroRolesMap)
        if roleClass and scores[roleClass] ~= nil then
            scores[roleClass] = scores[roleClass] + 0.5
        end
    end

    -- Need at least 1.5 signal (= one explicit + one role, or three role-based)
    local max = 0
    local winner = "unknown"
    for style, s in pairs(scores) do
        if s > max then max = s; winner = style end
    end

    if max < 1.5 then return "unknown" end
    return winner
end

-- ============================================================
-- Counter-style table
-- Given detected enemy style, what should we draft?
-- Inspired by pro team adaptive drafting (Parivision / Team Liquid approach)
-- ============================================================

-- Enemy style  →  our counter style
--   late_game  →  snowball  (end before they hit 6-slots)
--   wombo_combo → snowball  (poke/pick-off, never group for their combo)
--   snowball   →  wombo_combo (absorb aggression, win the big teamfight)
--   push       →  wombo_combo (teamfight to stop pushes, use AoE to clear waves)
--   unknown    →  use configured / random setting

local COUNTER_STYLE = {
    late_game   = "snowball",
    wombo_combo = "snowball",
    snowball    = "wombo_combo",
    push        = "wombo_combo",
}

-- ============================================================
-- Style selection — chosen once at draft start
-- ============================================================

local STYLES = { "wombo_combo", "snowball" }
local _selectedStyle = nil
local _enemyStyleDetected = nil

-- Call this every pick to update our read on the enemy (they pick over time).
-- HeroRolesMap is optional — when provided, untagged heroes are classified by role.
function M.UpdateEnemyRead(enemyNames, HeroRolesMap)
    if #enemyNames < 2 then return end  -- not enough signal yet
    local detected = M.DetectEnemyStyle(enemyNames, HeroRolesMap)
    if detected ~= "unknown" and detected ~= _enemyStyleDetected then
        _enemyStyleDetected = detected
        -- If we're in auto mode, switch to the counter style
        if _selectedStyle ~= nil then
            local counter = COUNTER_STYLE[detected]
            if counter and counter ~= _selectedStyle then
                print("[DraftStyle] Enemy going " .. detected .. " → switching to " .. counter)
                _selectedStyle = counter
            end
        end
    end
end

function M.GetActiveStyle(customize)
    if _selectedStyle then return _selectedStyle end

    local setting = (customize and customize.DraftStyle) or "auto"
    if setting == "auto" then
        -- Start with a random style; may be overridden by UpdateEnemyRead
        local idx = math.random(1, #STYLES)
        _selectedStyle = STYLES[idx]
        print("[DraftStyle] Auto selected: " .. _selectedStyle)
    else
        _selectedStyle = setting
        print("[DraftStyle] Using configured style: " .. _selectedStyle)
    end
    return _selectedStyle
end

-- Reset each game (called when PickSchedule resets)
function M.Reset()
    _selectedStyle = nil
    _enemyStyleDetected = nil
end

-- ============================================================
-- Scoring bonus applied per candidate hero
-- ============================================================

-- allyNames: already-picked allies (to detect combos stacking)
-- posIndex:  1-5 draft position
-- Returns score delta to add to the candidate's score.
function M.GetStyleBonus(style, cand, allyNames, posIndex)
    local bonus = 0

    if style == "wombo_combo" then
        -- Count how many AoE-lockdown heroes the team already has
        local aoePicked = 0
        for _, ally in ipairs(allyNames) do
            if M.AOE_LOCKDOWN[ally] then aoePicked = aoePicked + 1 end
        end

        if M.AOE_LOCKDOWN[cand] then
            -- First wombo anchor: big bonus. Each additional stacks but diminishes.
            if     aoePicked == 0 then bonus = bonus + 3.5
            elseif aoePicked == 1 then bonus = bonus + 2.5  -- strong 2-hero combo
            elseif aoePicked == 2 then bonus = bonus + 1.0  -- three-way wombo
            end
        end

        if M.COMBO_AMPLIFIER[cand] then
            -- Amplifiers only pay off when at least one anchor exists
            if aoePicked >= 1 then
                bonus = bonus + 2.0
            end
        end

        -- Hard carries hurt wombo (enemy may buy BKB and dodge everything)
        if M.HARD_CARRY[cand] then
            bonus = bonus - 1.5
        end

    elseif style == "snowball" then
        -- Snowball: fast spikes, kill supports, punish before enemies scale
        local isCore = posIndex and posIndex <= 3

        if M.SNOWBALL_CORE[cand] and isCore then
            bonus = bonus + 3.0
        end

        if M.KILL_SUPPORT[cand] and not isCore then
            bonus = bonus + 2.5
        end

        -- Hard carries slow the game down — penalise in snowball
        if M.HARD_CARRY[cand] then
            bonus = bonus - 2.0
        end

        -- AoE-lockdown heroes are neutral in snowball (not wrong, just not ideal)
        -- No explicit penalty — they still score on counter-pick and role gap.
    end

    return bonus
end

-- ============================================================
-- Human-readable label for UI/debug
-- ============================================================

M.STYLE_LABELS = {
    wombo_combo = "Wombo Combo (Tundra/Spirit style)",
    snowball    = "Snowball (XG/Gaimin style)",
    auto        = "Auto",
}

return M
