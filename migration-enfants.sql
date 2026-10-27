-- À exécuter une seule fois dans Supabase > SQL Editor.
create table if not exists public.children (
 id uuid primary key default gen_random_uuid(),
 parent_id uuid not null references public.profiles(id) on delete cascade,
 display_name text not null check(length(trim(display_name)) between 1 and 60),
 created_at timestamptz not null default now()
);
alter table public.children enable row level security;
drop policy if exists children_read on public.children;
create policy children_read on public.children for select to authenticated using(true);
drop policy if exists children_insert on public.children;
create policy children_insert on public.children for insert to authenticated with check(parent_id=(select auth.uid()));
drop policy if exists children_update on public.children;
create policy children_update on public.children for update to authenticated using(parent_id=(select auth.uid())) with check(parent_id=(select auth.uid()));
alter table public.gifts add column if not exists child_id uuid references public.children(id);
drop policy if exists gifts_insert on public.gifts;
create policy gifts_insert on public.gifts for insert to authenticated
with check(owner_id=(select auth.uid()) and (child_id is null or exists(select 1 from public.children c where c.id=child_id and c.parent_id=(select auth.uid()))));
drop policy if exists gifts_update on public.gifts;
create policy gifts_update on public.gifts for update to authenticated
using(owner_id=(select auth.uid()))
with check(owner_id=(select auth.uid()) and (child_id is null or exists(select 1 from public.children c where c.id=child_id and c.parent_id=(select auth.uid()))));
-- Le parent reste propriétaire technique de la liste : les réservations lui sont masquées par la politique existante.
