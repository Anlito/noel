-- Exécuter APRÈS migration-secret-santa.sql dans Supabase SQL Editor.
create table if not exists public.santa_organizers(user_id uuid primary key references public.profiles(id) on delete cascade);
alter table public.santa_organizers enable row level security;
drop policy if exists santa_organizer_self on public.santa_organizers;
create policy santa_organizer_self on public.santa_organizers for select to authenticated using(user_id=(select auth.uid()));
create or replace function public.santa_is_organizer() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.santa_admins where user_id=auth.uid())
 or exists(select 1 from public.santa_organizers where user_id=auth.uid())
$$;
create or replace function public.santa_set_organizer(p_user uuid,p_enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.santa_admins where user_id=auth.uid()) then raise exception 'Super-administrateur requis'; end if;
 if not exists(select 1 from public.profiles where id=p_user) then raise exception 'Compte inconnu'; end if;
 if p_enabled then insert into public.santa_organizers(user_id) values(p_user) on conflict do nothing;
 else delete from public.santa_organizers where user_id=p_user; end if;
end $$;
create or replace function public.santa_set_participant(p_user uuid,p_enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis'; end if;
 if exists(select 1 from public.santa_assignments) then raise exception 'Tirage déjà effectué : participation verrouillée'; end if;
 if not exists(select 1 from public.profiles where id=p_user) then raise exception 'Membre inconnu'; end if;
 if p_enabled then insert into public.santa_participants(user_id) values(p_user) on conflict do nothing;
 else delete from public.santa_participants where user_id=p_user; end if;
end $$;
create or replace function public.santa_draw() returns integer
language plpgsql security definer set search_path='' as $$
declare ids uuid[]; n integer; shift_by integer; i integer;
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis'; end if;
 perform pg_advisory_xact_lock(75812026);
 if exists(select 1 from public.santa_assignments) then raise exception 'Tirage déjà effectué'; end if;
 select array_agg(user_id order by random()) into ids from public.santa_participants;
 n:=coalesce(array_length(ids,1),0);
 if n<2 then raise exception 'Au moins deux participants requis'; end if;
 shift_by:=1+floor(random()*(n-1))::integer;
 for i in 1..n loop
  insert into public.santa_assignments(giver_id,recipient_id) values(ids[i],ids[1+((i-1+shift_by)%n)]);
 end loop;
 return n;
end $$;
create or replace function public.santa_draw_manual(p_pairs jsonb) returns integer
language plpgsql security definer set search_path='' as $$
declare n integer; count_pairs integer; giver uuid; receiver uuid; item jsonb;
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis'; end if;
 perform pg_advisory_xact_lock(75812026);
 if exists(select 1 from public.santa_assignments) then raise exception 'Tirage déjà effectué'; end if;
 if jsonb_typeof(p_pairs) is distinct from 'array' then raise exception 'Liste des attributions invalide'; end if;
 select count(*) into n from public.santa_participants;
 count_pairs:=jsonb_array_length(p_pairs);
 if n<2 or count_pairs<>n then raise exception 'Chaque participant doit être attribué exactement une fois'; end if;
 create temporary table if not exists pg_temp.santa_pairs(giver_id uuid,recipient_id uuid) on commit drop;
 truncate pg_temp.santa_pairs;
 for item in select value from jsonb_array_elements(p_pairs) loop
  giver:=(item->>'giver')::uuid; receiver:=(item->>'recipient')::uuid;
  if giver is null or receiver is null or giver=receiver then raise exception 'Attribution invalide ou à soi-même'; end if;
  insert into pg_temp.santa_pairs values(giver,receiver);
 end loop;
 if (select count(distinct giver_id) from pg_temp.santa_pairs)<>n
 or (select count(distinct recipient_id) from pg_temp.santa_pairs)<>n
 or exists(select 1 from pg_temp.santa_pairs p where not exists(select 1 from public.santa_participants x where x.user_id=p.giver_id) or not exists(select 1 from public.santa_participants x where x.user_id=p.recipient_id))
 then raise exception 'Chaque participant doit donner et recevoir exactement une fois'; end if;
 insert into public.santa_assignments(giver_id,recipient_id) select giver_id,recipient_id from pg_temp.santa_pairs;
 return n;
end $$;
revoke all on function public.santa_is_organizer() from public;
revoke all on function public.santa_set_organizer(uuid,boolean) from public;
revoke all on function public.santa_draw_manual(jsonb) from public;
grant execute on function public.santa_is_organizer() to authenticated;
grant execute on function public.santa_set_organizer(uuid,boolean) to authenticated;
grant execute on function public.santa_draw_manual(jsonb) to authenticated;
-- Aucune politique ne permet de lire les attributions des autres.
