local Utils = require( GetScriptDirectory()..'/FunLib/utils')
local J = require( GetScriptDirectory()..'/FunLib/jmz_func')
local LPressure = require( GetScriptDirectory()..'/FunLib/laning_pressure')

local Version      = require(GetScriptDirectory()..'/FunLib/version')
local Localization = require(GetScriptDirectory()..'/FunLib/localization')


local bot = GetBot()
local botName = bot:GetUnitName()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return end

local local_mode_laning_generic = nil
local nAllyCreeps = nil
local nEnemyCreeps = nil
local nFurthestEnemyAttackRange = 0
local nInRangeEnemy = nil
local botAssignedLane = nil
local botAttackRange = bot:GetAttackRange()
local attackDamage = bot:GetAttackDamage()
local nH, enemyBots = J.Utils.NumHumanBotPlayersInTeam(GetOpposingTeam())
local teamHumans, teamBots = J.Utils.NumHumanBotPlayersInTeam(GetTeam())

-- Laning pressure cache (refreshed every 3s)
local _lp_lastCalc  = -999
local _lp_enemyNames = {}
local _lp_aggrMult  = 1.0

-- Announcer state
local hasPickedOneAnnouncer      = false
local lastAnnouncePrintedTime    = 0
local numberAnnouncePrinted      = 1
local announcementGapSeconds     = 6
local isChangePosMessageDone     = false

if Utils.BuggyHeroesDueToValveTooLazy[botName] then local_mode_laning_generic = dofile( GetScriptDirectory().."/FunLib/override_generic/mode_laning_generic" ) end

