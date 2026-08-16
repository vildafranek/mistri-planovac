-- ============================================================
--  MISTŘI SVĚTA — plánovač natáčení
--  Kompletní SQL skript pro Supabase
--  Použití: Supabase → SQL Editor → New query → vložit celé → RUN
--  Skript je idempotentní, jde ho pustit opakovaně.
-- ============================================================

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- 1) ČLENOVÉ (4 moderátoři + studio + operátor streamu)
-- ------------------------------------------------------------
create table if not exists public.members (
  id         text primary key,                 -- 'vilem', 'radek', ...
  name       text not null,
  email      text,
  color      text not null default '#888888',
  role       text not null default 'moderator' check (role in ('moderator','studio','operator')),
  sort_order int  not null default 0,
  created_at timestamptz not null default now()
);

-- Pokud tabulka vznikla dřív, doplň novou roli 'operator' do omezení
alter table public.members drop constraint if exists members_role_check;
alter table public.members add  constraint members_role_check
  check (role in ('moderator','studio','operator'));

insert into public.members (id, name, email, color, role, sort_order) values
  ('vilem',    'Vilém Franěk',      'franek@closefriends.cz',      '#E8321A', 'moderator', 1),
  ('radek',    'Radek Duda',        'duda69@centrum.cz',           '#1B8CD6', 'moderator', 2),
  ('jiri',     'Jiří Tlustý',       'jiritlusty11@gmail.com',      '#F5A623', 'moderator', 3),
  ('honza',    'Honza Homolka',     'jan.homolka@oneplaysport.cz', '#2ECC71', 'moderator', 4),
  ('studio',   'Studio',            null,                          '#9B59B6', 'studio',    5),
  ('operator', 'Honza Vosecký',     'fhillnash@gmail.com',         '#00C2CB', 'operator',  6)
on conflict (id) do update set
  name       = excluded.name,
  email      = excluded.email,
  color      = excluded.color,
  role       = excluded.role,
  sort_order = excluded.sort_order;

-- ------------------------------------------------------------
-- 2) DOSTUPNOST
--    Jedna řádka = jeden člověk + jeden den + jedna hodina.
--    'day' je čisté datum a 'hour' celá hodina 0–23 v čase Europe/Prague,
--    takže nikde nevzniká posun časových zón.
-- ------------------------------------------------------------
create table if not exists public.availability (
  id         bigserial primary key,
  member_id  text not null references public.members(id) on delete cascade,
  day        date not null,
  hour       int  not null check (hour between 0 and 23),
  mode       text not null default 'remote' check (mode in ('remote','studio')),
  updated_at timestamptz not null default now(),
  unique (member_id, day, hour)
);

create index if not exists availability_day_idx        on public.availability (day);
create index if not exists availability_member_day_idx on public.availability (member_id, day);

-- ------------------------------------------------------------
-- 3) "MÁM VYPLNĚNO" pro daný týden
--    week_start = pondělí daného týdne (datum)
-- ------------------------------------------------------------
create table if not exists public.week_status (
  member_id  text not null references public.members(id) on delete cascade,
  week_start date not null,
  done       boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (member_id, week_start)
);

-- ------------------------------------------------------------
-- 4) HOSTÉ
-- ------------------------------------------------------------
create table if not exists public.guests (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  email      text,
  note       text,
  token      text not null unique,             -- do odkazu ?guest=TOKEN
  status     text not null default 'open' check (status in ('open','done','cancelled')),
  created_by text references public.members(id),
  created_at timestamptz not null default now()
);

create index if not exists guests_token_idx on public.guests (token);

-- ------------------------------------------------------------
-- 5) MOŽNOSTI, KTERÉ ZADÁ HOST
--    start_min = minuty od půlnoci (např. 9:30 → 570)
-- ------------------------------------------------------------
create table if not exists public.guest_options (
  id           uuid primary key default gen_random_uuid(),
  guest_id     uuid not null references public.guests(id) on delete cascade,
  day          date not null,
  start_min    int  not null check (start_min between 0 and 1439),
  duration_min int  not null default 90 check (duration_min between 15 and 480),
  studio_ok    boolean not null default false,
  note         text,
  created_at   timestamptz not null default now()
);

create index if not exists guest_options_guest_idx on public.guest_options (guest_id);

