-- Laning Pressure and Power Spike Module
-- Provides: per-hero level spike awareness, matchup-based lane aggression multipliers,
-- and camp stacking helpers for supports.
--
-- Used by:
--   mode_laning_generic.lua  — desire boost + general Think harassment
--   mode_roam_generic.lua    — support camp stacking during laning phase

local M = {}

local J = require(GetScriptDirectory()..'/FunLib/jmz_func')

-- Ranged units in Dota 2 bot API are detected via attack range; there is no
-- GetAttackCapability() method. 300 is the standard cutoff used elsewhere in
-- this codebase (see jmz_func.lua usages).
local RANGED_CUTOFF = 300

-- Lazy-load aba_matchups to avoid circular require issues at file load time
local _Matchups = nil
local function GetMatchups()
    if not _Matchups then
        _Matchups = require(GetScriptDirectory()..'/FunLib/aba_matchups')
    end
    return _Matchups
end

-- ============================================================
-- Power spike levels: hero → the level when they become a real kill threat.
-- At or above this level the bot should press the lane; below it, play safer.
-- ============================================================
M.LEVEL_SPIKE = {
    -- Level 6 ultimates that enable kills or aggressive roaming
    npc_dota_hero_ursa              = 6,  -- Enrage — unkillable duelist
    npc_dota_hero_slark             = 6,  -- Depth Shroud + Pounce burst
    npc_dota_hero_axe               = 6,  -- Culling Blade finisher
    npc_dota_hero_juggernaut        = 6,  -- Omnislash + Healing Ward
    npc_dota_hero_phantom_assassin  = 6,  -- Coup de Grace crits spike
    npc_dota_hero_bloodseeker       = 6,  -- Rupture — global map pressure
    npc_dota_hero_night_stalker     = 6,  -- Darkness + massive stat gain
    npc_dota_hero_spirit_breaker    = 6,  -- Nether Strike finisher
    npc_dota_hero_huskar            = 6,  -- Life Break kamikaze engage
    npc_dota_hero_dragon_knight     = 6,  -- Elder Dragon Form tankiness
    npc_dota_hero_batrider          = 6,  -- Flaming Lasso catch
    npc_dota_hero_lion              = 6,  -- Finger of Death one-shot
    npc_dota_hero_lina              = 6,  -- Laguna Blade nuke
    npc_dota_hero_skywrath_mage     = 6,  -- Mystic Flare burst
    npc_dota_hero_ancient_apparition= 6,  -- Ice Blast (no heal) pressure
    npc_dota_hero_witch_doctor      = 6,  -- Death Ward + Maledict combo
    npc_dota_hero_storm_spirit      = 6,  -- Ball Lightning roaming
    npc_dota_hero_void_spirit       = 6,  -- Astral Step blink mobility
    npc_dota_hero_ember_spirit      = 6,  -- Fire Remnant map presence
    npc_dota_hero_templar_assassin  = 6,  -- Psionic Trap zone control
    npc_dota_hero_puck              = 6,  -- Dream Coil teamfight lockdown
    npc_dota_hero_queenofpain       = 6,  -- Sonic Wave + Blink assassination
    npc_dota_hero_doom_bringer      = 6,  -- Doom silence on key target
    npc_dota_hero_bane              = 6,  -- Fiend's Grip kill channel
    npc_dota_hero_shadow_demon      = 6,  -- Demonic Purge slow
    npc_dota_hero_disruptor         = 6,  -- Static Storm lockdown
    npc_dota_hero_earthshaker       = 6,  -- Echo Slam teamfight
    npc_dota_hero_magnataur         = 6,  -- Reverse Polarity initiation
    npc_dota_hero_enigma            = 6,  -- Black Hole game-winning ult
    npc_dota_hero_tidehunter        = 6,  -- Ravage AoE stun (also strong at 3)
    npc_dota_hero_faceless_void     = 6,  -- Chronosphere lockdown
    npc_dota_hero_naga_siren        = 6,  -- Song of the Siren setup
    npc_dota_hero_dark_seer         = 6,  -- Wall of Replica teamfight
    npc_dota_hero_mars              = 6,  -- Arena of Blood zone control
    npc_dota_hero_warlock           = 6,  -- Upheaval + Golem
    npc_dota_hero_dawnbreaker       = 6,  -- Solar Guardian global assist
    -- Level 3: main damage/utility ability peaks at level 3
    npc_dota_hero_bristleback       = 3,  -- Quill Spray + tankiness
    npc_dota_hero_viper             = 3,  -- Nethertoxin + Corrosive Skin
    npc_dota_hero_venomancer        = 3,  -- Poison Sting max slow
    -- Level 2: level-1 + level-2 ability combo is already deadly
    npc_dota_hero_lion              = 2,  -- Earth Spike + Hex stun chain
}

-- Heroes that bully the lane early regardless of spike level
M.LANE_BULLY = {
    npc_dota_hero_bristleback   = true,
    npc_dota_hero_viper         = true,
    npc_dota_hero_tidehunter    = true,
    npc_dota_hero_venomancer    = true,
    npc_dota_hero_dragon_knight = true,
    npc_dota_hero_huskar        = true,
    npc_dota_hero_skywrath_mage = true,
    npc_dota_hero_ursa          = true,
    npc_dota_hero_undying       = true,
    npc_dota_hero_kunkka        = true,
    npc_dota_hero_weaver        = true,
    npc_dota_hero_razor         = true,
}

