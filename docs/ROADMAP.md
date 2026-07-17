# Hungry Snake — Progression, UI & Monetization Roadmap

Status: **planning** (agreed 2026-07-16). Build in stages; each stage ships and is
verifiable on its own.

## Decisions (locked)

- **Platform:** Desktop, Linux/snap (same track as sibling KTechpit apps). No ads.
- **Monetization:** *Cosmetic store + earnable currency.* The game is 100% free and
  fully playable. Currency is earned by playing; every cosmetic is unlockable for
  free. One **optional** one-time "Supporter" purchase lets impatient players skip
  the grind and thanks the dev — it grants coins + a couple of exclusive cosmetics,
  never a gameplay advantage. **Not pay-to-play, no dark patterns, no nag popups.**
- **Scoring:** Keep the classic core (`score` = apples, +1 each, speed ramps).
  Add a *meta-progression* layer on top: coins, achievements, a daily challenge,
  lifetime stats, and cosmetic unlocks. Single-run rules are unchanged.

## Guardrails

- Gameplay parity: normal runs play exactly as today. Nothing purchasable changes
  hitboxes, speed, board size, or scoring.
- Everything cosmetic is earnable in a reasonable amount of play (coin economy
  tuned so a dedicated free player unlocks the catalogue).
- One gentle "Support the dev" entry point (Store header + About). No interstitials.
- All new persisted state is versioned and migration-safe.

---

## 1. Currency & economy

- **Coins** 🪙 — the soft currency (name themed to the jungle; distinct from apples,
  which stay the score). Tunable.
- **Earn (free):**
  - Per run: `coins = score` (1 per apple) `+ newBestBonus` (e.g. +5 on a new best).
  - Daily challenge completion: flat reward + streak multiplier.
  - Achievement payouts (one-time each).
- **Spend:** cosmetics only, in the Store.
- **Optional buy:** Supporter unlock → a coin bundle + exclusive Supporter cosmetics
  (and optionally "unlock everything now"). Purely a shortcut + thank-you.

## 2. Meta progression

- **Achievements** — data-driven list, each with a predicate over run/lifetime stats
  and a one-time coin payout. Seed set: First Bite (1 apple), Sweet Tooth (50
  lifetime), Century (score 100 in a run), Long Boi (length N), Marathoner (X games),
  Daily Devotee (7-day streak), Completionist (own all cosmetics).
- **Daily Challenge** — deterministic from the date: a fixed apple seed + one modifier
  (e.g. brisker speed, or a target "reach score N"). One attempt tracked per day;
  completing it advances a **streak** and pays coins (streak-scaled).
- **Lifetime stats / profile** — games played, total apples, longest length, best
  score, total coins earned, current & best daily streak.

## 3. Cosmetics (data-driven, gameplay-neutral)

Slots, each with a catalogue of variants (id, name, price, unlock rule, `supporterOnly`):

- **Snake skin** — a palette set `{headGreen, snakeLight, snakeDark, snakeNose,
  snoutCap, eye tint}`. `Board.qml` reads the *equipped* skin, not `Theme` constants.
- **Board theme** — tile palette `{tileA, tileB, tileGap, frame, frameHi}`.
- **Apple / food** — fruit colour + leaf (apple, cherry, blueberry…).
- **Trophy** — the best-score icon variant.
- **Background** — jungle vs. alt scenes (optional, later).

Refactor: introduce a `Cosmetics` singleton (or a `Profile`-owned object) that exposes
the *currently equipped* palette per slot; `Board.qml` and the HUD bind to it. Default
(free) skin = the current look, so nothing regresses.

## 4. UI / navigation

Introduce a lightweight **screen router** — `win.screen` ∈
`{home, game, store, achievements, daily, settings, about}` with a small back-stack
(wire the existing unused `back` icon). Overlays become screens rather than ad-hoc
bindings.

- **Home hub** (new) — title, big **Play**, plus Store / Achievements / Daily /
  Settings / Supporter. Becomes the landing screen; quick "tap to start" replay stays.
- **Store** — a `SegmentedControl` of slots, a grid of `StoreCard`s (preview + price /
  Owned / Equip), coin balance in the header.
