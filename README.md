# Snecko

A smooth, jungle-themed take on the classic **Snake** for the desktop. Guide a
gliding snake around a checkerboard field, eat apples to grow, and don't run
into the walls or your own tail. Your best score is kept between sessions.

Built with **Qt 6 Quick (QML) + C++20 / CMake**, mirroring the sibling
*ArrowEscape* scaffold.

## Architecture

```
CMakeLists.txt          # project, app-id, QML module
src/
  main.cpp              # QGuiApplication + QQmlApplicationEngine (SN_SHOT / SN_AUTOPLAY hooks)
  AppInfo.h.in          # configured app-id / name / version
  core/
    SnakeGame.*         # all game logic: grid-locked movement (one cell/tick,
                        #   4 directions, no 180° reversal) with smooth visual
                        #   interpolation between cells, apple spawning,
                        #   score/best, wall + self collision, ~60 Hz QTimer clock
  qml/
    Main.qml            # window, HUD (apple + trophy), controls, overlays, sound
    Theme.qml           # jungle palette singleton
    Board.qml           # checkerboard field + Shapes snake body + head + apple
    components/         # Icon, IconButton, PillButton
assets/
  icons/                # app icon (SVG)
  sounds/               # eat / crash (generated PCM WAV — see tools/make_sounds.py)
packaging/              # .desktop
```

**Design choices**

- **Grid-locked movement, smooth visuals**: the snake moves one cell per tick in
  four directions (turns only on cell boundaries; a direct reversal into the neck
  is ignored), but a `progress` fraction leads the head forward and retracts the
  tail so it *glides* between cells instead of snapping.
- **C++ core, QML render** — `SnakeGame` (registered via `QML_ELEMENT`) owns the
  whole simulation and exposes it as properties + signals; QML just draws it. The
  body is a chain of overlapping circles sampled along the smooth head→tail
  polyline, giving a green→teal gradient and a tapering tail for free.
- **World units** — all geometry is in "cells"; a scaled QML layer maps one cell
  to pixels, so the sim is resolution-independent.

## Controls

- **Arrow keys** or **WASD** — steer.
- **Space** — start; during a run, **pause and open Settings** (a pause menu).
- **Space / Esc** — resume (close Settings). **Enter** — start / restart.
- **Menu button** (top-right) — open **Settings** (Sound, Restart).

## Build & run

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/bin/snecko
```

Requires Qt ≥ 6.5 (developed against 6.10) with `Quick`, `QuickControls2`,
`Svg`, `Multimedia`, and `QtQuick.Shapes`.

## Dev hooks (headless verification)

```sh
# Render a mid-game frame to a PNG and quit
SN_SHOT=/tmp/shot.png ./build/bin/snecko

# Auto-steer toward the apple and save a numbered filmstrip
SN_AUTOPLAY=/tmp/frames ./build/bin/snecko
```

## Regenerating sounds

```sh
python3 tools/make_sounds.py     # rewrites assets/sounds/{eat,crash}.wav
```

## Deferred (planned, structured to drop in like ArrowEscape)

Pro/trial licensing + Upgrade dialog, Settings/About dialogs, snap packaging +
AppStream metainfo, and background music.
