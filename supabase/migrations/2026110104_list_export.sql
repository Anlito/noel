-- Export des listes publiees dans une famille, sans reservations ni comptes.
begin;
create or replace function public.mf_export_lists(p_family uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform noel_private.ready();
 if not noel_private.admin(p_family) then raise exception 'Administration de cette famille requise';end if;
 return (select coalesce(jsonb_agg(jsonb_build_object(
  'family',f.name,'list_id',l.id,'list_name',coalesce(c.display_name,p.display_name),
  'list_type',case when l.child_id is null then 'Adulte' else 'Enfant' end,
  'owner',p.display_name,'gift_id',g.id,'title',g.title,'description',g.description,'url',g.url,
  'favorite',case when g.id is null then null else coalesce((to_jsonb(g)->>'preference')::integer,0)>0 end,
  'second_hand',case when g.id is null then null else coalesce((to_jsonb(g)->>'second_hand')::boolean,false) end
 ) order by coalesce(c.display_name,p.display_name),l.id,g.created_at,g.id),'[]'::jsonb)
 from noel_private.publications pub join noel_private.families f on f.id=pub.family_id
 join noel_private.lists l on l.id=pub.list_id join public.profiles p on p.id=l.owner_id
 left join noel_private.children c on c.id=l.child_id left join noel_private.gifts g on g.list_id=l.id
 where pub.family_id=p_family);
end $$;
revoke all on function public.mf_export_lists(uuid) from public,anon;
grant execute on function public.mf_export_lists(uuid) to authenticated;
do $migration$
declare definition text; updated text;
begin
 select pg_get_functiondef('public.mf_status()'::regprocedure) into definition;
 if position('list_export' in definition)=0 then
  updated:=replace(definition,'''version'',2','''list_export'',true,''version'',2');
  if updated=definition then raise exception 'mf_status inattendue';end if;execute updated;
 end if;
end $migration$;
commit;
