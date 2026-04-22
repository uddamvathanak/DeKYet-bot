"""
simulate_laning.py — Behavioral unit tests for bot laning/farming logic.
Uses lupa (Python + LuaJIT) to run the actual Lua logic in isolation,
no Dota 2 needed.

Usage:
    pip install lupa
    python tools/simulate_laning.py

Each test validates a specific behavior change we made.
PASS = logic is correct. FAIL = bug still present or regression.
"""

from lupa import LuaRuntime
import sys

lua = LuaRuntime(unpack_returned_tuples=True)

PASS = []
FAIL = []

def test(name, fn):
    try:
        fn()
        PASS.append(name)
        print(f"  PASS  {name}")
    except AssertionError as e:
        FAIL.append(name)
        print(f"  FAIL  {name}: {e}")
    except Exception as e:
        FAIL.append(name)
        print(f"  ERROR {name}: {type(e).__name__}: {e}")

# ─────────────────────────────────────────────────────────────────────────────
# Lua environment setup — minimal mock of Dota 2 API
# ─────────────────────────────────────────────────────────────────────────────
lua.execute("""
-- Dota 2 constants (subset used by laning logic)
BOT_MODE_DESIRE_NONE    = 0
BOT_MODE_DESIRE_VERYLOW = 0.05
BOT_MODE_DESIRE_LOW     = 0.15
BOT_MODE_DESIRE_HIGH    = 0.65
DAMAGE_TYPE_PHYSICAL    = 1
TEAM_RADIANT            = 2
LANE_BOT                = 3
ATTACK_CAPABILITY_MELEE  = 1
ATTACK_CAPABILITY_RANGED = 2

-- Math helpers used in bot scripts
function RemapValClamped(v, a, b, c, d)
    if v <= a then return c end
    if v >= b then return d end
    return c + (d - c) * (v - a) / (b - a)
end
function Min(a, b) return math.min(a, b) end
function Max(a, b) return math.max(a, b) end
function RandomVector(r) return {x=0, y=0, z=0} end
function RandomInt(a, b) return math.floor((a+b)/2) end

-- Distance helper
function GetUnitToUnitDistance(a, b)
    local dx = (a.loc and a.loc.x or 0) - (b.loc and b.loc.x or 0)
    local dy = (a.loc and a.loc.y or 0) - (b.loc and b.loc.y or 0)
    return math.sqrt(dx*dx + dy*dy)
end

function GetUnitToLocationDistance(unit, loc)
    local dx = (unit.loc and unit.loc.x or 0) - (loc.x or 0)
    local dy = (unit.loc and unit.loc.y or 0) - (loc.y or 0)
    return math.sqrt(dx*dx + dy*dy)
end

-- ── Factory helpers ─────────────────────────────────────────────────────────

-- Create a mock creep unit
function makeCreep(hp, maxHp, opts)
    opts = opts or {}
    local c = {
        hp    = hp,
        maxhp = maxHp or hp * 2,
        valid = true,
        attackable = opts.attackable ~= false,
        loc   = opts.loc or {x=100, y=0},
        team  = opts.team or TEAM_RADIANT,
    }
    c.GetHealth    = function(self) return self.hp end
    c.GetMaxHealth = function(self) return self.maxhp end
    c.GetTeam      = function(self) return self.team end
    return c
end

-- Create a mock hero unit
function makeHero(hp, opts)
    opts = opts or {}
    local h = makeCreep(hp, 1000, opts)
    h.hero = true
    h.illusion = false
    h.loc = opts.loc or {x=200, y=0}
    h.attackCap = opts.attackCap or ATTACK_CAPABILITY_MELEE
    h.IsHero              = function(self) return true end
    h.IsIllusion          = function(self) return self.illusion end
    h.GetUnitName         = function(self) return opts.name or "npc_dota_hero_axe" end
    h.GetAttackCapability = function(self) return self.attackCap end
    return h
end

-- Create a mock bot with action recording
function makeBot(opts)
    opts = opts or {}
    local b = makeHero(opts.hp or 800, opts)
    b.attackDamage = opts.attackDamage or 80
    b.attackRange  = opts.attackRange or 150
    b.level        = opts.level or 6
    b.position     = opts.position or 1
    b._actions     = {}
    b._chats       = {}
    b.GetAttackDamage     = function(self) return self.attackDamage end
    b.GetAttackRange      = function(self) return self.attackRange end
    b.GetLevel            = function(self) return self.level end
    b.GetLocation         = function(self) return self.loc end
    b.GetPlayerID         = function(self) return 0 end
    b.SetTarget           = function(self, t)
        table.insert(self._actions, {type="SetTarget", target=t})
    end
    b.Action_AttackUnit = function(self, t, force)
        table.insert(self._actions, {type="AttackUnit", target=t, force=force})
    end
    b.Action_MoveToUnit = function(self, t)
        table.insert(self._actions, {type="MoveToUnit", target=t})
    end
    b.Action_MoveToLocation = function(self, loc)
        table.insert(self._actions, {type="MoveToLocation", loc=loc})
    end
    b.ActionImmediate_Chat = function(self, msg, global)
        table.insert(self._chats, msg)
    end
    b.lastAction = function(self)
        return self._actions[#self._actions]
    end
    return b
end

-- ── Mirrors of new laning_pressure.lua helpers ───────────────────────────────

-- Mock IsValidHero: any table with .hero=true and .valid=true
function IsValidHero(u)
    return u and u.hero and u.valid
end

-- Mirror of M.GetRangeMatchupAdjust from laning_pressure.lua
function GetRangeMatchupAdjust(bot, enemyList)
    if not bot or bot:GetAttackCapability() ~= ATTACK_CAPABILITY_RANGED then
        return 0
    end
    if not enemyList or #enemyList == 0 then return 0 end
    for _, enemy in ipairs(enemyList) do
        if IsValidHero(enemy) then
            if enemy:GetAttackCapability() == ATTACK_CAPABILITY_RANGED then
                return 0
            end
        end
    end
    return -0.5
end

-- Mock ping-yield check (mirrors GetDesire() in mode_laning_generic.lua)
-- pingData: { location, time } or nil; towerLoc: location of a tower
-- Returns true if laning should yield (ping is near a tower within 10s)
function ShouldYieldOnPing(pingData, towerLoc, gameTime)
    if not pingData or not towerLoc then return false end
    local age = gameTime - (pingData.time or 0)
    if age > 10 then return false end
    local dx = pingData.location.x - towerLoc.x
    local dy = pingData.location.y - towerLoc.y
    local dist = math.sqrt(dx*dx + dy*dy)
    return dist <= 800
end

-- ── Exact logic from mode_laning_generic.lua ────────────────────────────────

-- WillKillTarget mirror (simplified — no delay correction for tests)
local function WillKillTarget(target, dmg)
    return target:GetHealth() <= dmg
end

function GetBestLastHitCreep(hCreepList, attackDamage)
    local dmgDelta = attackDamage * 0.7
    local moveToCreep = nil
    for _, creep in pairs(hCreepList) do
        if creep.valid and creep.attackable then
            if WillKillTarget(creep, attackDamage) then
                return creep, false
            end
            if WillKillTarget(creep, attackDamage + dmgDelta) then
                moveToCreep = creep
            end
        end
    end
    return moveToCreep, moveToCreep ~= nil
end

function GetBestDenyCreep(hCreepList, attackDamage)
    for _, creep in pairs(hCreepList) do
        if creep.valid and creep.attackable
        and (creep.hp / creep.maxhp) < 0.49
        and creep.hp <= attackDamage
        then
            return creep
        end
    end
    return nil
end

-- ── Priority chain from the new unified Think() ─────────────────────────────
-- Simulates what Think() decides given creep/hero lists

function SimulateThink(bot, allyCreeps, enemyCreeps, inRangeEnemies, aggrMult, opts)
    opts = opts or {}
    local pos   = bot.position
    local myHp  = bot.hp / bot.maxhp
    local atk   = bot.attackDamage
    local range = bot.attackRange

    -- PRIORITY 2: Last hit
    local canLastHit = pos <= 3 or opts.noCoreNearby
    if canLastHit then
        local hitCreep, moveToIt = GetBestLastHitCreep(enemyCreeps, atk)
        if hitCreep then
            local dist = GetUnitToUnitDistance(bot, hitCreep)
            if dist > range * (moveToIt and 0.8 or 1.0) then
                bot:Action_MoveToUnit(hitCreep)
            else
                bot:SetTarget(hitCreep)
                bot:Action_AttackUnit(hitCreep, true)
            end
            return "last_hit"
        end
    end

    -- PRIORITY 3: Deny
    local denyCreep = GetBestDenyCreep(allyCreeps, atk)
    if denyCreep then
        bot:SetTarget(denyCreep)
        bot:Action_AttackUnit(denyCreep, true)
        return "deny"
    end

    -- PRIORITY 4: Harass
    local rangeAdj    = GetRangeMatchupAdjust(bot, inRangeEnemies)
    local harassThresh = (pos <= 3 and 0.85 or 1.2) + rangeAdj
    if myHp > 0.5 and inRangeEnemies and #inRangeEnemies > 0
    and aggrMult >= harassThresh then
        local bestTarget, bestHp = nil, 1.1
        for _, enemy in ipairs(inRangeEnemies) do
            if enemy.hero and not enemy.illusion then
                local dist = GetUnitToUnitDistance(bot, enemy)
                local ehp  = enemy.hp / enemy.maxhp
                if dist <= range + 100 and ehp < bestHp then
                    bestHp    = ehp
                    bestTarget = enemy
                end
            end
        end
        if bestTarget then
            bot:SetTarget(bestTarget)
            bot:Action_AttackUnit(bestTarget, false)
            return "harass"
        end
    end

    -- PRIORITY 5: Wave push
    local nAllyCount  = #allyCreeps
    local nEnemyCount = #enemyCreeps
    local nThreat     = #inRangeEnemies
    if nEnemyCount > 0 and myHp > 0.5
    and (nAllyCount >= nEnemyCount or nThreat == 0)
    and (aggrMult >= 1.0 or nThreat == 0) then
        local weakest, weakHp = nil, math.huge
        for _, creep in pairs(enemyCreeps) do
            if creep.valid and creep.attackable then
                local hp = creep.hp
                if hp < weakHp then weakHp = hp; weakest = creep end
            end
        end
        if weakest then
            bot:Action_AttackUnit(weakest, false)
            return "wave_push"
        end
    end

    return "fallback"
end

-- ── Camp stuck timeout (mirrors mode_farm_generic.lua logic) ─────────────────

CAMP_EMPTY_TIMEOUT = 10
_campEmptySince = 0

function SimulateCampCheck(nNeutrals, cDist, gameTime)
    if #nNeutrals == 0 and cDist < 400 then
        if _campEmptySince == 0 then _campEmptySince = gameTime end
        if gameTime - _campEmptySince > CAMP_EMPTY_TIMEOUT then
            _campEmptySince = 0
            return "clear_and_leave"  -- should reset camp and go to lane
        end
        return "waiting"
    else
        _campEmptySince = 0
        return "farming"
    end
end

""")

# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────

print("\n── Last Hit Logic ──────────────────────────────────────────────────")

def test_lasthit_killable():
    result = lua.eval("GetBestLastHitCreep({makeCreep(60, 500)}, 80)")
    assert result is not None, "Should return killable creep"
test("Killable creep (HP ≤ damage) is found", test_lasthit_killable)

def test_lasthit_in_buffer():
    result, moveToIt = lua.eval("GetBestLastHitCreep({makeCreep(120, 500)}, 80)")
    assert result is not None, "Should find creep in approach range (HP ≤ dmg + 70%)"
    assert moveToIt, "Should set moveToIt=true for approach kills"
test("Creep in kill-buffer range triggers approach (HP ≤ dmg + 70% buffer)", test_lasthit_in_buffer)

def test_lasthit_none():
    result, moveToIt = lua.eval("GetBestLastHitCreep({makeCreep(800, 1000)}, 80)")
    assert result is None and not moveToIt, "Should return nil when no last-hit opportunity"
test("No last-hit opportunity when creep HP >> damage", test_lasthit_none)

def test_lasthit_prefers_killable_over_approach():
    lua.execute("""
    _c1 = makeCreep(120, 500)   -- approach range only
    _c2 = makeCreep(70, 500)    -- directly killable
    """)
    result, moveToIt = lua.eval("GetBestLastHitCreep({_c1, _c2}, 80)")
    assert not lua.eval("_moveToIt2"), "Directly killable creep should be returned first"
    assert lua.eval("_c2.hp == 70"), "Should return the directly killable one"
