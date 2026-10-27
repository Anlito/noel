create extension if not exists pgcrypto;
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,display_name text not null,created_at timestamptz default now());
create table public.gifts(id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.profiles(id) on delete cascade,title text not null,description text not null default '',url text not null default '',created_at timestamptz default now());
create table public.reservations(gift_id uuid primary key references public.gifts(id) on delete cascade,reserver_id uuid not null references public.profiles(id),created_at timestamptz default now());
create table public.meal_attendance(meal_key text not null check(meal_key in ('24-soir','25-midi','25-soir','26-midi','26-soir')),user_id uuid not null references public.profiles(id),primary key(meal_key,user_id));
create table public.meal_contributions(meal_key text not null check(meal_key in ('24-soir','25-midi','25-soir','26-midi','26-soir')),category text not null check(category in ('Apéro','Entrée','Plat','Dessert')),user_id uuid not null references public.profiles(id),primary key(meal_key,category,user_id));
create or replace function public.create_profile_on_signup() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.profiles(id,display_name) values(new.id,left(coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''),'Invité'),60));return new;end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_profile_on_signup();
alter table public.profiles enable row level security;
alter table public.gifts enable row level security;
alter table public.reservations enable row level security;
alter table public.meal_attendance enable row level security;
alter table public.meal_contributions enable row level security;
create policy profiles_read on public.profiles for select to authenticated using(true);
create policy gifts_read on public.gifts for select to authenticated using(true);
create policy gifts_insert on public.gifts for insert to authenticated with check(owner_id=(select auth.uid()));
create policy gifts_update on public.gifts for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy gifts_delete on public.gifts for delete to authenticated using(owner_id=(select auth.uid()));
create policy reservation_read on public.reservations for select to authenticated using(not exists(select 1 from public.gifts g where g.id=gift_id and g.owner_id=(select auth.uid())));
create policy reservation_insert on public.reservations for insert to authenticated with check(reserver_id=(select auth.uid()) and exists(select 1 from public.gifts g where g.id=gift_id and g.owner_id<>(select auth.uid())));
create policy reservation_delete on public.reservations for delete to authenticated using(reserver_id=(select auth.uid()));
create policy attendance_read on public.meal_attendance for select to authenticated using(true);
create policy attendance_insert on public.meal_attendance for insert to authenticated with check(user_id=(select auth.uid()));
create policy attendance_delete on public.meal_attendance for delete to authenticated using(user_id=(select auth.uid()));
create policy contribution_read on public.meal_contributions for select to authenticated using(true);
create policy contribution_insert on public.meal_contributions for insert to authenticated with check(user_id=(select auth.uid()));
create policy contribution_delete on public.meal_contributions for delete to authenticated using(user_id=(select auth.uid()));
-- This view inherits invoker RLS, so owners cannot read their own gift reservations.
create or replace view public.visible_reservations with (security_invoker=true) as select gift_id,reserver_id,created_at from public.reservations;
-- Prevent a gift owner from learning reservation status through DELETE success/failure.
-- All deletions are prohibited; owner can keep or edit gift instead.
drop policy gifts_delete on public.gifts;
create or replace function public.block_gift_delete() returns trigger language plpgsql as $$ begin raise exception 'Suppression des cadeaux désactivée pour préserver le secret';end $$;
create trigger no_gift_delete before delete on public.gifts for each row execute function public.block_gift_delete();
grant select on public.visible_reservations to authenticated;
