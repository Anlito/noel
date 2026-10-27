-- Autoriser l'organisateur à modifier ou réinitialiser un tirage Secret Santa.
-- Exécuter après migration-secret-santa-enfants.sql.
create or replace function public.santa_entry_reset()
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis'; end if;
 perform pg_advisory_xact_lock(75812026);
 delete from public.santa_entry_assignments;
end $$;

create or replace function public.santa_entry_replace_manual(p_pairs jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare n integer; item jsonb; giver uuid; recipient uuid;
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis'; end if;
 perform pg_advisory_xact_lock(75812026);
 if jsonb_typeof(p_pairs) is distinct from 'array' then raise exception 'Liste invalide'; end if;
 select count(*) into n from public.santa_entries;
 if n<2 or jsonb_array_length(p_pairs)<>n then raise exception 'Nombre de participants incorrect'; end if;
 create temporary table if not exists pg_temp.santa_replacement_pairs(giver_id uuid,recipient_id uuid) on commit drop;
 truncate pg_temp.santa_replacement_pairs;
 for item in select value from jsonb_array_elements(p_pairs) loop
  giver:=(item->>'giver')::uuid;
  recipient:=(item->>'recipient')::uuid;
  if giver is null or recipient is null or giver=recipient then raise exception 'Attribution invalide'; end if;
  insert into pg_temp.santa_replacement_pairs values(giver,recipient);
 end loop;
 if (select count(distinct giver_id) from pg_temp.santa_replacement_pairs)<>n
 or (select count(distinct recipient_id) from pg_temp.santa_replacement_pairs)<>n
 or exists(select 1 from pg_temp.santa_replacement_pairs p
  where not exists(select 1 from public.santa_entries e where e.id=p.giver_id)
  or not exists(select 1 from public.santa_entries e where e.id=p.recipient_id))
 then raise exception 'Chaque participant doit donner et recevoir une fois'; end if;
 delete from public.santa_entry_assignments;
 insert into public.santa_entry_assignments(giver_id,recipient_id)
 select giver_id,recipient_id from pg_temp.santa_replacement_pairs;
 return n;
end $$;

-- Tirage aléatoire de remplacement atomique.
create or replace function public.santa_entry_redraw()
returns integer language plpgsql security definer set search_path='' as $$
declare ids uuid[]; n integer; shift_by integer; i integer;
begin
 if not public.santa_is_organizer() then raise exception 'Organisateur requis'; end if;
 perform pg_advisory_xact_lock(75812026);
 select array_agg(id order by random()) into ids from public.santa_entries;
 n:=coalesce(array_length(ids,1),0);
 if n<2 then raise exception 'Au moins deux participants requis'; end if;
 shift_by:=1+floor(random()*(n-1))::integer;
 delete from public.santa_entry_assignments;
 for i in 1..n loop
  insert into public.santa_entry_assignments(giver_id,recipient_id)
  values(ids[i],ids[1+((i-1+shift_by)%n)]);
 end loop;
 return n;
end $$;

revoke all on function public.santa_entry_reset() from public,anon;
revoke all on function public.santa_entry_replace_manual(jsonb) from public,anon;
revoke all on function public.santa_entry_redraw() from public,anon;
grant execute on function public.santa_entry_reset() to authenticated;
grant execute on function public.santa_entry_replace_manual(jsonb) to authenticated;
grant execute on function public.santa_entry_redraw() to authenticated;
