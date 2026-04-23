# DeKYet Bot — Dota 2 Bot Scripts

**Baseline: [ryndrb / dota2bot (Tinkering ABout)](https://github.com/ryndrb/dota2bot), 7.41.**

The `bots/` folder in this repo is currently an **unmodified copy of ryndrb's Tinkering ABout**. This is the foundation DeKYet Bot is being built on top of. No modifications yet — next step is layering improvements one at a time per [docs/IMPROVEMENTS_ROADMAP.md](docs/IMPROVEMENTS_ROADMAP.md).

> **Baseline history:** DeKYet Bot was originally forked from [OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI). After head-to-head testing we migrated to ryndrb because his per-tick action loop is smoother and more stable. The previous OHA-based work lives in git history (see commit `91117b0`).

---

## How to play

Custom Lobby -> **Local Host** server -> pick **Local Dev Script** for both teams.

### Install (Windows)

Run `install-symlink.bat` as Administrator. It creates a symbolic link from Dota's vscripts bots folder to this repo's `bots/` folder, so changes here are live without reinstalling.

The script assumes Steam is at the default `C:\Program Files (x86)\Steam\...` path. Edit the first line of the `.bat` if yours differs.

### Install (manual)

Copy or symlink the contents of `bots/` to:

```
<Steam>\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots\
```

---

## What's in `bots/`

Exactly what ryndrb publishes at <https://github.com/ryndrb/dota2bot>:

- `bot_generic.lua` + `mode_*.lua` — per-mode Think/Desire logic
- `hero_selection.lua`, `ability_item_usage_generic.lua`, `item_purchase_generic.lua` — global hooks
- `BotLib/hero_*.lua` — per-hero ability logic
- `FunLib/` — shared utilities (`jmz_func.lua`, `aba_*.lua`, etc.)
- `Buff/` — optional side vscript for GPM/XPM boost (install separately per ryndrb's README)
- `API/` — Valve bot API reference stubs

Do not edit these files until the baseline has been verified stable in a lobby. Once confirmed, additions go in *new* files that augment `GetDesire()` or add side modules — we do not rewrite ryndrb's `Think()` loops (that was the mistake in the OHA port). See the roadmap for details.

---

## Roadmap

See [docs/IMPROVEMENTS_ROADMAP.md](docs/IMPROVEMENTS_ROADMAP.md) for the planned additions and the architectural rules for layering them on top of ryndrb without breaking his fluidity.

---

## Credits

- **[ryndrb / dota2bot (Tinkering ABout)](https://github.com/ryndrb/dota2bot)** — current baseline; the `bots/` tree is his work, unmodified
- **[forest0xia / dota2bot-OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI)** — the earlier foundation DeKYet was built on; several of our planned side modules originated there
- **New Beginner AI** (dota2jmz@163.com) — upstream of ryndrb's script
- **[Ranked Matchmaking AI](https://github.com/adamqqqplay/dota2ai)** (adamqqq)
- **[fretbots](https://github.com/fretmute/fretbots)** (fretmute)
- **[ExtremePush](https://github.com/insraq/dota2bots)** (insraq)
- BOT Experiment (Furiospuppy)
- All other contributors who made Dota 2 bot games better

---

## License

MIT License — see [LICENSE](LICENSE) for full text.

The `bots/` baseline is the work of ryndrb and upstream contributors. DeKYet Bot additions (once they exist on top of the baseline) (c) 2025-2026 DeKYet Bot Contributors.