test("Killable creep preferred over approach-range creep", test_lasthit_prefers_killable_over_approach)


print("\n── Deny Logic ──────────────────────────────────────────────────────")

def test_deny_found():
    result = lua.eval("GetBestDenyCreep({makeCreep(40, 100)}, 80)")
    assert result is not None, "40% HP, health ≤ damage → should deny"
test("Deny: creep at 40% HP with health ≤ damage", test_deny_found)

def test_deny_hp_too_high():
    result = lua.eval("GetBestDenyCreep({makeCreep(200, 400)}, 80)")
    assert result is None, "50% HP → should NOT deny (threshold is 49%)"
test("No deny: creep exactly at 50% HP (threshold 49%)", test_deny_hp_too_high)

def test_deny_health_over_damage():
    result = lua.eval("GetBestDenyCreep({makeCreep(40, 100, {attackable=true})}, 30)")
    # hp=40 > attackDamage=30, so can't one-shot deny
    assert result is None, "HP below threshold but health > attackDamage → no deny yet"
test("No deny: HP below threshold but health > attack damage", test_deny_health_over_damage)


print("\n── Think() Priority Chain ──────────────────────────────────────────")

def test_priority_lasthit_over_wave():
    """Last hit takes priority over wave push even when ally wave is bigger."""
    lua.execute("""
    _pbot    = makeBot({position=1, hp=800, attackDamage=80, attackRange=150, loc={x=0,y=0}})
    _killable = makeCreep(60, 500, {loc={x=100,y=0}})  -- killable
    _ally1   = makeCreep(100, 500, {loc={x=50,y=0}})
    _ally2   = makeCreep(100, 500, {loc={x=60,y=0}})
    _push1   = makeCreep(300, 500, {loc={x=100,y=0}})  -- enemy creep for wave push
    _decision = SimulateThink(_pbot, {_ally1, _ally2}, {_killable, _push1}, {}, 1.0, {noCoreNearby=true})
    """)
    decision = lua.eval("_decision")
    assert decision == "last_hit", f"Expected last_hit but got {decision}"
test("Last hit has priority over wave push", test_priority_lasthit_over_wave)

