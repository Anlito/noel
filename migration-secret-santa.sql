-- Secret Santa : exécuter dans Supabase SQL Editor après migration-enfants.sql.
create table if not exists public.santa_admins(user_id uuid primary key references auth.users(id) on delete cascade);
create table if not exists public.santa_participants(user_id uuid primary key references public.profiles(id) on delete cascade);
create table if not exists public.santa_assignments(giver_id uuid primary key references public.profiles(id) on delete cascade,recipient_id uuid not null unique references public.profiles(id) on delete cascade,check(giver_id<>recipient_id));
alter table public.santa_admins enable row level security;
alter table public.santa_participants enable row level security;
alter table public.santa_assignments enable row level security;
drop policy if exists santa_admin_self on public.santa_admins;
create policy santa_admin_self on public.santa_admins for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists santa_participants_read on public.santa_participants;
create policy santa_participants_read on public.santa_participants for select to authenticated using(true);
drop policy if exists santa_assignments_mine on public.santa_assignments;
create policy santa_assignments_mine on public.santa_assignments for select to authenticated using(giver_id=(select auth.uid()));
create or replace function public.santa_set_participant(p_user uuid,p_enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.santa_admins where user_id=auth.uid()) then raise exception 'Accès administrateur requis';end if;
 if exists(select 1 from public.santa_assignments) then raise exception 'Tirage déjà effectué : participation verrouillée';end if;
 if not exists(select 1 from public.profiles where id=p_user) then raise exception 'Membre inconnu';end if;
 if p_enabled then insert into public.santa_participants(user_id) values(p_user) on conflict do nothing;
 else delete from public.santa_participants where user_id=p_user;end if;
end $$;
create or replace function public.santa_draw() returns integer
language plpgsql security definer set search_path='' as $$
declare ids uuid[]; n integer; shift_by integer; i integer;
begin
 if not exists(select 1 from public.santa_admins where user_id=auth.uid()) then raise exception 'Accès administrateur requis';end if;
 if exists(select 1 from public.santa_assignments) then raise exception 'Tirage déjà effectué';end if;
 select array_agg(user_id order by random()) into ids from public.santa_participants;
 n:=coalesce(array_length(ids,1),0);
 if n<2 then raise exception 'Il faut au moins 2 participants';end if;
 shift_by:=1+floor(random()*(n-1))::integer;
 for i in 1..n loop
  insert into public.santa_assignments(giver_id,recipient_id) values(ids[i],ids[1+((i-1+shift_by)%n)]);
 end loop;
 return n;
end $$;
revoke all on function public.santa_set_participant(uuid,boolean) from public;
revoke all on function public.santa_draw() from public;
grant execute on function public.santa_set_participant(uuid,boolean) to authenticated;
grant execute on function public.santa_draw() to authenticated;
-- IMPORTANT : remplacer ADRESSE_ADMIN par l'e-mail du super-administrateur puis exécuter séparément :
-- insert into public.santa_admins(user_id)
-- select id from auth.users where lower(email)=lower('ADRESSE_ADMIN')
-- on conflict do nothing;
