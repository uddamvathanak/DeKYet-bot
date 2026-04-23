# Dota 2 Bot Scripts — Claude Code Guide

## Project Overview

This is the **DeKYet Bot** repo. The `bots/` folder currently holds an **unmodified copy of [ryndrb / dota2bot (Tinkering ABout)](https://github.com/ryndrb/dota2bot)** as a clean baseline. No DeKYet modifications have been layered on yet.

Supports Patch 7.41 / 7.41a.

## Architectural rule (very important)

**Do not rewrite or edit ryndrb's files until the baseline has been verified stable in a lobby.** The whole point of this baseline reset was that our previous OHA-based fork had broken fluidity by rewriting per-tick `Think()` loops. When improvements begin, they go in:

- **New side modules** (e.g. `bots/FunLib/dekyet_*.lua`) that *inform* decisions
- **`GetDesire()` augmentations** that bias when a mode activates
- **Never** in the per-tick `Think()` action-emit path

See [docs/IMPROVEMENTS_ROADMAP.md](docs/IMPROVEMENTS_ROADMAP.md) for the full plan.

## Key documentation

- [docs/IMPROVEMENTS_ROADMAP.md](docs/IMPROVEMENTS_ROADMAP.md) — what we plan to add on top of ryndrb, in priority order, with lessons from the OHA attempt
- [README.md](README.md) — install + play instructions
- [ryndrb's README](https://github.com/ryndrb/dota2bot) — baseline documentation

## Common tasks

### Verify the baseline in a lobby

1. Run `install-symlink.bat` as Administrator (creates symlink from Dota's vscripts/bots to this repo's `bots/`).
2. Launch Dota -> Custom Lobby -> Local Host -> Local Dev Script for both teams.
3. Expected welcome chat: `"Check out the GitHub page to get the latest files: https://github.com/ryndrb/dota2bot"` — that is ryndrb's baseline speaking. If you see any "Welcome to Open Hyper AI" text, Dota is still loading from a stale install, not this symlink.

### Layer an improvement (only after baseline is verified)

1. Read the relevant section in [docs/IMPROVEMENTS_ROADMAP.md](docs/IMPROVEMENTS_ROADMAP.md).
2. Add the improvement in a **new file** under `bots/FunLib/` or as a small, well-scoped patch to `GetDesire()` in the relevant mode file.
3. Include a kill-switch flag (e.g. `M.ENABLED = true`) at the top of every new module.
4. Lobby-test immediately; if anything regresses, flip the flag off.
5. Commit each layer separately so rollback is a single `git revert`.

## Important rules

- **Do not touch ryndrb's `Think()` functions.**
- **Every new module must `require('.../FunLib/jmz_func')` if it uses `J.*` helpers** — silent nil-index errors look like "bots stuck doing nothing" in-game.
- **Use `bot:GetAttackRange() > 300`** as the ranged-check idiom. `GetAttackCapability()` and `ATTACK_CAPABILITY_RANGED` do not exist in the Dota bot Unit API.
- **Verify any ability/item name on [Liquipedia](https://liquipedia.net/dota2)** before trusting patch note summaries.
- **Lobby-test after every layer**, not after every commit batch. The Lua VM does not surface most errors until a bot enters the relevant mode.
