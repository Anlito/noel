-- À exécuter dans Supabase > SQL Editor après migration-partage-listes-enfants.sql.
-- Ne modifie ni les réservations, ni leurs règles de visibilité.
begin;
create or replace function public.update_managed_child_gift(
 p_child_id uuid,p_gift_id uuid,p_title text,p_description text default '',p_url text default ''
)
returns void language plpgsql security definer set search_path = '' as $$
declare v_parent uuid;
begin
 select parent_id into v_parent from public.children where id=p_child_id for share;
 if auth.uid() is null or v_parent is null or not
 (v_parent=auth.uid() or exists(select 1 from public.child_list_managers where child_id=p_child_id and manager_id=auth.uid()))
 then raise exception 'Gestion de cette liste non autorisée';end if;
 if length(trim(coalesce(p_title,'')))<1 or length(p_title)>120 then raise exception 'Titre invalide';end if;
 if length(coalesce(p_description,''))>1000 or length(coalesce(p_url,''))>2048 then raise exception 'Texte trop long';end if;
 update public.gifts set title=trim(p_title),description=coalesce(p_description,''),url=coalesce(p_url,'')
 where id=p_gift_id and child_id=p_child_id and owner_id=v_parent;
 if not found then raise exception 'Cadeau introuvable';end if;
end $$;
revoke all on function public.update_managed_child_gift(uuid,uuid,text,text,text) from public;
grant execute on function public.update_managed_child_gift(uuid,uuid,text,text,text) to authenticated;
commit;