function GetDesire()
	PickOneAnnouncer()
	AnnounceMessages()

	if bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return BOT_MODE_DESIRE_NONE end
	local botLV = bot:GetLevel()
	local currentTime = DotaTime()

	botAttackRange = bot:GetAttackRange()
	nAllyCreeps = bot:GetNearbyLaneCreeps(1200, false)
	nEnemyCreeps = bot:GetNearbyLaneCreeps(800, true)
	nInRangeEnemy = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	nFurthestEnemyAttackRange = GetFurthestEnemyAttackRange(nInRangeEnemy)

	-- Refresh laning pressure cache every 3 seconds
	local _now = DotaTime()
	if _now - _lp_lastCalc > 3 then
		_lp_lastCalc = _now
		_lp_enemyNames = {}
		for _, e in ipairs(nInRangeEnemy) do
			if J.IsValidHero(e) then
				table.insert(_lp_enemyNames, e:GetUnitName())
			end
		end
		_lp_aggrMult = LPressure.GetAggressionMultiplier(botName, _lp_enemyNames, bot:GetLevel())
	end
	if local_mode_laning_generic then
		botAssignedLane = local_mode_laning_generic.GetBotTargetLane()
	else
		botAssignedLane = bot:GetAssignedLane()
	end
	attackDamage = bot:GetAttackDamage()
	if bot:GetItemSlotType(bot:FindItemSlot("item_quelling_blade")) == ITEM_SLOT_TYPE_MAIN then
		if bot:GetAttackRange() > 310 or bot:GetUnitName() == "npc_dota_hero_templar_assassin" then
			attackDamage = attackDamage + 4
		else
			attackDamage = attackDamage + 8
		end
	end

	if GetGameMode() == 23 then currentTime = currentTime * 1.65 end
	if currentTime < 0 then return BOT_ACTION_DESIRE_NONE end

	-- if DotaTime() > 20 and DotaTime() - skipLaningState.lastCheckTime < skipLaningState.checkGap then
	-- 	if skipLaningState.count > 6 then
	-- 		print('[WARN] Bot ' ..botName.. ' switching modes too often, now stop it for laning to avoid conflicts.')
	-- 		return 0
	-- 	end
	-- else
	-- 	skipLaningState.lastCheckTime = DotaTime()
	-- 	skipLaningState.count = 0
	-- end

	if J.GetEnemiesAroundAncient(bot, 3200) > 0 then
		return BOT_MODE_DESIRE_NONE
	end

	-- if J.GetDistanceFromAncient( bot, true ) < 6900 then
	-- 	return BOT_MODE_DESIRE_NONE
	-- end

	if bot:WasRecentlyDamagedByAnyHero(5)
	and #J.Utils.GetLastSeenEnemyIdsNearLocation(bot:GetLocation(), 800) > 0 then
		local nLaneFrontLocation = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
		local nDistFromLane = GetUnitToLocationDistance(bot, nLaneFrontLocation)
		if not J.WeAreStronger(bot, 1200) or (nDistFromLane > 700 and J.GetHP(bot) < 0.7) then
			return BOT_MODE_DESIRE_NONE
		end
	end

	-- 如果在打高地 就别撤退去干别的
	if J.Utils.IsTeamPushingSecondTierOrHighGround(bot) then
		return BOT_MODE_DESIRE_NONE
	end

	-- Yield laning when the human player pings a tower objective (push or defend).
	-- This lets push/defend modes take over with their higher desire (0.9).
	-- Window: 10 seconds, any ping type, 800-unit proximity to any live tower.
	local _pingHuman, _pingData = J.GetHumanPing()
	if _pingHuman ~= nil and _pingData ~= nil and DotaTime() > 0 then
		if J.IsPingCloseToValidTower(GetOpposingTeam(), _pingData, 800, 10)
		or J.IsPingCloseToValidTower(GetTeam(),           _pingData, 800, 10) then
			return BOT_MODE_DESIRE_NONE
		end
	end

	-- if J.ShouldGoFarmDuringLaning(bot) then
	-- 	return 0.2
	-- end

	if local_mode_laning_generic or (J.GetPosition(bot) == 1 and J.IsPosxHuman(5)) then
		-- last hit
		if J.IsInLaningPhase() then
			local hitCreep, _ = GetBestLastHitCreep(nEnemyCreeps)
			if J.IsValid(hitCreep) then
				if J.GetPosition(bot) <= 2 or not J.IsThereNonSelfCoreNearby(700) -- this is for e.g lone druid bear as pos1-2 with core LD nearby to do last hit.
				then
					return 0.9
				end
			end
		end
	end
	if local_mode_laning_generic and local_mode_laning_generic.GetDesire ~= nil then return local_mode_laning_generic.GetDesire() end

	if GetGameMode() == GAMEMODE_1V1MID or GetGameMode() == GAMEMODE_MO then
		return 1
	end

	if currentTime <= 10 then return 0.268 end

	-- Spike boost: at power-spike level with matchup advantage → press the lane harder
	if _lp_aggrMult >= 1.3 and J.GetHP(bot) > 0.5 then
		if currentTime <= 9 * 60 and botLV <= 7  then return 0.52 end
		if currentTime <= 12 * 60 and botLV <= 11 then return 0.44 end
	end

	if currentTime <= 9 * 60 and botLV <= 7 then return 0.446 end
	if currentTime <= 12 * 60 and botLV <= 11 then return 0.369 end
	if botLV <= 14 and J.GetCoresAverageNetworth() < 7000 then return 0.2 end

	J.Utils.GameStates.passiveLaningTime = true
	return 0.01
end

function GetFurthestEnemyAttackRange(enemyList)
	local attackRange = 0
	for _, enemy in pairs(enemyList) do
		if J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy) then
			local enemyAttackRange = enemy:GetAttackRange()
			if enemyAttackRange > attackRange then
				attackRange = enemyAttackRange
			end
		end
	end

	return attackRange
end

function GetBestLastHitCreep(hCreepList)
	local dmgDelta = attackDamage * 0.7

	local moveToCreep = nil
	for _, creep in pairs(hCreepList) do
		if J.IsValid(creep) and J.CanBeAttacked(creep) then
			local nDelay = J.GetAttackProDelayTime(bot, creep)
			if J.WillKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL, nDelay) then
				return creep, false
			end
			if J.WillKillTarget(creep, attackDamage + dmgDelta, DAMAGE_TYPE_PHYSICAL, nDelay) then
				moveToCreep = creep
			end
		end
	end
	if moveToCreep then
		return moveToCreep, true
	end

	return nil
