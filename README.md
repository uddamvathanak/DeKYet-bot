# DeKYet Bot — Dota 2 Bot Scripts

**Pro-style Dota 2 bot scripts built on top of [ryndrb's Tinkering ABout](https://github.com/ryndrb/dota2bot).** The ryndrb baseline gives bots that lane fluidly, last-hit reliably, and feel hand-tuned; on top of that foundation, DeKYet Bot layers pro-style drafting, macro strategy, power-spike awareness, and team coordination.

> **Baseline note (2026-04):** DeKYet Bot was originally built on OpenHyperAI. After extensive testing, we migrated the baseline to ryndrb's Tinkering ABout because its per-tick action loop is smoother and more stable. See [docs/IMPROVEMENTS_ROADMAP.md](docs/IMPROVEMENTS_ROADMAP.md) for the roadmap of additions being re-layered on the new baseline.

> **To play:** Create a **Custom Lobby** and select **Local Host** as the server location.

---

## What's New in DeKYet Bot

On top of the ryndrb Tinkering ABout baseline, DeKYet Bot adds:

### Draft Intelligence
- **Pro-style draft styles** — Wombo Combo (Tundra/Spirit: chain AoE CC) or Snowball (XG/Gaimin: fast tempo kills)
- **Reactive counter-drafting** — bots detect the enemy's draft intent (late game / wombo / snowball / push) and switch style to counter it
- **Role gap filling** — bots identify what your team is missing (disabler, initiator, healer) and pick accordingly
- **Wait for human** — bots defer their picks until the human player picks first, then fill the gaps
- **Meta tier list** — patch 7.41 S/A-tier heroes get a scoring bonus

### Macro Strategy
- **Central strategy brain** — picks Aggressive, Defensive, or Split Farm based on net worth, alive counts, Aegis, and tower state
- **Smoke gank coordination** — 3+ bots group up, find an isolated enemy, smoke up, and kill
- **Turbo-aware** — in Turbo mode, bots push harder (0.85), defend less (0.55 cap), farm less (0.35 cap)

### Laning Phase
- **Power spike awareness** — bots know their spike level (Ursa/Axe/Slark at 6, Bristleback at 3, etc.) and press the lane when they hit it
- **Matchup-aware aggression** — reads existing counter data to be aggressive when winning the matchup, passive when losing
- **Camp stacking** — pos4-5 supports walk to a neutral camp at :52 every minute when a core is holding the lane

### Items & Warding
- **Hero-specific Divine Rapier** — only bought by carries and spell-damage cores that actually need it
- **Counter-itemization** — MKB vs evasion, Mjollnir vs illusions, Dust vs invis heroes
- **Pro warding** — Roshan pit, outpost, and enemy farming route ward spots with highest priority

### Identity
- Bot names: **Three Kingdoms heroes** (Cao Cao, Guan Yu, Zhang Fei / Lu Bu, Zhou Yu, Sun Quan...)

---

## Quick Start

1. Clone or download this repo
2. Run `install-symlink.bat` to link scripts into Dota 2
3. Create a **Custom Lobby** with **Local Host** server
4. Start the game — bots auto-pick and play

---

## Configuration

Edit [bots/Customize/general.lua](bots/Customize/general.lua) to configure:

| Setting | Default | Options |
|---|---|---|
| `DraftStyle` | `"auto"` | `"wombo_combo"`, `"snowball"`, `"auto"` |
| `Radiant_Heros` | Random | Set specific heroes per position |
| `Ban` | Empty | Heroes to exclude from bot picks |
| `Allow_Repeated_Heroes` | false | Allow same hero on same team |

**Permanent customization** (survives updates): Copy the `Customize` folder to `<Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/game/Customize>`.

---

## In-Game Commands

| Command | Description |
|---|---|
| `!pos X` | Swap your role with a bot (e.g., `!pos 2` for mid) |
| `!pick HERO` | Pick a hero (`!pick sniper`) |
| `!ban HERO` | Ban a hero from being picked |
| `!sp XX` | Set bot language (`en`, `zh`, `ru`, `ja`) |

---

## Bot Roles & Positioning

Lobby slot order = position assignment (1–5):

| Position | Lane |
|---|---|
| Pos 1 (Carry) + Pos 5 (Hard Support) | Safe Lane |
| Pos 2 (Mid) | Mid Lane |
| Pos 3 (Offlane) + Pos 4 (Soft Support) | Offlane |

---

## Developer Documentation

| Document | Description |
|---|---|
| [CODEBASE_CONTEXT.md](CODEBASE_CONTEXT.md) | All modified/added files with descriptions |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Complete codebase architecture and file map |
| [docs/PATCH_UPDATE_GUIDE.md](docs/PATCH_UPDATE_GUIDE.md) | Step-by-step patch update runbook |
| [CLAUDE.md](CLAUDE.md) | AI coding assistant guide for common tasks |

### Project Structure

```
bots/
├── FunLib/
│   ├── game_strategy.lua       ★ NEW — macro strategy brain (Aggressive/Defensive/Split Farm)
│   ├── draft_style.lua         ★ NEW — pro draft styles + enemy detection
│   ├── laning_pressure.lua     ★ NEW — level spikes, matchup aggression, camp stacking
│   ├── aba_push.lua            ★ Modified — turbo boost + strategy multiplier
│   ├── aba_defend.lua          ★ Modified — turbo cap + strategy multiplier
│   └── aba_ward_utility.lua    ★ Modified — Roshan/outpost/farming route wards
├── mode_laning_generic.lua     ★ Modified — spike-aware desire + general Think()
├── mode_roam_generic.lua       ★ Modified — camp stacking for supports
├── mode_farm_generic.lua       ★ Modified — turbo farm cap + strategy multiplier
├── mode_team_roam_generic.lua  ★ Modified — strategy multiplier + smoke gank
├── hero_selection.lua          ★ Modified — role gaps, wait-for-human, draft style
├── item_purchase_generic.lua   ★ Modified — Rapier whitelist + counter-items
└── Customize/general.lua       ★ Modified — DraftStyle setting + Three Kingdoms names
```

---

## Credits

DeKYet Bot is built on top of the incredible work of:

- **[ryndrb / dota2bot (Tinkering ABout)](https://github.com/ryndrb/dota2bot)** — the current baseline; the `bots/` tree is based on ryndrb's fluid, hand-tuned bot scripts
- **[forest0xia / dota2bot-OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI)** — the original foundation DeKYet started on; many of our strategic modules were first developed against it (MIT License, Copyright 2024 Mingyou Xia)
- **New Beginner AI** ([dota2jmz@163.com](mailto:dota2jmz@163.com))
- **Ranked Matchmaking AI** ([adamqqq](https://github.com/adamqqqplay/dota2ai))
- **fretbots** ([fretmute](https://github.com/fretmute/fretbots))
- **ExtremePush** ([insraq](https://github.com/insraq/dota2bots))
- BOT Experiment (Furiospuppy)
- All other contributors who made Dota 2 bot games better

---

## License

MIT License — see [LICENSE](LICENSE) for full text.

Current baseline: [ryndrb / dota2bot (Tinkering ABout)](https://github.com/ryndrb/dota2bot). Historically built on dota2bot-OpenHyperAI © 2024 Mingyou Xia. DeKYet Bot modifications © 2025–2026 DeKYet Bot Contributors.
