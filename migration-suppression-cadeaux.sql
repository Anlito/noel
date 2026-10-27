-- À exécuter dans Supabase > SQL Editor après les migrations enfants et partage.
-- Supprime une idée sans révéler si elle était réservée.
begin;
-- Les suppressions directes restent interdites. Seules les fonctions contrôlées
-- (cadeaux, suppression de compte/enfant) peuvent supprimer physiquement une idée.
revoke delete on public.gifts from authenticated, anon, public;
drop policy if exists gifts_delete on public.gifts;
drop trigger if exists no_gift_delete on public.gifts;

create or replace function public.delete_my_gift(p_gift_id uuid,p_child_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_gift public.gifts%rowtype;
begin
 if auth.uid() is null then raise exception 'Suppression non autorisée';end if;
 select * into v_gift from public.gifts where id=p_gift_id for update;
 if not found then raise exception 'Cadeau introuvable ou accès refusé';end if;
 if p_child_id is null then
   if v_gift.child_id is not null or v_gift.owner_id<>auth.uid() then
     raise exception 'Cadeau introuvable ou accès refusé';end if;
 else
   if v_gift.child_id is distinct from p_child_id or not exists(
     select 1 from public.children c where c.id=p_child_id and c.parent_id=v_gift.owner_id
     and (c.parent_id=auth.uid() or exists(select 1 from public.child_list_managers m
       where m.child_id=c.id and m.manager_id=auth.uid()))
   ) then raise exception 'Cadeau introuvable ou accès refusé';end if;
 end if;
 -- Même résultat qu'une réservation existe ou non : aucun statut n'est retourné.
 delete from public.reservations where gift_id=p_gift_id;
 delete from public.gifts where id=p_gift_id;
end $$;
revoke all on function public.delete_my_gift(uuid,uuid) from public,anon;
grant execute on function public.delete_my_gift(uuid,uuid) to authenticated;

-- Compatibilité avec les anciennes pages encore en cache.
create or replace function public.delete_managed_child_gift(p_child_id uuid,p_gift_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_child_id is null then raise exception 'Suppression non autorisée';end if;
 perform public.delete_my_gift(p_gift_id,p_child_id);
end $$;
revoke all on function public.delete_managed_child_gift(uuid,uuid) from public,anon;
grant execute on function public.delete_managed_child_gift(uuid,uuid) to authenticated;
commit;
