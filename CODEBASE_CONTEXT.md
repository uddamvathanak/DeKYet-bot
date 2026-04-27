# Codebase Context — DeKYet Bot

Tree of context for new chats. Update whenever adding/editing/deleting files or folders.

## Top level

- `install-symlink.bat` — Admin script: junctions `bots/` to `<Dota>/game/dota/scripts/vscripts/bots`. Live alias, edits flow into Dota directly.
- `README.md` — install + play instructions.
- `CLAUDE.md` — project rules. Architectural rule: never rewrite ryndrb's `Think()`; new code goes in `bots/FunLib/dekyet_*.lua` with kill-switches.
- `CODEBASE_CONTEXT.md` — this file.
- `docs/IMPROVEMENTS_ROADMAP.md` — priority list of layers to add over the ryndrb baseline.
- `bots/` — ryndrb baseline + DeKYet additions.

## `bots/` — Dota 2 vscripts entrypoint

Top-level files are Dota's required entrypoints (`mode_*_generic.lua`, `ability_item_usage_generic.lua`, `item_purchase_generic.lua`, `hero_selection.lua`, etc.). Subfolders:

- `bots/API/` — engine API wrappers / game-state interfaces.
- `bots/BotLib/` — per-hero decision logic (`hero_*.lua`, role assignments, etc.).
- `bots/Buff/` — modifier/buff tracking utilities.
- `bots/FunLib/` — shared strategy library and DeKYet additions.

### `bots/FunLib/` (selected)

ryndrb baseline:
- `jmz_func.lua` — central `J.*` helper module (distance, networth, hero queries, attack-delay model, etc.). Required by virtually every mode file.
- `aba_push.lua` — `Push.GetPushDesire` / `Push.PushThink` + lane-scoring and high-ground logic.
- `aba_defend.lua`, `aba_item.lua`, `aba_role.lua`, `aba_skill.lua`, `aba_ward_utility.lua`, `aba_modifiers.lua`, `aba_minion.lua`, `aba_special_units.lua`, `aba_buff.lua`, `aba_chat*.lua`, `aba_site.lua` — supporting modules.
- `spell_list.lua` — per-ability priority weights.
- `bot_names.lua`, `lua_util.lua`, `util_role_item.lua`, `MinionLib/`.

DeKYet additions (kill-switchable side modules):
- `dekyet_debug_log.lua` — global `print` no-op gate; `M.DEBUG_LOG=true` to restore.
- `dekyet_pressure_bias.lua` — `Pressure.ShouldSuppressFarm(bot)` (early-return guard in `mode_farm_generic.GetDesire`) and `Pressure.GetPushBoost(bot, lane)` (added to `aba_push.GetPushDesire` before final clamp). Discourages greedy jungle farm and biases pushing when team has tempo.
- `dekyet_team_engage.lua` — `Engage.GetTeamRoamBoost(bot)` (added to `mode_team_roam_generic` target-desire returns). Bumps engage commitment when ≥4 allies grouped and not behind.
- `dekyet_lasthit.lua` — `DKLastHit.GetIncomingAllyDamage(creep, nDelay)`. Used in `mode_laning_generic.GetBestLastHitCreep` to include ally creep damage in the kill threshold so the bot snipes near-kill creeps.

## Modified ryndrb files (DeKYet plumbing only — ≤2 lines each, all gated by `M.ENABLED` flags)

- `bots/mode_farm_generic.lua` — requires `dekyet_pressure_bias`; calls `Pressure.ShouldSuppressFarm(bot)` in the early-exit chain of `GetDesire`.
- `bots/FunLib/aba_push.lua` — requires `dekyet_pressure_bias`; adds `Pressure.GetPushBoost(bot, lane)` before the final return in `GetPushDesire`.
- `bots/mode_team_roam_generic.lua` — requires `dekyet_team_engage`; adds `Engage.GetTeamRoamBoost(bot)` into the two `Clamp(targetDesire, ...)` returns.
- `bots/mode_laning_generic.lua` — requires `dekyet_lasthit`; adds `nAllyIncoming` to the damage threshold in `GetBestLastHitCreep`.
