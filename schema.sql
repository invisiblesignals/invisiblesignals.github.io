-- Telefone sem Fio v2 (applied 2026-11-25 to Supabase project telefone-sem-fio, sa-east-1).
-- One signal per device per week (weekly round); anyone reads the public map; nobody edits or deletes via the public key.
-- dev (device id), q1 (ladder 0-10) and q2 (could count on someone: 4 always .. 0 never) are never readable row by row.
create table public.pontos (
  id    text primary key check (char_length(id) between 8 and 64),
  dev   text not null check (char_length(dev) between 8 and 64),
  wk    text not null default to_char(now() at time zone 'utc', 'IYYY-"W"IW'),
  code  text not null unique check (code ~ '^[a-z0-9]{4,12}$'),
  ref   text check (ref is null or ref ~ '^[a-z0-9]{4,12}$'),
  place text not null check (char_length(place) between 1 and 80),
  cc    text check (cc is null or cc ~ '^[A-Z]{2}$'),
  lat   double precision not null check (lat between -90 and 90),
  lon   double precision not null check (lon between -180 and 180),
  msg   text not null check (char_length(msg) between 3 and 280),
  mode  text not null check (mode in ('igual', 'recontada', 'nova')),
  q1    smallint check (q1 between 0 and 10),
  q2    smallint check (q2 between 0 and 4),
  lang  text check (lang is null or lang ~ '^[a-z]{2,3}$'),
  at    timestamptz not null default now(),
  unique (dev, wk)
);
create index pontos_at_idx on public.pontos (at desc);
alter table public.pontos enable row level security;
create policy "anyone reads" on public.pontos for select to anon, authenticated using (true);
create policy "anyone adds" on public.pontos for insert to anon, authenticated
  with check (wk = to_char(now() at time zone 'utc', 'IYYY-"W"IW'));
revoke all on public.pontos from anon, authenticated;
grant select (id, wk, code, ref, place, cc, lat, lon, msg, mode, lang, at) on public.pontos to anon, authenticated;
grant insert (id, dev, code, ref, place, cc, lat, lon, msg, mode, q1, q2, lang) on public.pontos to anon, authenticated;

create or replace function public.ladder_counts()
returns table (cc text, q1 smallint, n bigint)
language sql stable security definer set search_path = public as $$
  select '*'::text, p.q1, count(*) from public.pontos p where p.q1 is not null group by p.q1
  union all
  select p.cc, p.q1, count(*) from public.pontos p
  where p.q1 is not null and p.cc in (select x.cc from public.pontos x where x.q1 is not null and x.cc is not null group by x.cc having count(*) >= 5)
  group by p.cc, p.q1;
$$;
revoke all on function public.ladder_counts() from public, anon, authenticated;
grant execute on function public.ladder_counts() to anon, authenticated;

-- v3 (applied 2026-11-25): anti-robot burst guard (max 20 signals per connection per 10 min), salted SHA-256 connection code
-- (pontos.iph, never readable via the API, used only to flag possible duplicates in analysis), prompt version pontos.pv
-- (null = v1 wording, 2 = "What helps you live well? It can be anything"). Full SQL: migration pontos_guard_v3 in Supabase.