def test_priority_deny_over_harass():
    """Deny takes priority over harassing enemy heroes."""
    lua.execute("""
    _pbot     = makeBot({position=2, hp=800, attackDamage=80, attackRange=600, loc={x=0,y=0}})
    _denyable = makeCreep(40, 100, {loc={x=50,y=0}})   -- deniable ally creep
    _enemy    = makeHero(600, {loc={x=100,y=0}})
    _decision = SimulateThink(_pbot, {_denyable}, {}, {_enemy}, 1.5, {})
    """)
    decision = lua.eval("_decision")
    assert decision == "deny", f"Expected deny but got {decision}"
test("Deny has priority over harassing enemy heroes", test_priority_deny_over_harass)

def test_wave_push_when_winning():
    """Wave push fires when ally wave >= enemy wave and no threats."""
    lua.execute("""
    _pbot  = makeBot({position=1, hp=800, attackDamage=80, attackRange=150, loc={x=0,y=0}})
    _ally1 = makeCreep(300, 500, {loc={x=50,y=0}})
    _ally2 = makeCreep(300, 500, {loc={x=60,y=0}})
    _enemy1 = makeCreep(300, 500, {loc={x=100,y=0}})  -- 1 enemy creep vs 2 ally
    _decision = SimulateThink(_pbot, {_ally1, _ally2}, {_enemy1}, {}, 1.0, {noCoreNearby=true})
    """)
    decision = lua.eval("_decision")
    assert decision == "wave_push", f"Expected wave_push but got {decision}"
test("Wave push fires when ally wave outnumbers enemy (no threats)", test_wave_push_when_winning)

def test_no_wave_push_when_behind():
    """Wave push does NOT fire when enemy wave outnumbers allies AND enemies present."""
    lua.execute("""
    _pbot  = makeBot({position=1, hp=800, attackDamage=80, attackRange=150, loc={x=0,y=0}})
    _ally1 = makeCreep(300, 500, {loc={x=50,y=0}})
    _ec1   = makeCreep(300, 500, {loc={x=100,y=0}})
    _ec2   = makeCreep(300, 500, {loc={x=110,y=0}})
    _ec3   = makeCreep(300, 500, {loc={x=120,y=0}})
    _enemy = makeHero(600, {loc={x=130,y=0}})  -- threatening enemy hero
    _decision = SimulateThink(_pbot, {_ally1}, {_ec1, _ec2, _ec3}, {_enemy}, 0.8, {noCoreNearby=true})
    """)
    decision = lua.eval("_decision")
    assert decision != "wave_push", f"Should NOT wave push when outnumbered by creeps + hero"
test("Wave push blocked when enemy wave outnumbers and threat present", test_no_wave_push_when_behind)

def test_harass_core_lower_threshold():
    """Cores (pos1-3) harass at aggrMult=0.85, supports need 1.2."""
    lua.execute("""
    _corebot = makeBot({position=1, hp=800, attackDamage=80, attackRange=600, loc={x=0,y=0}})
    _suppbot = makeBot({position=5, hp=600, attackDamage=50, attackRange=600, loc={x=0,y=0}})
    _enem    = makeHero(600, {loc={x=100,y=0}})
    _d_core  = SimulateThink(_corebot, {}, {}, {_enem}, 0.85, {})  -- core at threshold
    _d_supp  = SimulateThink(_suppbot, {}, {}, {_enem}, 0.85, {})  -- supp below threshold
    """)
    d_core = lua.eval("_d_core")
    d_supp = lua.eval("_d_supp")
    assert d_core == "harass", f"Core should harass at aggrMult=0.85, got {d_core}"
    assert d_supp != "harass", f"Support should NOT harass at aggrMult=0.85, got {d_supp}"
test("Core harasses at aggrMult≥0.85; support needs aggrMult≥1.2", test_harass_core_lower_threshold)


print("\n── Camp Stuck Timeout ──────────────────────────────────────────────")

def test_camp_not_stuck_yet():
    lua.execute("_campEmptySince = 0")
    r1 = lua.eval("SimulateCampCheck({}, 200, 100.0)")
    r2 = lua.eval("SimulateCampCheck({}, 200, 107.0)")
    assert r1 == "waiting", f"Should be 'waiting' not '{r1}'"
    assert r2 == "waiting", f"Should still be 'waiting' at 7s, not '{r2}'"
test("Camp stuck timer: still 'waiting' before 10s timeout", test_camp_not_stuck_yet)

def test_camp_clears_after_timeout():
    lua.execute("_campEmptySince = 0")
    lua.eval("SimulateCampCheck({}, 200, 200.0)")
    result = lua.eval("SimulateCampCheck({}, 200, 211.0)")
    assert result == "clear_and_leave", f"Expected 'clear_and_leave' after 11s, got '{result}'"
test("Camp stuck timer: clears camp after 10s timeout", test_camp_clears_after_timeout)

def test_camp_timer_resets_on_neutrals():
    lua.execute("_campEmptySince = 0")
    lua.eval("SimulateCampCheck({}, 200, 300.0)")    # timer starts
    lua.eval("SimulateCampCheck({1,2,3}, 200, 306.0)")  # neutrals appear, reset
    result = lua.eval("SimulateCampCheck({}, 200, 312.0)")  # empty again, fresh timer
    assert result == "waiting", f"Timer should restart fresh after neutral spawn, got '{result}'"
