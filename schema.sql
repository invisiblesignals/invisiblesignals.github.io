-- Telefone sem Fio: one table, anyone can read and add, nobody can edit or delete through the public key.
-- The ladder answer (q1) is never readable row by row: only counts, and per country only with 5+ answers.
create table if not exists public.pontos (
  id    text primary key check (char_length(id) between 8 and 64),
  code  text not null unique check (code ~ '^[a-z0-9]{4,12}$'),
  ref   text check (ref is null or ref ~ '^[a-z0-9]{4,12}$'),
  place text not null check (char_length(place) between 1 and 80),
  cc    text check (cc is null or cc ~ '^[A-Z]{2}$'),
  lat   double precision not null check (lat between -90 and 90),
  lon   double precision not null check (lon between -180 and 180),
  msg   text not null check (char_length(msg) between 3 and 280),
  mode  text not null check (mode in ('igual', 'recontada', 'nova')),
  q1    smallint check (q1 between 0 and 10),
  lang  text check (lang in ('pt', 'en', 'fr', 'es', 'it')),
  at    timestamptz not null default now()
);
alter table public.pontos enable row level security;
drop policy if exists "anyone reads" on public.pontos;
drop policy if exists "anyone adds" on public.pontos;
create policy "anyone reads" on public.pontos for select to anon, authenticated using (true);
create policy "anyone adds" on public.pontos for insert to anon, authenticated with check (true);
revoke all on public.pontos from anon, authenticated;
grant select (id, code, ref, place, cc, lat, lon, msg, mode, lang, at) on public.pontos to anon, authenticated;
grant insert (id, code, ref, place, cc, lat, lon, msg, mode, q1, lang) on public.pontos to anon, authenticated;

create or replace function public.ladder_counts()
returns table (cc text, q1 smallint, n bigint)
language sql stable security definer set search_path = public as $$
  select '*'::text, p.q1, count(*) from public.pontos p where p.q1 is not null group by p.q1
  union all
  select p.cc, p.q1, count(*) from public.pontos p
  where p.q1 is not null and p.cc in (select x.cc from public.pontos x where x.q1 is not null and x.cc is not null group by x.cc having count(*) >= 5)
  group by p.cc, p.q1;
$$;
revoke all on function public.ladder_counts() from public;
grant execute on function public.ladder_counts() to anon, authenticated;
