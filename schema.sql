-- =====================================================================
-- BILANCIO CASA – script database per Supabase
-- Incollalo tutto in: Supabase → SQL Editor → New query → Run
-- =====================================================================

-- ===== TABELLE =====
create table if not exists spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null check (type in ('personal','shared')),
  invite_code text unique default upper(substr(md5(random()::text),1,8)),
  created_by uuid references auth.users on delete cascade default auth.uid(),
  created_at timestamptz default now()
);

create table if not exists space_members (
  space_id uuid references spaces on delete cascade,
  user_id uuid references auth.users on delete cascade,
  display_name text,
  joined_at timestamptz default now(),
  primary key (space_id, user_id)
);

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces on delete cascade,
  name text not null,
  icon text default '📦',
  color text default '#64748B',
  kind text not null default 'expense' check (kind in ('expense','income')),
  budget numeric(12,2) default 0
);

create table if not exists accounts (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces on delete cascade,
  name text not null,
  initial_balance numeric(12,2) default 0
);

create table if not exists recurring (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces on delete cascade,
  type text not null check (type in ('expense','income')),
  amount numeric(12,2) not null check (amount > 0),
  day int not null check (day between 1 and 31),
  category_id uuid references categories on delete set null,
  account_id uuid references accounts on delete set null,
  note text,
  paid_by uuid default auth.uid(),
  split_pct numeric default 50 check (split_pct between 0 and 100),
  start_month date not null default date_trunc('month', current_date)::date,
  active boolean default true
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces on delete cascade,
  type text not null check (type in ('expense','income','settle')),
  amount numeric(12,2) not null check (amount > 0),
  date date not null default current_date,
  category_id uuid references categories on delete set null,
  account_id uuid references accounts on delete set null,
  note text,
  paid_by uuid default auth.uid(),
  split_pct numeric default 50 check (split_pct between 0 and 100),
  recurring_id uuid references recurring on delete set null,
  created_at timestamptz default now()
);
create index if not exists transactions_space_date on transactions (space_id, date);

create table if not exists goals (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces on delete cascade,
  name text not null,
  target numeric(12,2) not null check (target > 0),
  deadline date,
  icon text default '🎯'
);

create table if not exists goal_contributions (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references goals on delete cascade,
  space_id uuid not null references spaces on delete cascade,
  user_id uuid default auth.uid(),
  amount numeric(12,2) not null,
  date date default current_date
);

-- ===== SICUREZZA: ognuno vede solo gli spazi di cui fa parte =====
create or replace function is_member(sid uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from space_members where space_id = sid and user_id = auth.uid());
$$;

alter table spaces             enable row level security;
alter table space_members      enable row level security;
alter table categories         enable row level security;
alter table accounts           enable row level security;
alter table recurring          enable row level security;
alter table transactions       enable row level security;
alter table goals              enable row level security;
alter table goal_contributions enable row level security;

drop policy if exists "leggi spazi" on spaces;
drop policy if exists "modifica spazi" on spaces;
drop policy if exists "elimina spazi" on spaces;
create policy "leggi spazi"    on spaces for select using (is_member(id));
create policy "modifica spazi" on spaces for update using (is_member(id));
create policy "elimina spazi"  on spaces for delete using (created_by = auth.uid());

drop policy if exists "leggi membri" on space_members;
drop policy if exists "modifica mio nome" on space_members;
drop policy if exists "esci da spazio" on space_members;
create policy "leggi membri"      on space_members for select using (is_member(space_id));
create policy "modifica mio nome" on space_members for update using (user_id = auth.uid());
create policy "esci da spazio"    on space_members for delete using (user_id = auth.uid());

do $$
declare t text;
begin
  foreach t in array array['categories','accounts','recurring','transactions','goals','goal_contributions'] loop
    execute format('drop policy if exists "membri" on %I', t);
    execute format('create policy "membri" on %I for all using (is_member(space_id)) with check (is_member(space_id))', t);
  end loop;
