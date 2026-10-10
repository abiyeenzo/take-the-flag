# Take The Flag If You Can

A fast, neon capture the flag game for Roblox. Two teams fight over one arena, grab the enemy flag, and run it back to their own base. Every match earns coins and XP that unlock new classes and trails.

Play it on Roblox: https://www.roblox.com/games/9837048251/Take-The-Flag-If-You-Can

## Features

- **Short matches.** Five minutes, first team to 3 captures wins. A tie goes to a sudden death overtime where the next capture wins.
- **Three classes**, each with its own stats and ability:
  - Striker: balanced, Overcharge boosts damage and fire rate.
  - Scout: fast, Dash launches you forward.
  - Guardian: tough, Shield blocks all damage for 3 seconds.
- **Progression.** Levels, XP, coins, kill streak bonuses and an MVP screen after every match. Scout unlocks at level 3, Guardian at level 5.
- **Trail shop.** Spend coins on trails that follow you around the arena.
- **Server authoritative combat.** The client only sends where it aims. The server checks fire rate, line of sight, teams and damage.
- **Flag carrier pressure.** The carrier is highlighted for everyone, moves slower, and drops the flag on death. A dropped flag returns on its own after 12 seconds, or instantly when a teammate touches it.
- **Procedural arena.** The whole map, lighting, spawns, cover and jump pads are built by code at startup, so the repository contains no copied assets.
- **Saved progress** with DataStores, autosave and save on leave.

## Controls

| Input | Action |
| --- | --- |
| Left click or tap | Shoot |
| Q or the ability button | Use class ability |
| C | Class menu |
| B | Trail shop |

## Project layout

```
src/
  shared/    config, class definitions, cosmetics, remote events
  server/
    Main.server.lua      starts every service
    Services/            map, teams, flags, combat, classes, rounds, data, shop
  client/    HUD, menus, shooting, ability effects
tools/publish.sh         build and publish through Open Cloud
```

All tuning values (round length, captures to win, rewards, arena size) live in `src/shared/Config.lua`.

## Building

You need [Rojo](https://rojo.space) 7.

```
rojo build default.project.json -o build/TakeTheFlag.rbxl
```

Open the file in Roblox Studio to test. To live sync while editing, run `rojo serve` and connect from the Rojo plugin.

## Publishing without Studio

Create an Open Cloud API key in the Creator Hub with the Place Publishing permission for your experience, then:

```
export ROBLOX_API_KEY=...
export ROBLOX_UNIVERSE_ID=3637415736
export ROBLOX_PLACE_ID=9837048251
tools/publish.sh
```

Use `VERSION_TYPE=Saved` to upload a version without making it live.

## License

MIT, see `LICENSE`.
