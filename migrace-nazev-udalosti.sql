-- Doplní sloupec pro název události v kalendáři.
-- Supabase → SQL Editor → New query → vložit → Run
alter table public.sessions add column if not exists title text;