end

function GetBestDenyCreep(hCreepList)
	for _, creep in pairs(hCreepList)
	do
		if J.IsValid(creep)
		and J.GetHP(creep) < 0.49
		and J.CanBeAttacked(creep)
		and creep:GetHealth() <= attackDamage
		then
			return creep
		end
	end

	return nil
end

-- Unified laning Think() for all positions (1-5, overrides, pos1 with human pos5).
-- Fluidity model (ported from upstream ryndrb/dota2bot):
--   1. Let Action_AttackUnit run uninterrupted when last-hitting / denying.
--   2. Debounce the *fallback* move so the hero doesn't get re-ordered every tick.
--   3. Use Action_MoveDirectly (not IssueMove) to step into exact attack range,
--      with bounding-radius math so we stop *precisely* in range and attack.
--   4. Drop tower aggro the moment the enemy T1 targets us.
--   5. Pull back if we dove the enemy tower without creep cover.
-- Wrapped in pcall so Lua errors are both printed and chatted in-game.
local _lastErrChatTime   = -999
local fNextMovementTime  = 0

-- Drop tower aggro: if the enemy tower targets us, hand the aggro to the
-- nearest ally creep by attacking it; if no creep is available, retreat home.
local function DropTowerAggro(hUnit, nUnitList)
	if not J.IsValid(hUnit) then return false end
	local nEnemyTowers = hUnit:GetNearbyTowers(800, true)
	if not J.IsValidBuilding(nEnemyTowers[1]) then return false end
	if nEnemyTowers[1]:GetAttackTarget() ~= hUnit then return false end
	for _, creep in pairs(nUnitList) do
		if J.IsValid(creep) and GetUnitToUnitDistance(creep, nEnemyTowers[1]) < 700 then
			hUnit:Action_AttackUnit(creep, false)
			return true
		end
	end
	J.IssueMove(hUnit, J.GetTeamFountain())
	return true
end

-- Find a creep (e.g. siege) at a tower location — used for "attack tower while
-- our creep tanks it" opportunistic assist.
local function GetCreepInLocation(sCreepName, vLocation, nRadius, bEnemy)
	local list = bEnemy and GetUnitList(UNIT_LIST_ENEMY_CREEPS) or GetUnitList(UNIT_LIST_ALLIED_CREEPS)
	for _, creep in pairs(list) do
		if J.IsValid(creep)
		and GetUnitToLocationDistance(creep, vLocation) <= nRadius
		and string.find(creep:GetUnitName(), sCreepName) then
			return creep
		end
	end
	return nil
end