end $$;

-- ===== FUNZIONI =====

-- Crea uno spazio (personale o condiviso) con categorie e conti di base
create or replace function create_space(p_name text, p_type text, p_display_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  if auth.uid() is null then raise exception 'Non autenticato'; end if;

  -- un solo spazio personale per utente
  if p_type = 'personal' then
    select s.id into sid from spaces s join space_members m on m.space_id = s.id
     where s.type = 'personal' and m.user_id = auth.uid() limit 1;
    if sid is not null then return sid; end if;
  end if;

  insert into spaces(name, type, created_by) values (p_name, p_type, auth.uid()) returning id into sid;
  insert into space_members(space_id, user_id, display_name) values (sid, auth.uid(), p_display_name);

  insert into categories(space_id, name, icon, color, kind) values
    (sid, 'Casa',             '🏠', '#2563EB', 'expense'),
    (sid, 'Spesa alimentare', '🛒', '#16A34A', 'expense'),
    (sid, 'Bollette',         '⚡', '#EA580C', 'expense'),
    (sid, 'Trasporti',        '🚗', '#D97706', 'expense'),
    (sid, 'Svago',            '🎬', '#8B5CF6', 'expense'),
    (sid, 'Salute',           '❤️', '#E11D48', 'expense'),
    (sid, 'Ristoranti e bar', '🍽️', '#DB2777', 'expense'),
    (sid, 'Abbigliamento',    '👕', '#0891B2', 'expense'),
    (sid, 'Regali',           '🎁', '#C026D3', 'expense'),
    (sid, 'Altro',            '📦', '#64748B', 'expense'),
    (sid, 'Stipendio',        '💼', '#059669', 'income'),
    (sid, 'Altre entrate',    '💰', '#0D9488', 'income');

  insert into accounts(space_id, name) values (sid, 'Conto corrente'), (sid, 'Contanti');
  return sid;
end $$;

-- Entra in uno spazio condiviso con il codice invito
create or replace function join_space(p_code text, p_display_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  if auth.uid() is null then raise exception 'Non autenticato'; end if;
  select id into sid from spaces where invite_code = upper(trim(p_code)) and type = 'shared';
  if sid is null then raise exception 'Codice invito non valido'; end if;
  insert into space_members(space_id, user_id, display_name)
  values (sid, auth.uid(), p_display_name) on conflict do nothing;
  return sid;
end $$;

-- Genera i movimenti delle spese/entrate ricorrenti (ultimi 12 mesi al massimo)
create or replace function apply_recurring(sid uuid)
returns int language plpgsql security invoker set search_path = public as $$
declare r record; m date; d date; n int := 0;
begin
  if not is_member(sid) then raise exception 'Accesso negato'; end if;
  for r in select * from recurring where space_id = sid and active loop
    for m in
      select gs::date from generate_series(
        greatest(r.start_month, (date_trunc('month', current_date) - interval '11 months')::date),
        date_trunc('month', current_date)::date,
        interval '1 month') gs
    loop
      d := least(m + (r.day - 1), (m + interval '1 month' - interval '1 day')::date);
      if d <= current_date and not exists (
        select 1 from transactions t where t.recurring_id = r.id and date_trunc('month', t.date) = m
      ) then
        insert into transactions(space_id, type, amount, date, category_id, account_id, note, paid_by, split_pct, recurring_id)
        values (sid, r.type, r.amount, d, r.category_id, r.account_id, r.note, r.paid_by, r.split_pct, r.id);
        n := n + 1;
      end if;
    end loop;
  end loop;
  return n;
end $$;

-- ===== PERMESSI API =====
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on function is_member(uuid), create_space(text,text,text), join_space(text,text), apply_recurring(uuid) to authenticated;

-- ===== AGGIORNAMENTI IN TEMPO REALE (i movimenti dell'altro compaiono subito) =====
do $$
begin
  alter publication supabase_realtime add table transactions;
exception when others then null;
end $$;
