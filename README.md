<p align="center">
  <img src="https://raw.githubusercontent.com/keshavbhatt/hungrysnake-packaging/main/banner.png" alt="Hungry Snake: a classic arcade snake game for Linux" width="100%">
</p>

<p align="center">
  A classic snake game for Linux with a bright, cartoon arcade look. Guide a cute snake
  around a wooden board, eat apples, grow longer and don't bite your own tail. Smooth
  movement, snake skins, animated scenes, daily challenges and an online leaderboard.
  Free, open source and ad-free, built with Qt&nbsp;6.
</p>

<p align="center">
  <a href="https://snapcraft.io/hungrysnake"><img src="https://snapcraft.io/static/images/badges/en/snap-store-black.svg" alt="Get it from the Snap Store" height="56"></a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/keshavbhatt/hungrysnake-packaging/main/screenshots/02-play.png" alt="A Hungry Snake run on the jungle board" width="100%">
</p>

## Install

**Snap**:

```sh
sudo snap install hungrysnake
```

## Features

**Play**
- The snake glides smoothly between cells instead of snapping, and turns are buffered so
  quick key presses are never lost.
- A run starts only when you steer, and the speed climbs gently and announces each step,
  so even a very long snake stays in control.
- Bonus food: a golden star for extra points and a mint leaf that trims your tail when you
  are boxed in.
- A cute, expressive snake that blinks, flicks its tongue and watches the apple.

**Unlock and customize**
- Earn Coins just by playing and spend them in the Store on snake skins, board themes,
  apple styles and bonus food looks.
- Six animated background scenes: jungle, sunset, twilight, ember, snowfall and aurora,
  each with its own drifting atmosphere and scenery.
- Scene-matched snakes, boards and apples that combine into one coordinated look.
- Every standard cosmetic unlocks by playing; an optional Supporter Pack adds a few
  exclusive extras.

**Challenges and leaderboard**
- A new Daily Challenge every day, with a streak to keep alive.
- Achievements that pay out Coins for lifetime and single-run milestones.
- An opt-in online leaderboard: pick a nickname, post your high score and see your global
  rank on the home screen.

**Made for the desktop**
- Six relaxing music tracks, crunchy sound effects and an optional key-press sound, each
  with its own toggle.
- Fullscreen by default, and a performance mode for older PCs and laptops.
- Offline gameplay with no account needed; the leaderboard is the only online part.
- Native Wayland and X11.

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="https://raw.githubusercontent.com/keshavbhatt/hungrysnake-packaging/main/screenshots/01-home.png" alt="The home screen"></td>
    <td width="50%"><img src="https://raw.githubusercontent.com/keshavbhatt/hungrysnake-packaging/main/screenshots/03-store.png" alt="The Store with snake skins, boards and apples"></td>
  </tr>
  <tr>
    <td width="50%"><img src="https://raw.githubusercontent.com/keshavbhatt/hungrysnake-packaging/main/screenshots/04-daily.png" alt="The Daily Challenge"></td>
    <td width="50%"><img src="https://raw.githubusercontent.com/keshavbhatt/hungrysnake-packaging/main/screenshots/05-achievements.png" alt="Achievements"></td>
  </tr>
</table>

## Controls

| Key | Action |
|---|---|
| Arrow keys or WASD | Steer |
| Space | Start from the home screen, pause a run, Play Again after Game Over |
| Enter | Start or restart |
| Esc | Back, close a dialog, pause |
| F11 | Toggle fullscreen |
| Ctrl+Q | Quit |

## Building

Hungry Snake is a Qt 6 Quick (QML) and C++20 game built with CMake. It needs Qt 6.5 or
newer (developed against 6.10) with Quick, QuickControls2, Svg, Multimedia, Network and
QtQuick.Shapes.

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/bin/hungrysnake
```

The leaderboard's Supabase URL and public (anon) key are baked in at build time. Override
them with `-DSN_SUPABASE_URL=... -DSN_SUPABASE_ANON_KEY=...`, or leave them empty to get
an offline mock leaderboard. `backend/supabase_setup.sql` sets up your own backend.

To build the snap, run `snapcraft`. It takes its summary, description and licence from
`packaging/com.ktechpit.hungrysnake.metainfo.xml`. Store art (icons, screenshots, banner)
lives in [hungrysnake-packaging](https://github.com/keshavbhatt/hungrysnake-packaging).

### Project layout

```
CMakeLists.txt           project, app id, QML module, baked leaderboard keys
modules/
  AccountAndLicense/     KTechpit account and licence client (static library)
src/
  main.cpp               QGuiApplication and QQmlApplicationEngine, screenshot hooks
  core/
    SnakeGame.*          game logic: grid movement with smooth interpolation, apple and
                         bonus food spawning, stepped speed, score, collisions, 60 Hz clock
    Profile.*            Coins, lifetime stats, owned and equipped cosmetics
    Leaderboard.*        global ranks over Supabase REST, with an offline mock
  licensing/
    LicenseController.*  app glue over AccountAndLicense (Supporter Pack)
  qml/
    Main.qml             window, HUD, screens, dialogs, sound, controls
    Theme.qml            jungle palette singleton
    Board.qml            board, snake, apple and bonus food
    Cosmetics.qml        cosmetics catalogue and equipped palette
    Achievements.qml     achievement definitions and progress
    components/          icons, buttons, cards, particle and scene layers
assets/                  icons, fonts, decor, sounds and music
tools/                   scripts that generate the music, sound effects and foliage
packaging/               .desktop file and AppStream metainfo
snap/                    snapcraft.yaml
```

The C++ types own the state and expose it as properties and signals; QML only draws it.
All geometry is in board cells, scaled to pixels by one QML layer, so the game is
resolution-independent. Cosmetics only change the look, never the gameplay.

### Dev hooks

Environment variables for screenshots and headless checks (ignored unless set):

```sh
# Render a screen to a PNG and quit
SN_SHOT=/tmp/shot.png SN_SCREEN=home SN_SIZE=1920x1080 ./build/bin/hungrysnake

# Capture gameplay: SN_MODE=long grows a snake; SN_LONG_EATS and SN_LONG_DELAY tune it
SN_SHOT=/tmp/play.png SN_MODE=long SN_LONG_EATS=8 ./build/bin/hungrysnake
```

Also `SN_MODE` (ready, waiting, eat, long, over, settings, ...), `SN_DELAY`,
`SN_AUTOPLAY`, and in debug builds only `SN_LICSET=pro|trial|free|neterr` to simulate a
licence state.

### Music and sounds

```sh
python3 tools/make_music.py      # the six tracks in assets/sounds/music/
python3 tools/make_sounds.py     # crash.wav and turn0..4.wav
```

`eat.wav` is our own sound; it is not produced by these scripts.

## Contributing

Bug reports, ideas and pull requests are welcome. For bigger changes, open an
[issue](https://github.com/keshavbhatt/HungrySnake/issues) first so we can agree on the
approach. Contributions to the game are accepted under the GPL; the licensing module is
not open to changes (see below).

## Licence

Open source: GPL-3.0-or-later for the game, the bundled fonts under the SIL Open Font
License 1.1, and the licensing module (account, licence and Supporter Pack verification
code) under the Ktechpit Licensing Module License, which allows reading and building it
but not changing, bypassing or redistributing it. The details, the paths and what this
means for forks are in [LICENSING.md](LICENSING.md).

## Help

Bugs and requests go to the [issues](https://github.com/keshavbhatt/HungrySnake/issues),
or by email to [connect@ktechpit.com](mailto:connect@ktechpit.com).