function Think()
	local ok, err = pcall(function()
		if J.CanNotUseAction(bot) then return end

		local pos  = J.GetPosition(bot)
		local myHp = J.GetHP(bot)

		-- Reload per-frame lane state cheaply (GetDesire caches most of this).
		local nEnemyTowers = bot:GetNearbyTowers(1200, true)
		local nInRangeAlly = J.GetAlliesNearLoc(bot:GetLocation(), 1200)

		-- PRIORITY 0 (always first): drop tower aggro if we're being shot at.
		if DropTowerAggro(bot, nAllyCreeps) then return end

		-- PRIORITY 1: Support camp stacking (:52-:57 window, pos4-5 only)
		if pos >= 4 then
			local hasCore = false
			for _, ally in ipairs(nInRangeAlly) do
				if J.IsValid(ally) and J.IsCore(ally) then hasCore = true; break end
			end
			if LPressure.ShouldSupportStack(bot, hasCore, myHp) then
				local campLoc = LPressure.GetNearestAllyCamp(bot)
				if campLoc then
					J.IssueMove(bot, campLoc)
					return
				end
			end
		end

		-- PRIORITY 2: Pull back if dove the enemy tower without creep cover.
		-- Spaced by fNextMovementTime so we don't re-issue every tick.
		if J.IsValidBuilding(nEnemyTowers[1]) then
			local distTower = GetUnitToUnitDistance(bot, nEnemyTowers[1])
			local enemyCreepsAtTower = bot:GetNearbyLaneCreeps(800, true)
			if distTower < 800 and #enemyCreepsAtTower < 3 then
				if DotaTime() >= fNextMovementTime then
					bot:Action_MoveDirectly(J.VectorAway(bot:GetLocation(), nEnemyTowers[1]:GetLocation(), 950) + RandomVector(75))
					fNextMovementTime = DotaTime() + RandomFloat(1, 3)
				end
				return
			end
		end

		-- PRIORITY 3: Last hit enemy creeps.
		-- Use Action_MoveDirectly into bounding-radius-adjusted spot so the bot
		-- stops *exactly* at attack range and immediately swings — the single
		-- biggest fluidity win over Action_MoveToUnit.
		local canLastHit = pos <= 3 or not J.IsThereNonSelfCoreNearby(700)
		if canLastHit then
			local hitCreep, moveToIt = GetBestLastHitCreep(nEnemyCreeps)
			if J.IsValid(hitCreep) then
				local dist = GetUnitToUnitDistance(bot, hitCreep)
				if dist > botAttackRange then
					bot:Action_MoveDirectly(J.VectorTowards(hitCreep:GetLocation(), bot:GetLocation(), botAttackRange - hitCreep:GetBoundingRadius()))
				else
					-- Direct Action_AttackUnit (no debounce) so wind-up never gets cancelled.
					bot:SetTarget(hitCreep)
					bot:Action_AttackUnit(hitCreep, false)
				end
				return
			end
		end

		-- PRIORITY 4: Deny dying ally creeps
		local denyCreep = GetBestDenyCreep(nAllyCreeps)
		if J.IsValid(denyCreep) then
			bot:SetTarget(denyCreep)
			bot:Action_AttackUnit(denyCreep, true)
			return
		end

		-- PRIORITY 5: Siege-assist — if enemy tower is shooting a creep and we
		-- have wave advantage, chip the tower while our creeps tank.
		if J.IsValidBuilding(nEnemyTowers[1])
		and J.CanBeAttacked(nEnemyTowers[1])
		and J.IsValid(nEnemyTowers[1]:GetAttackTarget())
		and nEnemyTowers[1]:GetAttackTarget():IsCreep()
		and #nInRangeAlly >= (nInRangeEnemy and #nInRangeEnemy or 0) then
			local siegeCreep = GetCreepInLocation('siege', nEnemyTowers[1]:GetLocation(), 800, false)
			if J.IsValid(siegeCreep) and J.GetHP(siegeCreep) >= 0.5
			and siegeCreep:GetAttackTarget() == nEnemyTowers[1] then
				bot:Action_AttackUnit(nEnemyTowers[1], true)
				return
			end
		end

		-- PRIORITY 6: Harass — attack enemy heroes in range
		local rangeAdj    = LPressure.GetRangeMatchupAdjust(bot, nInRangeEnemy)
		local harassThresh = (pos <= 3 and 0.85 or 1.2) + rangeAdj
		-- Supports: don't harass while we have creep aggro (≥2 nearby enemy creeps)
		local closeEnemyCreeps = bot:GetNearbyLaneCreeps(600, true)
		local creepAggroSafe   = pos <= 3 or #closeEnemyCreeps <= 1
		if myHp > 0.5 and nInRangeEnemy and #nInRangeEnemy > 0
		and creepAggroSafe and _lp_aggrMult >= harassThresh then
			local bestTarget, bestHp = nil, 1.1
			for _, enemy in ipairs(nInRangeEnemy) do
				if J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy)
				and J.IsInRange(bot, enemy, botAttackRange + 100)
				and J.GetHP(enemy) < bestHp then
					bestHp     = J.GetHP(enemy)
					bestTarget = enemy
				end
			end
			if bestTarget then
				bot:SetTarget(bestTarget)
				bot:Action_AttackUnit(bestTarget, true)
				return
			end
		end

		-- PRIORITY 7: Hero-override specific logic (Tinker, Morphling, etc.)
		if local_mode_laning_generic then
			local_mode_laning_generic.Think()
			return
		end

		-- FALLBACK: walk to lane front, but only every 0.3–0.9s so we don't
		-- re-issue movement on every tick (the smoothness trick).
		if botAssignedLane and DotaTime() >= fNextMovementTime then
			local nLongestAttackRange    = math.max(botAttackRange, 250, nFurthestEnemyAttackRange)
			local fLaneFrontAmount       = GetLaneFrontAmount(GetTeam(), botAssignedLane, false)
			local fLaneFrontAmount_enemy = GetLaneFrontAmount(GetOpposingTeam(), botAssignedLane, false)
			local target_loc = GetLaneFrontLocation(GetTeam(), botAssignedLane, -nLongestAttackRange)
			if fLaneFrontAmount_enemy < fLaneFrontAmount then
				target_loc = GetLaneFrontLocation(GetOpposingTeam(), botAssignedLane, -nLongestAttackRange)
			end
			bot:Action_MoveToLocation(target_loc + RandomVector(100))
			fNextMovementTime = DotaTime() + RandomFloat(0.3, 0.9)
		end
	end)

	-- Error reporting: print to console + chat in-game (max once per 30s per bot)
	if not ok then
		print("[LaneBot Error] " .. tostring(err))
		if DotaTime() - _lastErrChatTime > 30 then
			_lastErrChatTime = DotaTime()
			bot:ActionImmediate_Chat("[Script Error] " .. tostring(err):sub(1, 80), false)
		end
	end
