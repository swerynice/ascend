-- ASCEND Datenbank: öffentliche Profile (Ranglisten), private Spielstände, Feed.
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  level int not null default 1,
  xp int not null default 0,
  rank text not null default 'E',
  str int not null default 0,
  vit int not null default 0,
  agi int not null default 0,
  dis int not null default 0,
  streak int not null default 0,
  week_key date,
  week_xp int not null default 0,
  rel_strength numeric not null default 0,
  prs jsonb not null default '{}'::jsonb,
  title text,
  updated_at timestamptz not null default now()
);

create table if not exists public.saves (
  id uuid primary key references auth.users on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.feed (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users on delete cascade default auth.uid(),
  username text not null default '',
  kind text not null check (length(kind) <= 20),
  text text not null check (length(text) <= 200),
  created_at timestamptz not null default now()
);
create index if not exists feed_created_idx on public.feed (created_at desc);

alter table public.profiles enable row level security;
alter table public.saves enable row level security;
alter table public.feed enable row level security;

-- Profile: alle Eingeloggten dürfen lesen, jeder nur sein eigenes schreiben.
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Spielstand: nur der Besitzer.
drop policy if exists "saves own" on public.saves;
create policy "saves own" on public.saves for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Feed: alle Eingeloggten lesen, Einträge nur im eigenen Namen.
drop policy if exists "feed read" on public.feed;
create policy "feed read" on public.feed for select to authenticated using (true);
drop policy if exists "feed insert own" on public.feed;
create policy "feed insert own" on public.feed for insert to authenticated with check (user_id = auth.uid());

-- Name im Feed kommt immer aus dem Profil, nicht vom Handy.
create or replace function public.feed_set_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.user_id := auth.uid();
  select username into new.username from public.profiles where id = auth.uid();
  if new.username is null then raise exception 'Kein Profil'; end if;
  return new;
end $$;
drop trigger if exists feed_bi on public.feed;
create trigger feed_bi before insert on public.feed for each row execute function public.feed_set_user();

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.saves to authenticated;
grant select, insert on public.feed to authenticated;
