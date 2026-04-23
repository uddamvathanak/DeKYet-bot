# Improvements Roadmap — Layering on top of ryndrb/dota2bot

**Baseline:** [ryndrb/dota2bot](https://github.com/ryndrb/dota2bot) (Tinkering ABout, 7.41).
**Premise:** ryndrb's bots beat OpenHyperAI in head-to-head play. We restart from his
baseline because it's *fluid* and *stable*, then layer the smart additions below
on top — keeping his `Think()` shape, augmenting his `GetDesire()` and adding
new strategic modules.

---

## Architectural rule

- **Never rewrite his `Think()` functions.** They are hand-tuned for fluidity
  (debounced moves, `Action_MoveDirectly`, uninterrupted `Action_AttackUnit`).
  Our additions live in `GetDesire()` (when to enter a mode) and in new
  side-modules that decide *what* to push toward — not *how* to walk.
- Action emit stays in his hands. Strategy decisions stay in ours.
- Every new module ships with a kill-switch (e.g. `M.ENABLED = true`). If a
  feature breaks lobby launch, flip the flag.

---

## What to port from our OHA fork (in priority order)

### 1. Rock-Paper-Scissors team strategy (`game_strategy.lua`)

- ROCK = high-ground defend (we're behind on towers / NW)
- PAPER = winning team smoke-gank-push (NW lead, no major item gap)
- SCISSORS = vision-based counter-gank against split-farming enemies
- Hysteresis: 8 s cache so the strategy doesn't flap.
- Hooks into `mode_team_roam_generic` to bias smoke/gank/push decisions.
- **Skip the strategy-aware `mode_laning` desire bumps** — they over-fired on
  ryndrb's tighter laning loop.

### 2. Team-defense rally (`aba_defend.lua` extension)

- When T2+ tower under attack with enemies present and a recent ally ping or
  ally already defending, raise `defend_tower_*` desire to 0.88–0.9 (ROCK +0.05
  bonus). Set `bot._rallyActive=true`.
- Allies with TP ready and >3500 from rally hub TP to a safe point 900 from
  the hub.
- Don't TP if enemies already at the safe point.

### 3. Push coordination (`aba_push.lua` extension)

- During PAPER strategy, raise `push_tower_*` floor by 0.08 when:
  - Wave is in enemy half *and* ≥3 allies near *and* core has BKB ready.
- Cancel push and rally if a teammate dies during the push window.

### 4. Hero matchup + spike awareness (`laning_pressure.lua`)

- Per-hero `LEVEL_SPIKE` table (when each hero becomes a kill threat).
- `LANE_BULLY` set (Bristleback/Viper/Husk/etc. press regardless of spike).
- `PASSIVE_EARLY` set (Medusa/Spectre/AM/etc. always farm safe).
- `GetAggressionMultiplier(botName, enemies, level)` → returns 0.5–1.6.
- **Read in `GetDesire()` only**, never in `Think()`. Used to bump laning
  desire when we're at spike + countering enemy.
- `ShouldSupportStack(bot, hasCore, hp)` for the :52–:57 stacking window.

### 5. Captain mode draft helper (`captain_mode.lua`, `draft_style.lua`)

- Already standalone, just drop in. No Think-loop interaction.

### 6. Hero role assignment overrides (`aba_hero_roles_map.lua`,
       `aba_hero_pos_weights.lua`)

- Better pos-1..5 assignments per hero than ryndrb's defaults.
- Patch into `hero_selection.lua` only.

### 7. Item build polish (`aba_item.lua`, `BotLib/hero_*.lua`)

- Hero-specific `sRoleItemsBuyList[pos_N]` arrays we tuned for 7.41.
- Worth diffing per-hero: keep ours where it's clearly better (e.g. recent
  patch items), keep ryndrb's where his timing is sharper.

### 8. Idle watchdog (`J.CheckBotIdleState`)

- Detects the "stuck at fountain in BOT_MODE_RETREAT at full HP" bug and
  forces a mode reset. Useful even on ryndrb's bots — adds resilience without
  touching his action loop.

### 9. Print gate (`debug_log.lua`)

- Idempotent global `print` no-op unless `DEBUG_LOG=true`.
- Cheap perf win across every hot file (saves Lua VM string-format cost).

### 10. Sticky-target helper (`SetStickyTarget` pattern)

- 1.0–1.2 s target-lock to prevent rapid re-target jitter.
- Apply to farm mode and team_roam (already in upstream team_roam).

---

## What to leave behind from the OHA fork

- The full `Think()` rewrites we did — they fight ryndrb's fluidity.
- The `J.IssueMove*` debounce wrappers — ryndrb's per-file `fNextMovementTime`
  pattern is simpler and works. (Keep them only as utilities for *new* code we
  add, not as a replacement for his calls.)
- The `bots/FunLib/override_generic/mode_*.lua` files — ryndrb's hero-specific
  paths are tighter; only port heroes that visibly play wrong.
- `aba_global_overrides.lua` package.path mac-compat shim — verify ryndrb
  doesn't already handle this; if not, port just the 6-line `package.path`
  block.

---

## Migration plan (suggested ordering)

1. **Snapshot current `bots/`** to `bots_oha_backup/` (keep for diff reference).
2. **Drop in ryndrb baseline** as the new `bots/`.
3. **Smoke-test in lobby** — confirm bots launch and play unmodified.
4. **Layer additions one at a time**, syntax-check + lobby-test after each:
   - debug_log.lua (lowest risk)
   - laning_pressure.lua (read-only side module)
   - aba_hero_roles_map.lua + aba_hero_pos_weights.lua
   - game_strategy.lua (RPS)
   - aba_defend.lua / aba_push.lua extensions
   - per-hero item builds
   - idle watchdog
5. **Tag a release** after each working layer so we can roll back.

---

## What we learned from this round (don't repeat)

- **Don't fork `Think()` functions.** Every per-tick action call in the bot
  loop has ripple effects on animation/cast smoothness. Augment with new
  modules that *inform* his Think, don't replace it.
- **`GetAttackCapability` and `ATTACK_CAPABILITY_RANGED` don't exist** in the
  Dota bot Unit API. Use `bot:GetAttackRange() > 300` (the codebase idiom).
- **Lazy-require modules** that have potential cycles (`aba_matchups` from
  `laning_pressure`).
- **Always require `J = require '...jmz_func'`** at the top of any new module
  that uses `J.*` helpers — silent nil-index errors look like "bots stuck
  doing nothing" in-game.
- **Lobby-test after every layer**, not after every commit batch. The Lua VM
  doesn't surface most errors until the bot enters the relevant mode.
