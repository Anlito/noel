-- Identite du reservant : uniquement sur demande d'un administrateur.
begin;
create or replace function public.mf_reserver(p_family uuid,p_gift uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare owner uuid;child uuid;person uuid;person_name text;
begin
 perform noel_private.ready();
 if not noel_private.admin(p_family) then raise exception 'Administration de cette famille requise';end if;
 select l.owner_id,l.child_id into owner,child from noel_private.gifts g
 join noel_private.lists l on l.id=g.list_id
 join noel_private.publications p on p.list_id=l.id and p.family_id=p_family where g.id=p_gift;
 if not found then raise exception 'Cadeau inaccessible dans cette famille';end if;
 if owner=auth.uid() and child is null then raise exception 'Les reservations de ta propre liste restent cachees';end if;
 select r.reserver_id,p.display_name into person,person_name from noel_private.reservations r
 join public.profiles p on p.id=r.reserver_id where r.gift_id=p_gift;
 if not found then return jsonb_build_object('reserved',false);end if;
 return jsonb_build_object('reserved',true,'name',case when noel_private.member(p_family,person) then person_name else 'une personne d’une autre famille' end);
end $$;
revoke all on function public.mf_reserver(uuid,uuid) from public,anon;
grant execute on function public.mf_reserver(uuid,uuid) to authenticated;
do $migration$
declare definition text;updated text;
begin
 select pg_get_functiondef('noel_private.gift_json(uuid,uuid)'::regprocedure) into definition;
 if position('''reserver''' in definition)>0 then
  updated:=replace(definition,',''reserver'',case when noel_private.member(f,r.reserver_id) then p.display_name when r.gift_id is not null then ''une personne d’une autre famille'' else null end','');
  if updated=definition then raise exception 'gift_json inattendue : aucune modification appliquee';end if;execute updated;
 end if;
 select pg_get_functiondef('public.mf_status()'::regprocedure) into definition;
 if position('reservation_privacy' in definition)=0 then
  updated:=replace(definition,'''version'',2','''reservation_privacy'',true,''version'',2');
  if updated=definition then raise exception 'mf_status inattendue';end if;execute updated;
 end if;
end $migration$;
commit;
