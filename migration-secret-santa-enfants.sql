-- Exécuter après les migrations enfants et Secret Santa.
-- Les identités du tirage sont soit un adulte (user_id), soit un enfant (child_id).
create table if not exists public.santa_entries (
 id uuid primary key default gen_random_uuid(),
 user_id uuid unique references public.profiles(id) on delete cascade,
 child_id uuid unique references public.children(id) on delete cascade,
 check ((user_id is null) <> (child_id is null))
);
alter table public.santa_entries enable row level security;
drop policy if exists santa_entries_read on public.santa_entries;
create policy santa_entries_read on public.santa_entries for select to authenticated using(true);
create table if not exists public.santa_entry_assignments (
 giver_id uuid primary key references public.santa_entries(id) on delete cascade,
 recipient_id uuid not null unique references public.santa_entries(id) on delete cascade,
 check(giver_id<>recipient_id)
);
alter table public.santa_entry_assignments enable row level security;
drop policy if exists santa_entry_assignments_private on public.santa_entry_assignments;
create policy santa_entry_assignments_private on public.santa_entry_assignments for select to authenticated using(
 exists(select 1 from public.santa_entries e where e.id=giver_id and
 (e.user_id=(select auth.uid()) or exists(select 1 from public.children c where c.id=e.child_id and c.parent_id=(select auth.uid()))))
);
-- Initialise les adultes déjà sélectionnés dans l'ancien modèle, sans créer d'attribution.
insert into public.santa_entries(user_id) select user_id from public.santa_participants on conflict do nothing;
create or replace function public.santa_entry_set(p_user uuid,p_child uuid,p_enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis';end if;
 perform pg_advisory_xact_lock(75812026);
 if exists(select 1 from public.santa_entry_assignments) or exists(select 1 from public.santa_assignments) then raise exception 'Tirage déjà effectué';end if;
 if (p_user is null)=(p_child is null) then raise exception 'Choisir un adulte ou un enfant';end if;
 if p_user is not null and not exists(select 1 from public.profiles where id=p_user) then raise exception 'Adulte inconnu';end if;
 if p_child is not null and not exists(select 1 from public.children where id=p_child) then raise exception 'Enfant inconnu';end if;
 if p_enabled then insert into public.santa_entries(user_id,child_id) values(p_user,p_child) on conflict do nothing;
 elsif p_user is not null then delete from public.santa_entries where user_id=p_user;
 else delete from public.santa_entries where child_id=p_child;end if;
end $$;
create or replace function public.santa_entry_draw() returns integer
language plpgsql security definer set search_path='' as $$
declare ids uuid[]; n integer; shift_by integer; i integer;
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis';end if;
 perform pg_advisory_xact_lock(75812026);
 if exists(select 1 from public.santa_entry_assignments) or exists(select 1 from public.santa_assignments) then raise exception 'Tirage déjà effectué';end if;
 select array_agg(id order by random()) into ids from public.santa_entries;
 n:=coalesce(array_length(ids,1),0);
 if n<2 then raise exception 'Au moins deux participants requis';end if;
 shift_by:=1+floor(random()*(n-1))::integer;
 for i in 1..n loop
 insert into public.santa_entry_assignments(giver_id,recipient_id) values(ids[i],ids[1+((i-1+shift_by)%n)]);
 end loop;
 return n;
end $$;
create or replace function public.santa_entry_draw_manual(p_pairs jsonb) returns integer
language plpgsql security definer set search_path='' as $$
declare n integer; item jsonb; giver uuid; recipient uuid;
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis';end if;
 perform pg_advisory_xact_lock(75812026);
 if exists(select 1 from public.santa_entry_assignments) or exists(select 1 from public.santa_assignments) then raise exception 'Tirage déjà effectué';end if;
 if jsonb_typeof(p_pairs) is distinct from 'array' then raise exception 'Liste invalide';end if;
 select count(*) into n from public.santa_entries;
 if n<2 or jsonb_array_length(p_pairs)<>n then raise exception 'Nombre de participants incorrect';end if;
 create temporary table if not exists pg_temp.santa_entry_pairs(giver_id uuid,recipient_id uuid) on commit drop;
 truncate pg_temp.santa_entry_pairs;
 for item in select value from jsonb_array_elements(p_pairs) loop
 giver:=(item->>'giver')::uuid;recipient:=(item->>'recipient')::uuid;
 if giver is null or recipient is null or giver=recipient then raise exception 'Attribution invalide';end if;
 insert into pg_temp.santa_entry_pairs values(giver,recipient);
 end loop;
 if (select count(distinct giver_id) from pg_temp.santa_entry_pairs)<>n
 or (select count(distinct recipient_id) from pg_temp.santa_entry_pairs)<>n
 or exists(select 1 from pg_temp.santa_entry_pairs p where not exists(select 1 from public.santa_entries e where e.id=p.giver_id) or not exists(select 1 from public.santa_entries e where e.id=p.recipient_id))
 then raise exception 'Chaque participant doit donner et recevoir une fois';end if;
 insert into public.santa_entry_assignments select giver_id,recipient_id from pg_temp.santa_entry_pairs;
 return n;
end $$;
revoke all on function public.santa_entry_set(uuid,uuid,boolean) from public;
revoke all on function public.santa_entry_draw() from public;
revoke all on function public.santa_entry_draw_manual(jsonb) from public;
grant execute on function public.santa_entry_set(uuid,uuid,boolean) to authenticated;
grant execute on function public.santa_entry_draw() to authenticated;
grant execute on function public.santa_entry_draw_manual(jsonb) to authenticated;