end


function PickOneAnnouncer()
	if not hasPickedOneAnnouncer then
		for i, _ in pairs(GetTeamPlayers(GetTeam())) do
			local member = GetTeamMember(i)
			if member ~= nil and member.isAnnouncer then return end
		end
		bot.isAnnouncer = true
		hasPickedOneAnnouncer = true
	end
end

function AnnounceMessages()
	-- Only pre-game chatter
	if DotaTime() > 60 then return end

	local welcomeMessages = Localization.Get('welcome_msgs')
	local inTurbo         = J.IsModeTurbo()

	-- Staggered lines during negative DotaTime pre-game
	if ((inTurbo and DotaTime() > -50 + GetTeam() * 2) or (not inTurbo and DotaTime() > -75 + GetTeam() * 2))
	   and numberAnnouncePrinted < #welcomeMessages + 1
	   and bot.isAnnouncer
	   and DotaTime() < 0
	then
		if GameTime() - lastAnnouncePrintedTime >= announcementGapSeconds then
			local message      = welcomeMessages[numberAnnouncePrinted]
			local isFirstLine  = (numberAnnouncePrinted == 1)
			if message then
				-- Match original behavior: first line (or if no enemy bots) can be global
				bot:ActionImmediate_Chat(isFirstLine and (message .. Version.number) or message, enemyBots == 0 or isFirstLine)
			end
			numberAnnouncePrinted   = numberAnnouncePrinted + 1
			lastAnnouncePrintedTime = GameTime()
		end
	end

	-- Announce role during pre-game
	if GetGameMode() ~= GAMEMODE_1V1MID
	   and GetGameState() == GAME_STATE_PRE_GAME
	   and (bot.announcedRole == nil or bot.announcedRole ~= J.GetPosition(bot))
	then
		bot.announcedRole = J.GetPosition(bot)
		bot:ActionImmediate_Chat(Localization.Get('say_play_pos') .. J.GetPosition(bot), false)
	end

	-- Close position selection after horn if humans and bots mixed
	if GetGameMode() ~= GAMEMODE_1V1MID and not isChangePosMessageDone then
		if DotaTime() >= 0 and teamHumans > 0 and teamBots > 0 then
			bot:ActionImmediate_Chat(Localization.Get('pos_select_closed'), true)
			isChangePosMessageDone = true
		end
	end
end
