-- Autorise les parents/gestionnaires a reserver les cadeaux des enfants.
-- Les reservations de sa propre liste personnelle restent cachees.
begin;
create or replace function noel_private.hide_reservations(l uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select noel_private.manage(l) and exists(select 1 from noel_private.lists where id=l and child_id is null)
$$;
revoke all on function noel_private.hide_reservations(uuid) from public,anon,authenticated;
do $migration$
declare definition text;updated text;
begin
 select pg_get_functiondef('noel_private.gift_json(uuid,uuid)'::regprocedure) into definition;
 updated:=replace(definition,'noel_private.manage(x.list_id)','noel_private.hide_reservations(x.list_id)');execute updated;
 select pg_get_functiondef('public.mf_read(text,uuid,uuid)'::regprocedure) into definition;
 updated:=replace(definition,'not noel_private.manage(g.list_id)','not noel_private.hide_reservations(g.list_id)');execute updated;
 select pg_get_functiondef('public.mf_write(text,uuid,uuid,jsonb)'::regprocedure) into definition;
 updated:=replace(definition,'if v_list.id is null or noel_private.manage(v_list.id) or not exists','if v_list.id is null or noel_private.hide_reservations(v_list.id) or not exists');
 if updated=definition and position('noel_private.hide_reservations(v_list.id)' in definition)=0 then raise exception 'Verification reservation inattendue';end if;
 execute updated;
 select pg_get_functiondef('public.mf_status()'::regprocedure) into definition;
 if position('child_reservations' in definition)=0 then
  updated:=replace(definition,'''version'',2','''child_reservations'',true,''version'',2');
  if updated=definition then raise exception 'mf_status inattendue';end if;execute updated;
 end if;
end $migration$;
commit;
