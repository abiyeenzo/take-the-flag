# Take The Flag If You Can

A fast, neon capture the flag game for Roblox. Two teams fight over one arena, grab the enemy flag, and run it back to their own base. Every match earns coins and XP that unlock new classes and trails.

Play it on Roblox: https://www.roblox.com/games/9837048251/Take-The-Flag-If-You-Can

## Features

- **Never play alone.** Bots fill every match up to `Config.BotTargetPlayers` players (humans plus bots). They use made-up usernames, gather in the lobby, play the objectives and shoot with human-like imperfection. They earn no coins, XP or stats and are never saved. As more real players join, bots leave.
- **Lobby and countdown.** Everyone gathers in a glowing lobby between matches. A big sign and HUD countdown run down, then 3, 2, 1, a screen flash, and everybody appears at their team base.
- **Short matches.** Five minutes, first team to 3 captures wins. A tie goes to a sudden death overtime where the next capture wins.
- **Three classes**, each with its own stats and ability:
  - Striker: balanced, Overcharge boosts damage and fire rate.
  - Scout: fast, Dash launches you forward.
  - Guardian: tough, Shield blocks all damage for 3 seconds.
- **Weapons.** Blaster, Pulse SMG, Scatter Cannon, Rail Rifle and the VIP Golden Blaster. Buy them with coins or with Robux.
- **VIP game pass.** Double coins, 25 percent more XP, the Golden Blaster and the Aurora trail.
- **Progression.** Levels, XP, coins, tag streak bonuses and an MVP screen after every match. Scout unlocks at level 3, Guardian at level 5.
- **Shop.** Three tabs: weapons, trails and a Robux store with coin packs and the VIP pass.
- **Tutorial.** New players get five short tips (different wording on phones and tablets).
- **Accessibility settings** (gear button or the G key): reduce flashes, show or hide tutorial tips, large interface, and R / B letters next to team colors. Settings last for the current session only, because Roblox client scripts have no local storage.
- **Phone friendly.** The HUD scales with the screen width, buttons are at least 44 pixels high, and on touch devices the ability button, toolbar and profile bar move away from the thumbstick and the jump button.
- **Family friendly.** Neon laser tag style: no blood, no gore, friendly wording.
- **Server authoritative combat.** The client only sends where it aims. The server checks fire rate, line of sight, teams and damage.
- **Flag carrier pressure.** The carrier is highlighted for everyone, moves slower, and drops the flag on death. A dropped flag returns on its own after 12 seconds, or instantly when a teammate touches it.
- **Procedural arena.** The whole map, lobby, lighting, spawns, cover and jump pads are built by code at startup, so the repository contains no copied assets.
- **Saved progress** with DataStores, autosave and save on leave.

## Controls

| Input | Action |
| --- | --- |
| Left click or tap | Shoot (hold to keep shooting) |
| Q or the ability button | Use class ability |
| C | Class menu |
| B | Shop |
| G | Settings |

## Configuring Robux items

All Robux items live in `src/shared/Monetization.lua`.

1. In the Creator Hub, open your experience, then Monetization.
2. Create one game pass (VIP) and one developer product for each entry in `Monetization.Products` (three coin packs and three weapons).
3. Paste each numeric id into the `Id` field of the matching entry.
4. Publish. The `Robux` value in the file is only the price shown in the shop; the real price is the one set in the Creator Hub.

An entry with `Id = 0` is shown as "Soon" and cannot be bought. Purchases are handled by `MonetizationService` on the server and are idempotent: each receipt is stored in the player's profile and the purchase is only confirmed after the data is saved.

Bots and lobby timing are tuned in `src/shared/Config.lua` (`BotTargetPlayers`, `CountdownSeconds`, `IntermissionTime`).

## Project layout

```
src/
  shared/    config, classes, weapons, monetization, cosmetics, remote events
  server/
    Main.server.lua      starts every service
    Services/            map, bots, teams, flags, combat, classes, rounds, data, shop, purchases
  client/    HUD, menus, settings, tutorial, shooting, ability effects
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