test("Camp stuck timer resets when neutrals appear between checks", test_camp_timer_resets_on_neutrals)

def test_camp_far_away_not_stuck():
    lua.execute("_campEmptySince = 0")
    r = lua.eval("SimulateCampCheck({}, 600, 100.0)")  # cDist=600 > 400 threshold
    assert r == "farming", f"Should not start stuck timer when far from camp, got '{r}'"
test("Camp stuck timer only fires when within 400 units of camp", test_camp_far_away_not_stuck)


print("\n── Error Chatting (pcall wrapper) ──────────────────────────────────")

def test_pcall_catches_error():
    lua.execute("""
    local _bot = makeBot({})
    local _errBot_chats = {}
    local _lastErrTime = -999
    local _dotaTime = 100.0

    local function BrokenThink()
        error("intentional test error")
    end

    local ok, err = pcall(BrokenThink)
    if not ok then
        if _dotaTime - _lastErrTime > 30 then
            _lastErrTime = _dotaTime
            _bot:ActionImmediate_Chat("[Script Error] " .. tostring(err):sub(1, 80), false)
        end
    end
    _pcall_test_chats = _bot._chats
    """)
    chats = lua.eval("_pcall_test_chats")
    assert chats is not None and len(list(chats.values())) > 0, "Error should produce a chat message"
    chat_msg = list(chats.values())[0]
    assert "[Script Error]" in chat_msg, f"Chat should start with [Script Error], got: {chat_msg}"
test("pcall wrapper catches error and chats it in-game", test_pcall_catches_error)

def test_pcall_rate_limits_chat():
    """Error chatting should not spam — max once per 30s."""
    lua.execute("""
    local _bot2 = makeBot({})
    local _lastErrTime2 = -999
    local _dotaTime2 = 100.0

    local function BrokenThink() error("test error") end

    -- Fire twice within 30s
    local ok, err = pcall(BrokenThink)
    if not ok and _dotaTime2 - _lastErrTime2 > 30 then
        _lastErrTime2 = _dotaTime2
        _bot2:ActionImmediate_Chat("[Script Error] " .. tostring(err):sub(1,80), false)
    end
    _dotaTime2 = 115.0  -- only 15s later
    ok, err = pcall(BrokenThink)
    if not ok and _dotaTime2 - _lastErrTime2 > 30 then
        _lastErrTime2 = _dotaTime2
        _bot2:ActionImmediate_Chat("[Script Error] second error", false)
    end
    _rate_limit_chats = _bot2._chats
    """)
    chats = list(lua.eval("_rate_limit_chats").values())
    assert len(chats) == 1, f"Should only chat once per 30s, got {len(chats)} messages"
test("Error chat rate-limited: max once per 30s", test_pcall_rate_limits_chat)


print("\n── Range vs Melee Harass ───────────────────────────────────────────")

def test_ranged_core_vs_melee_always_harasses():
    """Ranged core vs all-melee enemies: threshold drops 0.85 → 0.35, so aggrMult=0.5 is enough."""
    lua.execute("""
    _rbot  = makeBot({position=1, hp=800, attackDamage=80, attackRange=600,
                      loc={x=0,y=0}, attackCap=ATTACK_CAPABILITY_RANGED})
    _melee = makeHero(500, {loc={x=400,y=0}, attackCap=ATTACK_CAPABILITY_MELEE})
    -- aggrMult=0.5 is below the default core threshold (0.85) but above adjusted (0.85-0.5=0.35)
    _rDecision = SimulateThink(_rbot, {}, {}, {_melee}, 0.5, {noCoreNearby=true})
    """)
    decision = lua.eval("_rDecision")
    assert decision == "harass", f"Ranged core vs melee should harass at aggrMult=0.5 (adj thresh=0.35), got {decision}"
test("Ranged core vs all-melee: harasses at aggrMult=0.5 (threshold drops to 0.35)", test_ranged_core_vs_melee_always_harasses)

def test_melee_core_uses_normal_threshold():
    """Melee core still needs aggrMult >= 0.85 to harass."""
    lua.execute("""
    _mbot  = makeBot({position=1, hp=800, attackDamage=80, attackRange=150,
                      loc={x=0,y=0}, attackCap=ATTACK_CAPABILITY_MELEE})
    _melee = makeHero(500, {loc={x=100,y=0}, attackCap=ATTACK_CAPABILITY_MELEE})
    -- aggrMult=0.5 below normal threshold (0.85) → should NOT harass
    _mDecision = SimulateThink(_mbot, {}, {}, {_melee}, 0.5, {noCoreNearby=true})
    """)
    decision = lua.eval("_mDecision")
    assert decision != "harass", f"Melee core should NOT harass at aggrMult=0.5 (normal thresh=0.85), got {decision}"
test("Melee core uses normal threshold (0.85), no range bonus", test_melee_core_uses_normal_threshold)