-- Heroes that must farm quietly; penalise aggression until key items arrive
M.PASSIVE_EARLY = {
    npc_dota_hero_medusa         = true,
    npc_dota_hero_spectre        = true,
    npc_dota_hero_antimage       = true,
    npc_dota_hero_phantom_lancer = true,
    npc_dota_hero_terrorblade    = true,
    npc_dota_hero_alchemist      = true,
    npc_dota_hero_arc_warden     = true,
    npc_dota_hero_invoker        = true,
    npc_dota_hero_tinker         = true,
    npc_dota_hero_naga_siren     = true,
    npc_dota_hero_lone_druid     = true,
}

-- ============================================================
-- Matchup advantage check using aba_matchups counter lists.
-- Returns: positive = we counter them, negative = they counter us.
-- ============================================================
function M.GetLaneMatchupScore(botName, enemyNames)
    local Matchups = GetMatchups()
    local score = 0
    for _, ename in ipairs(enemyNames) do
        if Matchups.IsCounter(botName, ename) then score = score + 1 end
        if Matchups.IsCounter(ename, botName) then score = score - 1 end
    end
    return score
end

-- ============================================================
-- Aggression multiplier for lane harassment decisions.
-- Returns: 1.0 = neutral | >1.0 = press | <1.0 = play safe
-- ============================================================
function M.GetAggressionMultiplier(botName, enemyNames, botLevel)
    -- Passive farmers always play safe in laning phase
    if M.PASSIVE_EARLY[botName] then return 0.65 end

    local mult = 1.0

    -- Level spike: big aggression boost at or past spike level
    local spike = M.LEVEL_SPIKE[botName]
    if spike then
        if botLevel >= spike then
            mult = mult + 0.35   -- at spike → press hard
        elseif botLevel < spike - 1 then
            mult = mult - 0.15   -- pre-spike → be cautious
        end
    end

    -- Natural lane bullies get a flat bonus
    if M.LANE_BULLY[botName] then mult = mult + 0.15 end

    -- Each counter match in lane = ±15%
    local matchScore = M.GetLaneMatchupScore(botName, enemyNames)
    mult = mult + matchScore * 0.15

    -- Turbo: slightly faster pacing; heroes hit spike timing sooner
    if GetGameMode() == 23 then mult = mult + 0.1 end

    return math.max(0.5, math.min(1.6, mult))
end

-- ============================================================
-- Range vs Melee matchup advantage
-- Returns a negative adjustment to the harass threshold when our hero is
-- ranged and ALL visible nearby enemy heroes are melee.  A lower threshold
-- means the bot harasses more freely.
-- ============================================================
function M.GetRangeMatchupAdjust(bot, enemyList)
    if not bot or bot:GetAttackRange() <= RANGED_CUTOFF then
        return 0
    end
    if not enemyList or #enemyList == 0 then return 0 end
    for _, enemy in ipairs(enemyList) do
        if J.IsValidHero(enemy) then
            if enemy:GetAttackRange() > RANGED_CUTOFF then
                return 0  -- at least one ranged enemy present — no free-trading
            end
        end
    end
    -- Every visible enemy is melee: ranged hero can trade freely
    return -0.5
end

-- ============================================================
-- Camp stacking timing helpers
-- ============================================================

-- Returns true during the window (:52–:57 real seconds of each minute)
-- when bots should move to a neutral camp to stack it.
function M.IsStackingWindow()
    local t = DotaTime()
    local minTime = (GetGameMode() == 23) and 90 or 150  -- earlier in turbo
    if t < minTime then return false end
    local sec = t % 60
    return sec >= 52 and sec <= 57
end

-- Should a support hero go stack instead of standing in lane?
-- hasAllyCore: true when a core ally is present in the lane
function M.ShouldSupportStack(bot, hasAllyCore, myHp)
    if not hasAllyCore then return false end
    if (myHp or 1.0) < 0.55 then return false end
    local pos = J.GetPosition(bot)
    if pos < 4 then return false end   -- only pos 4-5 supports stack
    return M.IsStackingWindow()
end

-- Returns the nearest allied neutral camp center suitable for stacking
-- (medium or large preferred; skips ancients and enemy camps).
function M.GetNearestAllyCamp(bot)
    local ok, camps = pcall(GetNeutralSpawners)
    if not ok or not camps then return nil end
    local bestScore = 3500  -- effective distance cap
    local bestLoc   = nil
    for _, camp in pairs(camps) do
        if camp.team == GetTeam() and camp.type ~= "ancient" then
            local loc  = Vector(camp.location.x, camp.location.y, camp.location.z)
            local dist = GetUnitToLocationDistance(bot, loc)
            -- Penalise small camps: prefer medium/large by adding virtual distance
            local penalty = (camp.type == "small") and 500 or 0
            local eff = dist + penalty
            if eff < bestScore then
                bestScore = eff
                bestLoc   = loc
            end
        end
    end
    return bestLoc
end

return M
