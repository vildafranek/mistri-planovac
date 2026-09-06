-- Přidá Jana Vacka (NHL) a Tomáše Vrábela (Maxa liga) jako roli 'extra'
-- (vedlejší pořady — mimo hlavní čtyřku).
-- Supabase → SQL Editor → New query → vložit → Run

alter table public.members drop constraint if exists members_role_check;
alter table public.members add  constraint members_role_check
  check (role in ('moderator','studio','operator','extra'));

insert into public.members (id, name, email, color, role, sort_order) values
  ('vacek',    'Jan Vacek',      null, '#E056A0', 'extra',    5),
  ('vrabel',   'Tomáš Vrábel',   null, '#A0D911', 'extra',    6),
  ('studio',   'Studio',         null, '#9B59B6', 'studio',   7),
  ('operator', 'Honza Vosecký',  'fhillnash@gmail.com', '#00C2CB', 'operator', 8)
on conflict (id) do update set
  name = excluded.name, email = excluded.email, color = excluded.color,
  role = excluded.role, sort_order = excluded.sort_order;

select id, name, role, sort_order from public.members order by sort_order;