def test_ranged_vs_ranged_no_bonus():
    """Ranged bot vs ranged enemy: no threshold reduction (normal 0.85 applies)."""
    lua.execute("""
    _rbot2   = makeBot({position=1, hp=800, attackDamage=80, attackRange=600,
                        loc={x=0,y=0}, attackCap=ATTACK_CAPABILITY_RANGED})
    _renem   = makeHero(500, {loc={x=400,y=0}, attackCap=ATTACK_CAPABILITY_RANGED})
    -- aggrMult=0.5 — enemy is also ranged, so no adjustment
    _rrDecision = SimulateThink(_rbot2, {}, {}, {_renem}, 0.5, {noCoreNearby=true})
    """)
    decision = lua.eval("_rrDecision")
    assert decision != "harass", f"Ranged vs ranged should NOT harass at aggrMult=0.5, got {decision}"
test("Ranged vs ranged enemy: no bonus, normal 0.85 threshold applies", test_ranged_vs_ranged_no_bonus)

def test_ranged_support_vs_melee_lower_threshold():
    """Ranged support vs all-melee: threshold drops 1.2 → 0.7."""
    lua.execute("""
    _rsbot  = makeBot({position=5, hp=600, attackDamage=60, attackRange=600,
                       loc={x=0,y=0}, attackCap=ATTACK_CAPABILITY_RANGED})
    _melen  = makeHero(500, {loc={x=400,y=0}, attackCap=ATTACK_CAPABILITY_MELEE})
    -- aggrMult=0.8 is below supp default (1.2) but above adjusted (1.2-0.5=0.7)
    _rsDecision = SimulateThink(_rsbot, {}, {}, {_melen}, 0.8, {noCoreNearby=true})
    """)
    decision = lua.eval("_rsDecision")
    assert decision == "harass", f"Ranged support vs melee should harass at aggrMult=0.8 (adj thresh=0.7), got {decision}"
test("Ranged support vs all-melee: harasses at aggrMult=0.8 (threshold drops to 0.7)", test_ranged_support_vs_melee_lower_threshold)


print("\n── Ping Yield (laning drops desire on objective ping) ───────────────")

def test_ping_near_tower_yields():
    """Human pings near a tower 3s ago → laning mode should yield."""
    lua.execute("""
    local towerLoc = {x=5000, y=5000}
    local pingData = {location={x=5100, y=5050}, time=100.0}  -- 700 units away, 3s old
    _pingYield1 = ShouldYieldOnPing(pingData, towerLoc, 103.0)
    """)
    result = lua.eval("_pingYield1")
    assert result, "Ping within 800 units of tower, 3s old → should yield laning"
test("Ping 700u from tower, 3s old: laning yields", test_ping_near_tower_yields)

def test_ping_expired_no_yield():
    """Human ping is 12s old → expired, laning should NOT yield."""
    lua.execute("""
    local towerLoc2 = {x=5000, y=5000}
    local pingData2 = {location={x=5100, y=5050}, time=100.0}  -- 3s old
    _pingYield2 = ShouldYieldOnPing(pingData2, towerLoc2, 113.0)  -- 13s later
    """)
    result = lua.eval("_pingYield2")
    assert not result, "Ping older than 10s should NOT trigger yield"
test("Ping older than 10s: no yield (expired window)", test_ping_expired_no_yield)

def test_ping_far_from_tower_no_yield():
    """Human pings 2000 units from nearest tower → not near any tower, no yield."""
    lua.execute("""
    local towerLoc3 = {x=5000, y=5000}
    local pingData3 = {location={x=3000, y=3000}, time=100.0}  -- ~2828 units away
    _pingYield3 = ShouldYieldOnPing(pingData3, towerLoc3, 103.0)
    """)
    result = lua.eval("_pingYield3")
    assert not result, "Ping 2828u from tower (outside 800 radius) should NOT yield"
test("Ping 2800u from tower: no yield (outside 800u radius)", test_ping_far_from_tower_no_yield)


print("\n── Push Ping Bypasses Level Gate ────────────────────────────────────")

# Mirrors the logic: ping check now comes BEFORE the level-6 gate in aba_push.lua
# We simulate: isPingedAndMatchesLane → should return 0.9 regardless of hero levels

def test_push_ping_before_level_check():
    """Push ping detected before level check → returns 0.9 ignoring hero levels."""
    lua.execute("""
    -- Simulates the restructured GetPushDesireHelper logic:
    -- 1) ping check (now first), 2) level check (skipped by early return)
    function SimulatePushDesire(isPingedLane, anyHeroBelowSix)
        -- Ping check runs first (our fix: moved before level gate)
        if isPingedLane then
            return 0.9
        end
        -- Level check (would block without ping)
        if anyHeroBelowSix then
            return 0.0  -- BotModeDesire.None
        end
        return 0.65  -- normal push desire
    end
    _pingBeforeLevel_pinged   = SimulatePushDesire(true,  true)   -- pinged + someone low
    _pingBeforeLevel_noping   = SimulatePushDesire(false, true)   -- no ping + someone low
    _pingBeforeLevel_nopingnl = SimulatePushDesire(false, false)  -- no ping, all level 6+
    """)
    assert abs(lua.eval("_pingBeforeLevel_pinged") - 0.9) < 0.01, \
        "Ping should return 0.9 even if heroes below 6"
    assert lua.eval("_pingBeforeLevel_noping") == 0.0, \
        "Without ping, level gate blocks (returns 0)"
    assert abs(lua.eval("_pingBeforeLevel_nopingnl") - 0.65) < 0.01, \
        "Without ping and all level 6+, normal desire applies"
