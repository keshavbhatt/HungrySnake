# Hungry Snake

A smooth, jungle-themed take on the classic **Snake** for the desktop. Guide a
gliding cartoon snake around a wooden board, eat apples to grow, and don't run
into the walls or your own tail. Earn Coins as you play and spend them on a deep
catalogue of cosmetics; chase a Daily Challenge, collect Achievements, and post
your best to a global leaderboard.

Built with **Qt 6 Quick (QML) + C++20 / CMake**, mirroring the sibling
*ArrowEscape* scaffold. Ships as a strictly-confined snap.

## Features

- **Smooth, glide-between-cells movement** — the snake moves one cell per tick in
  four directions (turns buffered; a direct reversal into the neck is ignored),
  with a `progress` fraction that leads the head and retracts the tail so it
  *glides* rather than snaps. Expressive head: blinks, flicks its tongue, watches
  the apple.
- **Gentle, announced difficulty ramp** — speed climbs slowly and toasts each
  step, so long runs stay controllable.
- **Timed bonus foods** — a golden **star** (extra points) and a mint **leaf**
  (trims your tail when you're boxed in), on top of the regular apple.
- **Store & Coins** — earn Coins just by playing, then buy cosmetics across five
  slots: **snake skins, board themes, apple styles, bonus-food looks and animated
  background scenes**. Many items are colour-matched so you can assemble one
  coordinated look.
- **Six hand-crafted scenes** — jungle, sunset, twilight, ember, snowfall and
  aurora, each with its own drifting atmosphere (fireflies, motes, stars, embers,
  snow, aurora) and bespoke static scenery drawn behind the board.
- **Daily Challenge** with a streak, and **Achievements** that pay out Coins on
  lifetime and single-run milestones.
- **Opt-in global leaderboard** — pick a nickname, post your best, and see your
  worldwide rank (shown persistently on the home hub).
- **Audio** — six looping soundtracks, crunchy eat/crash effects, and an optional
  per-turn blip; each independently toggleable.
- **Supporter Pack** — an optional purchase (verified by the KTechpit licence
  backend) that unlocks a handful of exclusive cosmetics. Every *standard*
  cosmetic is earnable by playing; the game has no ads.
- **Always fullscreen**, with a **performance mode** that drops the animated
  decoration for older machines.

## Architecture

```
CMakeLists.txt          # project, app-id, QML module, baked leaderboard keys
modules/
  AccountAndLicense/    # reusable KTechpit account/licence client (static lib)
src/
  main.cpp              # QGuiApplication + QQmlApplicationEngine (screenshot hooks)
  AppInfo.h.in          # configured app-id / name / version
  LeaderboardConfig.h.in# baked-in Supabase URL + anon key (build time)
  core/
    SnakeGame.*         # all game logic: grid-locked movement with smooth visual
                        #   interpolation, apple + bonus-food spawning, stepped
                        #   speed, score/best, wall + self collision, ~60 Hz clock
    Profile.*           # persistent Coins, lifetime stats, owned/equipped cosmetics
    Leaderboard.*       # global ranks over Supabase REST (mock fallback offline)
  licensing/
    LicenseController.* # app glue over AccountAndLicense (Supporter Pack)
  qml/
    Main.qml            # window, HUD, screens, dialogs, sound, controls
    Theme.qml           # jungle palette singleton
    Board.qml           # checkerboard field + snake body + head + apple/bonus
    Cosmetics.qml       # cosmetics catalogue + equipped-palette resolver
    Achievements.qml    # achievement definitions + progress
    components/         # Icon, buttons, cards, particle/scene layers, ...
assets/
  icons/  fonts/  decor/
  sounds/               # eat (recording) + crash/turn* (generated) + music/
packaging/              # .desktop + AppStream metainfo
snap/                   # snapcraft.yaml (kde-neon-6, strict confinement)
```

**Design notes**

- **C++ core, QML render** — `SnakeGame`, `Profile` and `Leaderboard` are
  `QML_ELEMENT` types; `LicenseController` is a QML singleton; `Cosmetics` and
  `Achievements` are QML objects; `Theme` is a `pragma Singleton`. The C++ owns
  state and exposes it as properties + signals; QML just draws it.
- **World units** — all geometry is in "cells"; a scaled QML layer maps one cell
  to pixels, so the sim is resolution-independent.
- **Cosmetics are gameplay-neutral** — skins only restyle; the bonus foods
  themselves are always available to everyone (only their *look* is a purchase).

## Controls

- **Arrow keys** / **WASD** — steer.
- **Space** — start from the home screen; **pause** during a run; **Play Again**
  on the Game Over card.
- **Enter** — start / restart. **Esc** — back / close dialog / pause.
- **F11** — toggle fullscreen for the session (the game always launches
  fullscreen). **Ctrl+Q** — quit (also a Quit tile on the home screen).

## Build & run

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/bin/hungrysnake
```

Requires Qt ≥ 6.5 (developed against 6.10) with `Quick`, `QuickControls2`,
`Svg`, `Multimedia`, `Network`, and `QtQuick.Shapes`.

The leaderboard's Supabase URL + anon key are baked in at build time; override
per-build with `-DSN_SUPABASE_URL=... -DSN_SUPABASE_ANON_KEY=...` (empty ⇒ the
offline mock board).

## Dev hooks (headless verification)

Debug/screenshot helpers read from the environment (inert unless set):

```sh
# Render a screen to a PNG and quit
SN_SHOT=/tmp/shot.png SN_SCREEN=home SN_SIZE=1920x1080 ./build/bin/hungrysnake

# Capture gameplay: SN_MODE=long grows a snake; SN_LONG_EATS / SN_LONG_DELAY tune it
SN_SHOT=/tmp/play.png SN_MODE=long SN_LONG_EATS=8 ./build/bin/hungrysnake
```

Other hooks: `SN_MODE` (ready/waiting/eat/long/over/settings/…), `SN_DELAY`,
`SN_AUTOPLAY`, and — in **debug builds only** — `SN_LICSET=pro|trial|free|neterr`
to simulate a licence tier.

## Regenerating sounds

```sh
python3 tools/make_sounds.py     # rewrites crash.wav + turn0..4.wav
```

`eat.wav` and the six music tracks under `assets/sounds/music/` are shipped
recordings — they are **not** generated by the script.

## Packaging

```sh
snapcraft            # builds the strictly-confined snap
```

The snap adopts its summary/description/licence from
`packaging/com.ktechpit.hungrysnake.metainfo.xml` (via `parse-info`). Store
assets (icons, screenshots, banner) live in the separate
[`hungrysnake-packaging`](https://github.com/keshavbhatt/hungrysnake-packaging)
repository.
