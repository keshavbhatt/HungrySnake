# Global Leaderboard

A hosted global leaderboard (top scores across all players). The game talks to a
**Supabase** table over plain REST via `QtNetwork`. With no backend configured it runs
in **mock mode** against a seeded demo board, so the whole flow works offline.

## Pieces

- `src/core/Leaderboard.{h,cpp}` — the client. Manages the player's anonymous identity
  (a random `playerId` uuid + a chosen `nickname`, persisted in QSettings group
  `[leaderboard]`), fetches the top scores, and upserts the player's best.
- Leaderboard screen + "Ranks" home tile in `Main.qml`. A new personal best is
  auto-submitted on death (once a nickname is set).
- `backend/supabase_setup.sql` — the table, indexes, sanity caps, monotonic-score
  trigger, and Row Level Security policies.
- `.github/workflows/leaderboard-keepalive.yml` — pings the API every 3 days so the
  free Supabase project doesn't pause on inactivity.

## Mock vs live

The client is **live** when both a URL and an anon key are present; otherwise it's
**mock** (the `demo` badge shows on the Ranks screen). Config precedence:

1. Environment: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
2. QSettings `[leaderboard]` keys `url`, `anonKey`

## Going live

1. Create a free Supabase project.
2. SQL editor → paste and run `backend/supabase_setup.sql`.
3. Project settings → API → copy the **Project URL** and the **anon/public** key.
   (The anon key is meant to ship in the client — security is enforced by the RLS
   policies, not by hiding the key.)
4. Point the game at it, either:
   - export `SUPABASE_URL` / `SUPABASE_ANON_KEY` before launch, or
   - add `url=` and `anonKey=` under `[leaderboard]` in the config file
     (`~/.config/ktechpit/Hungry Snake.conf`).
5. Add the same two values as GitHub repo secrets so the keep-alive Action can run.

## Anti-cheat (basic)

RLS enforces a qualifying range (score 10–100000, matching `Leaderboard::MinScore`)
and nickname length server-side, and the `keep_max_score` trigger means an upsert can
only ever raise a player's score. This stops casual tampering and keeps trivial runs
off the board. It does **not** stop a determined client from posting a fake in-range score;
that would need run-replay verification (seed + input log), deliberately out of scope.