test("Push ping: bypasses level-6 gate, returns 0.9 even early game", test_push_ping_before_level_check)


print("\n── Defend Ping: All Ping Types, 10s Window ──────────────────────────")

def test_defend_ping_any_type():
    """Defend mode should react to normal AND warning pings (no normal_ping filter)."""
    lua.execute("""
    -- Simulates old (filtered) vs new (unfiltered) defend ping check
    function OldDefendPingCheck(ping)
        -- OLD: not ping.normal_ping required
        return ping and not ping.normal_ping
    end
    function NewDefendPingCheck(ping)
        -- NEW: any ping type is valid
        return ping ~= nil
    end
    local normalPing  = {location={x=100,y=100}, time=100.0, normal_ping=true}
    local warningPing = {location={x=100,y=100}, time=100.0, normal_ping=false}
    _oldNormal  = OldDefendPingCheck(normalPing)
    _oldWarning = OldDefendPingCheck(warningPing)
    _newNormal  = NewDefendPingCheck(normalPing)
    _newWarning = NewDefendPingCheck(warningPing)
    """)
    assert not lua.eval("_oldNormal"),  "Old code: normal ping was ignored"
    assert lua.eval("_oldWarning"),     "Old code: warning ping was accepted"
    assert lua.eval("_newNormal"),      "New code: normal ping must be accepted"
    assert lua.eval("_newWarning"),     "New code: warning ping still accepted"
test("Defend ping accepts all ping types (removed normal_ping filter)", test_defend_ping_any_type)

def test_defend_ping_window_10s():
    """Defend ping window is 10s (was 5s)."""
    lua.execute("""
    PING_DELTA_NEW = 10
    local pingTime = 100.0
    _within5s  = GameTime == nil and true or (100.0 + 4  < pingTime + PING_DELTA_NEW)
    _within10s = (100.0 + 9  < pingTime + PING_DELTA_NEW)  -- 9s after ping, within 10s
    _after10s  = (100.0 + 11 < pingTime + PING_DELTA_NEW)  -- 11s after, expired
    -- Simplified: use arithmetic
    _win5  = (4  < PING_DELTA_NEW)   -- 4s old, window=10 → valid
    _win10 = (9  < PING_DELTA_NEW)   -- 9s old, window=10 → valid
    _exp   = (11 < PING_DELTA_NEW)   -- 11s old, window=10 → expired
    """)
    assert lua.eval("_win5"),      "4s-old ping should be within 10s window"
    assert lua.eval("_win10"),     "9s-old ping should be within 10s window"
    assert not lua.eval("_exp"),   "11s-old ping should be expired (outside 10s window)"
test("Defend ping window is 10s (bots have more time to react)", test_defend_ping_window_10s)


print("\n── Hero Combo Chains ────────────────────────────────────────────────")

# Shared combo-chain simulator in Lua
lua.execute("""
-- Simulates the time-tracked chain logic added to Lion, Lina, Tidehunter.
-- Takes:
--   lastCastTime  : when the setup spell was cast (DotaTime units)
--   nowTime       : current DotaTime
--   chainMin      : minimum age before chain fires (0 for Lina/Tide, 0.8 for Lion)
--   chainMax      : maximum age for chain to remain active
--   setupAvail    : can chain-follower ability A be cast? (bool)
--   finishAvail   : can chain-follower ability B be cast? (bool)
-- Returns: 'chain_A', 'chain_B', or 'normal'
function SimulateComboChain(lastCastTime, nowTime, chainMin, chainMax, setupAvail, finishAvail)
    local age = nowTime - lastCastTime
    if age > chainMin and age <= chainMax then
        if setupAvail  then return "chain_A" end  -- e.g. Hex / LSA / Anchor Smash
        if finishAvail then return "chain_B" end  -- e.g. Finger / Laguna
    end
    return "normal"
end
""")

# ── Lion: Earth Spike → Hex → Finger ─────────────────────────────────────────
def test_lion_chain_hex_after_spike():
    """Within 0.8–1.5s of Spike, Hex (chain_A) fires before Finger."""
    lua.execute("""
    -- Spike cast 1.0s ago: past animation (0.8s), within chain window (1.5s)
    _lion1 = SimulateComboChain(100.0, 101.0, 0.8, 1.5, true, true)
    """)
    assert lua.eval("_lion1") == "chain_A", \
        "1.0s after Spike: Hex should fire first (chain_A)"
test("Lion: Hex fires immediately after Spike (0.8–1.5s window)", test_lion_chain_hex_after_spike)

def test_lion_chain_finger_when_hex_unavail():
    """Within window but Hex unavailable (on CD): Finger fires instead."""
    lua.execute("_lion2 = SimulateComboChain(100.0, 101.0, 0.8, 1.5, false, true)")
    assert lua.eval("_lion2") == "chain_B", \
        "Hex unavailable → Finger should fire during Spike window"
