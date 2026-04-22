# Codebase Context — dota2bot-OpenHyperAI

## Project Overview
Lua bot scripts for Dota 2 custom lobbies. Forked from forest0xia/dota2bot-OpenHyperAI, customized with strategic overhaul.

## Key Directories
- `bots/` — Main bot scripts loaded by Dota 2 engine
- `bots/BotLib/` — Per-hero builds and ability logic (hero_*.lua)
- `bots/FunLib/` — Shared utility/library modules
- `bots/FretBots/` — Matchup data, hero names, neutral items
- `bots/Customize/` — User-facing configuration (bot names, bans, tuning)
- `bots/ts_libs/` — TypeScript-generated Dota 2 API type definitions
- `typescript/` — TypeScript source files (compiled to Lua via TypeScriptToLua)
- `docs/` — Architecture docs, patch update guide

## Key Files (Modified/Added)

### Custom Strategy System
- `bots/FunLib/game_strategy.lua` — **NEW** Central strategy brain. Rock-Paper-Scissors macro: AGGRESSIVE / DEFENSIVE / SPLIT_FARM. Returns desire multipliers (push_mult, defend_mult, farm_mult, roam_mult) that all modes consult.

### Mode Files
- `bots/FunLib/aba_push.lua` — Push desire logic. Modified: turbo boost (0.85 base), strategy multiplier, skip 5-enemy cap in turbo.
- `bots/FunLib/aba_defend.lua` — Defend desire logic. Modified: turbo cap (0.55 max), strategy multiplier.
- `bots/mode_farm_generic.lua` — Farm mode. Modified: turbo farm cap (0.35 max), strategy multiplier.
- `bots/mode_team_roam_generic.lua` — Team roam / fight mode. Modified: strategy multiplier, smoke gank sub-behavior (FindIsolatedEnemy, ShouldSmokeGank, smoke usage in Think).

### Items
- `bots/item_purchase_generic.lua` — Purchase state machine. Modified: hero-specific Divine Rapier whitelist (gyro/medusa/morphling/PA/ember/kunkka/arc/drow PLUS spell-damage carries zeus/lina/SF/TA/tinker for magic-toggle rapier), counter-itemization injection (MKB vs evasion, Mjollnir vs illusions, Dust vs invis).
- `bots/ability_item_usage_generic.lua` — Item usage logic. Modified: Moon Shard eat fix (check main inventory full, not backpack empty).
- `bots/FunLib/advanced_item_strategy.lua` — Counter-item definitions and threat detection (dead code, not imported — counter logic inlined in item_purchase_generic instead).

### Warding
- `bots/FunLib/aba_ward_utility.lua` — Ward positions. Modified: added Roshan pit wards, outpost wards, enemy farming route wards. Objective wards injected at top of available spots list.

### Draft
- `bots/FunLib/draft_style.lua` — **NEW** Draft style system.
  - Hero tag tables: AOE_LOCKDOWN, COMBO_AMPLIFIER, SNOWBALL_CORE, KILL_SUPPORT, HARD_CARRY
  - Style scoring: `GetStyleBonus(style, cand, allyNames, posIndex)`
  - **Enemy draft detection**: `DetectEnemyStyle(enemyNames)` → "late_game" / "wombo_combo" / "snowball" / "push"
  - **Reactive switching**: `UpdateEnemyRead(enemyNames)` called before each bot pick; auto-counter-styles (late_game/wombo → snowball; snowball/push → wombo_combo). Inspired by Parivision / Team Liquid adaptive drafting.
  - **Meta tier list**: `GetMetaBonus(cand)` → S-tier (+1.5), A-tier (+0.75). Patch 7.41 heroes. Update `META_HEROES` table each major patch.
  - Styles: "wombo_combo" (Tundra/Spirit), "snowball" (XG/Gaimin), "auto" (random + reactive)
- `bots/hero_selection.lua` — Hero drafting. Modified:
  - Counter-pick weights tightened to 50/25/15/7/3 (heavily favor best counter)
  - Turbo bias: +2 score for high initiator+nuker+disabler heroes
  - Team composition penalty: -3 score for 4th+ core pick
  - **Role gap scoring**: +3 for disabler (must-have), +2.5 initiator, +2 healer, +1.5 nuker/carry when that role is missing from team
  - **Wait-for-human**: when human is on bot's team, all bots defer picking until the human picks first; bots then pick 2s later in sequence. Emergency override at GameTime ≥ 65s (last ~5s) to avoid time-out.
  - Draft style bonus wired in as step 7 of scoring
  - Helper functions: `HasHumanOnTeam`, `HumanOnTeamHasPicked`, `GetMissingTeamRoles`, `GetHeroRolesMap`
- `bots/Customize/general.lua` — Added `Customize.DraftStyle = "auto"` setting with full documentation comment.

### Laning Phase Intelligence
- `bots/FunLib/laning_pressure.lua` — **NEW** Laning pressure and power spike module.
  - `LEVEL_SPIKE` table: hero → level when they become a kill threat (~35 heroes). Cores spike at 6, bullies at 2–3.
  - `LANE_BULLY` / `PASSIVE_EARLY` tables: heroes that pressure early vs heroes that farm passively.
  - `GetLaneMatchupScore(botName, enemyNames)`: uses `aba_matchups.IsCounter()` to score the lane matchup. Positive = we counter them.
  - `GetAggressionMultiplier(botName, enemyNames, botLevel)`: combines spike level + bully flag + matchup score → returns 0.5–1.6× multiplier. Turbo adds +0.1.
  - `IsStackingWindow()`: returns true at :52–:57 of each minute (the camp stacking window).
  - `ShouldSupportStack(bot, hasAllyCore, myHp)`: pos4-5, HP > 55%, ally core in lane, and in stacking window.
  - `GetNearestAllyCamp(bot)`: finds nearest allied medium/large camp within 3200 range (penalises small camps).
- `bots/mode_laning_generic.lua` — Modified:
  - Requires `laning_pressure`; caches `_lp_aggrMult` every 3s using nearby enemy hero names.
  - Spike-aware desire: when `aggrMult ≥ 1.3` and HP > 50%, desire bumps from 0.446 → 0.52 (cores press when strong).
  - **General `Think()` for all positions**: added as `else` branch (previously undefined for pos2-5 non-override heroes):
    - Supports (pos4-5): move to nearest camp during stacking window when a core is in lane.
    - Cores at spike: attack the lowest-HP enemy hero within attack range.
    - Fallback: move to lane front.
- `bots/mode_roam_generic.lua` — Modified:
  - Requires `laning_pressure`.
  - Camp stacking desire (0.62) added to `ConsiderGeneralRoamingInConditions()` for pos4-5 supports during `IsInLaningPhase()`.
  - `ThinkGeneralRoaming()`: when `_isStacking`, moves to `_stackCampLoc` until window closes.

### Config
- `bots/Customize/general.lua` — Bot names set to ZL 1-10, Customize.Enable = true.
- `install-symlink.bat` — Creates symlink from Dota 2 vscripts/bots to this repo.

## TypeScript Sources
Some Lua files are generated from TypeScript (marked `Generated with TypeScriptToLua`). When modifying these, also update the `.ts` source in `typescript/`. Modified TS files:
- `typescript/bots/FunLib/aba_push.ts` — Turbo push changes mirrored from Lua.
