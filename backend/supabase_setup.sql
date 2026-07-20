-- Hungry Snake — global leaderboard schema for Supabase (Postgres).
-- Paste this whole file into the Supabase SQL editor and run it once.
--
-- Design: one row per player (keyed on the client's random player_uuid), upserted on
-- each new personal best. Row Level Security lets the anonymous key read everyone and
-- write only its own row, with sanity caps; a trigger makes scores monotonic (an
-- upsert can never LOWER a player's score) — the basic, no-server anti-cheat layer.

create table if not exists public.scores (
    player_uuid uuid        primary key,
    nickname    text        not null check (char_length(nickname) between 1 and 16),
    score       integer     not null check (score >= 0 and score <= 100000),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

create index if not exists scores_score_idx on public.scores (score desc);

-- Keep the stored score as the player's MAX and stamp updated_at on every upsert.
create or replace function public.keep_max_score() returns trigger as $$
begin
    if new.score < old.score then
        new.score := old.score;
    end if;
    new.updated_at := now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists scores_keep_max on public.scores;
create trigger scores_keep_max before update on public.scores
    for each row execute function public.keep_max_score();

-- The anon role (the public API key) needs table privileges; RLS still gates the rows.
grant select, insert, update on public.scores to anon;

alter table public.scores enable row level security;

drop policy if exists "scores read all"   on public.scores;
drop policy if exists "scores insert any" on public.scores;
drop policy if exists "scores update any" on public.scores;

-- Anyone may read the whole board.
create policy "scores read all" on public.scores
    for select to anon using (true);

-- Anyone may insert a row within the sanity caps (client sends its own player_uuid).
-- Minimum score 10 to qualify for the board (matches Leaderboard::MinScore).
create policy "scores insert any" on public.scores
    for insert to anon
    with check (char_length(nickname) between 1 and 16
                and score >= 10 and score <= 100000);

-- Updates are allowed within caps; the keep_max_score trigger prevents lowering.
create policy "scores update any" on public.scores
    for update to anon
    using (true)
    with check (char_length(nickname) between 1 and 16
                and score >= 10 and score <= 100000);