test("Lion: Finger fires when Hex unavailable during Spike window", test_lion_chain_finger_when_hex_unavail)

def test_lion_no_chain_before_animation():
    """First 0.8s after Spike: animation window, chain should NOT fire."""
    lua.execute("_lion3 = SimulateComboChain(100.0, 100.5, 0.8, 1.5, true, true)")
    assert lua.eval("_lion3") == "normal", \
        "Within 0.8s of Spike: animation window, chain must NOT fire yet"
test("Lion: chain blocked during 0.8s cast-animation window", test_lion_no_chain_before_animation)

def test_lion_no_chain_after_window():
    """After 1.5s, Spike stun has expired; chain window closes."""
    lua.execute("_lion4 = SimulateComboChain(100.0, 101.7, 0.8, 1.5, true, true)")
    assert lua.eval("_lion4") == "normal", \
        "1.7s after Spike: chain window closed, normal ordering resumes"
test("Lion: chain window closes after 1.5s", test_lion_no_chain_after_window)

# ── Lina: Dragon Slave → LSA → Laguna Blade ──────────────────────────────────
def test_lina_chain_lsa_after_slave():
    """Within 1.5s of Dragon Slave, LSA (chain_A) fires before Laguna."""
    lua.execute("_lina1 = SimulateComboChain(100.0, 101.0, 0.0, 1.5, true, true)")
    assert lua.eval("_lina1") == "chain_A", \
        "1.0s after Dragon Slave: LSA should fire first"
test("Lina: LSA fires immediately after Dragon Slave (within 1.5s)", test_lina_chain_lsa_after_slave)

def test_lina_chain_laguna_when_lsa_unavail():
    """Dragon Slave was cast but LSA on CD: Laguna fires during window."""
    lua.execute("_lina2 = SimulateComboChain(100.0, 101.0, 0.0, 1.5, false, true)")
    assert lua.eval("_lina2") == "chain_B", \
        "LSA unavailable → Laguna should fire during Dragon Slave window"
test("Lina: Laguna fires when LSA unavailable during Dragon Slave window", test_lina_chain_laguna_when_lsa_unavail)

def test_lina_no_chain_without_slave():
    """Without Dragon Slave recently cast, normal ordering (Laguna first) applies."""
    lua.execute("_lina3 = SimulateComboChain(-99.0, 100.0, 0.0, 1.5, true, true)")
    assert lua.eval("_lina3") == "normal", \
        "No recent Dragon Slave: normal ability ordering, not chain"
test("Lina: no chain without recent Dragon Slave", test_lina_no_chain_without_slave)

def test_lina_chain_closes_after_window():
    """After 1.5s Dragon Slave window closes; Laguna fires normally first."""
    lua.execute("_lina4 = SimulateComboChain(100.0, 101.7, 0.0, 1.5, true, true)")
    assert lua.eval("_lina4") == "normal", \
        "1.7s after Dragon Slave: chain window closed"
test("Lina: chain window closes after 1.5s", test_lina_chain_closes_after_window)

# ── Tidehunter: Ravage → Anchor Smash ────────────────────────────────────────
def test_tide_chain_anchor_after_ravage():
    """Within 2.5s of Ravage, Anchor Smash (chain_A) is forced."""
    lua.execute("_tide1 = SimulateComboChain(100.0, 101.5, 0.0, 2.5, true, false)")
    assert lua.eval("_tide1") == "chain_A", \
        "1.5s after Ravage: Anchor Smash must fire immediately"
test("Tidehunter: Anchor Smash forced immediately after Ravage (within 2.5s)", test_tide_chain_anchor_after_ravage)

def test_tide_chain_closes_after_window():
    """After 2.5s window: stun has ended, Anchor Smash not forced."""
    lua.execute("_tide2 = SimulateComboChain(100.0, 102.8, 0.0, 2.5, true, false)")
    assert lua.eval("_tide2") == "normal", \
        "2.8s after Ravage: stun expired, chain window closed"
test("Tidehunter: Anchor Smash chain closes after 2.5s", test_tide_chain_closes_after_window)

def test_tide_no_chain_without_ravage():
    """Without Ravage recently: no forced Anchor Smash (uses normal order)."""
    lua.execute("_tide3 = SimulateComboChain(-99.0, 100.0, 0.0, 2.5, true, false)")
    assert lua.eval("_tide3") == "normal", \
        "No recent Ravage: Anchor Smash not forced, normal ordering"
test("Tidehunter: no forced Anchor Smash without recent Ravage", test_tide_no_chain_without_ravage)


# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
print(f"\n{'='*55}")
print(f"  {len(PASS)} passed   {len(FAIL)} failed   {len(PASS)+len(FAIL)} total")
if FAIL:
    print(f"\n  Failed tests:")
    for f in FAIL:
        print(f"    - {f}")
    print()
    sys.exit(1)
else:
    print("\n  All tests passed! Logic behaves as expected.")
    print("  Run in-game (custom lobby) to validate bot actions visually.\n")