- **Achievements** — list with `ProgressBar`s; claim buttons for unclaimed payouts.
- **Daily** — today's modifier/target, reward, streak, Play.
- **Settings** — existing sound/music/track **+ dark-mode toggle** (wire sun/moon) and
  reduced-motion.
- **Game Over** (enhanced) — coins-earned tally with a count-up, new-best flag,
  achievement `Toast`s, and Home / Restart / Continue.
- **Pause** — current settings-as-pause + a Home button.
- **About / Supporter** — credits + the single Supporter CTA.

### Widget kit additions (`components/`)

- Promote inline `StatCard` and `ToggleRow` to real components.
- New: `CoinBalance` (berry icon + count), `StoreCard`, `ProgressBar`,
  `SegmentedControl`/`Tab`, `ScreenHeader` (title + back), `Toast`, `Badge`.
- **Icon** — add: berry/coin, store/bag, medal, calendar, lock, check, gear, heart,
  home, chevron, sparkle; wire the already-defined `sun`/`moon`/`back`/`home`.
- **Theme** — add store/locked/owned + coin-gold tokens; restructure into
  **light/dark palettes** so the dark-mode toggle has something to switch.

## 5. Persistence & architecture

- New **`Profile : QObject` (QML_ELEMENT, QSettings-backed)** — the single source of
  truth for money/meta so list-state and atomic grants are robust (better than QML
  `Settings` aliases for sets):
  - `coins`, `ownedCosmetics` (set), `equipped` (per-slot), `achievements`
    (unlocked/claimed), `dailyLast`, `dailyStreak`/`bestStreak`, lifetime `stats`,
    `supporterUnlocked`, `schemaVersion`.
  - `Q_INVOKABLE`: `grant(coins)`, `buy(id)`, `equip(slot,id)`, `claim(ach)`,
    `recordRun(summary)`, `startDailyIfDue()`.
- **`SnakeGame`** — on `died()`, expose a run summary (apples, length, isNewBest);
  add an optional `startDaily(seed, modifier)` that only sets seed/speed — normal
  `start()` is untouched. RNG already seeds the apple; make the seed injectable.
- Keep the existing QML `Settings` for sound/music/dark toggles; Profile owns the
  rest. Both under the `HungrySnake` category.

## 6. Monetization wiring (desktop)

- Reuse the sibling **AccountAndLicense** module (deferred in the original build plan)
  for the one-time **Supporter** unlock. Free build stays fully playable; purchase
  sets `Profile.supporterUnlocked` → grants the coin bundle + exclusive skins (and
  optional unlock-all).
- No ads, no consumable IAP storefront on desktop — a single durable unlock.

---

## Build stages

Each stage is independently shippable & testable (headless `SN_SHOT`/`SN_MODE` +
manual play).

- **Stage 1 — Currency + Profile.** `Profile` C++ type + QSettings; coins earned per
  run; coin balance in HUD; coins-earned tally on Game Over. No store yet.
- **Stage 2 — Widget kit + Theme tokens + icons.** Promote StatCard/ToggleRow; add
  CoinBalance/StoreCard/ProgressBar/SegmentedControl/ScreenHeader/Toast/Badge; new
  icons; Theme light/dark token split.
- **Stage 3 — Screen router + Home hub.** `win.screen` + back-stack; Home landing;
  rework overlays into screens.
- **Stage 4 — Cosmetics.** Data model + `Cosmetics` equipped singleton; refactor
  `Board.qml`/HUD to read equipped palettes; Store screen (browse / unlock / equip).
- **Stage 5 — Achievements + Daily + streaks.** Predicate engine, daily seed/modifier,
  Game-Over toasts, stats/profile view.
- **Stage 6 — Dark mode + settings expansion.** Wire sun/moon; reduced-motion.
- **Stage 7 — Supporter unlock + About/Credits.** AccountAndLicense integration.
- **Stage 8 — Balance & packaging.** Economy tuning; snap metainfo/desktop polish.

## Open questions (for later stages, not blocking)

- Coin earn/price tuning (how many runs ≈ one skin).
- Daily modifier set (which modifiers feel fair).
- Whether Supporter "unlocks everything" or just grants a generous bundle + exclusives.
- Currency name (Coins vs. Coins vs. Seeds).