-- ------------------------------------------------------------
-- 6) NAHLÁŠENÍ MODERÁTORŮ K HOSTOVÝM MOŽNOSTEM
-- ------------------------------------------------------------
create table if not exists public.guest_rsvps (
  id         bigserial primary key,
  option_id  uuid not null references public.guest_options(id) on delete cascade,
  member_id  text not null references public.members(id) on delete cascade,
  answer     text not null check (answer in ('yes','no')),
  updated_at timestamptz not null default now(),
  unique (option_id, member_id)
);

-- ------------------------------------------------------------
-- 7) TERMÍNY NATÁČENÍ
--    "kandidát" se do DB neukládá – počítá se z dostupnosti.
--    Do DB se zapisuje až potvrzený termín.
-- ------------------------------------------------------------
create table if not exists public.sessions (
  id                uuid primary key default gen_random_uuid(),
  day               date not null,
  start_min         int  not null check (start_min between 0 and 1439),
  duration_min      int  not null default 90 check (duration_min between 15 and 480),
  kind              text not null default 'call' check (kind in ('call','studio','guest')),
  status            text not null default 'confirmed' check (status in ('confirmed','booked','cancelled')),
  episodes          int  not null default 1 check (episodes between 1 and 10),
  participants      text[] not null default '{}',   -- id moderátorů, kteří na termín dorazí
  title             text,                            -- název události v kalendáři (zadá se před odesláním pozvánky)
  guest_id          uuid references public.guests(id) on delete set null,
  note              text,
  confirmed_by      text references public.members(id),
  confirmed_at      timestamptz,
  booked_by         text references public.members(id),
  booked_at         timestamptz,
  cancelled_by      text references public.members(id),
  cancelled_at      timestamptz,
  calendar_event_id text,
  calendar_link     text,
  created_at        timestamptz not null default now()
);

-- Pokud tabulka vznikla dřív, doplň novější sloupce
alter table public.sessions add column if not exists participants text[] not null default '{}';
alter table public.sessions add column if not exists title text;

create index if not exists sessions_day_idx on public.sessions (day);

-- Jeden aktivní termín na stejné datum + čas (ochrana proti dvojímu potvrzení)
create unique index if not exists sessions_unique_slot
  on public.sessions (day, start_min)
  where status <> 'cancelled';

-- ------------------------------------------------------------
-- 8) RLS (Row Level Security)
--    Appka běží jen s anon klíčem (žádné přihlašování do Supabase),
--    proto anon potřebuje čtení i zápis. Data nejsou citlivá.
--    'members' je pro anon záměrně jen ke čtení – seznam lidí se
--    mění výhradně v tomto SQL skriptu.
-- ------------------------------------------------------------
alter table public.members       enable row level security;
alter table public.availability  enable row level security;
alter table public.week_status   enable row level security;
alter table public.guests        enable row level security;
alter table public.guest_options enable row level security;
alter table public.guest_rsvps   enable row level security;
alter table public.sessions      enable row level security;

-- members: pouze čtení
drop policy if exists members_read on public.members;
create policy members_read on public.members
  for select to anon, authenticated using (true);

-- ostatní tabulky: plný přístup pro anon (appka nemá vlastní auth)
do $$
declare t text;
begin
  foreach t in array array['availability','week_status','guests','guest_options','guest_rsvps','sessions']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_anon_read',   t);
    execute format('drop policy if exists %I on public.%I', t || '_anon_write',  t);
    execute format('drop policy if exists %I on public.%I', t || '_anon_update', t);
    execute format('drop policy if exists %I on public.%I', t || '_anon_delete', t);

    execute format('create policy %I on public.%I for select to anon, authenticated using (true)',
                   t || '_anon_read', t);
    execute format('create policy %I on public.%I for insert to anon, authenticated with check (true)',
                   t || '_anon_write', t);
    execute format('create policy %I on public.%I for update to anon, authenticated using (true) with check (true)',
                   t || '_anon_update', t);
    execute format('create policy %I on public.%I for delete to anon, authenticated using (true)',
                   t || '_anon_delete', t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 9) Kontrola – po spuštění by tu mělo být 5 řádků
-- ------------------------------------------------------------
select id, name, role, color from public.members order by sort_order;
