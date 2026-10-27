-- Partage de gestion des listes d'enfants (à exécuter dans Supabase SQL Editor)
create table if not exists public.child_list_managers (
 child_id uuid not null references public.children(id) on delete cascade,
 manager_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(child_id,manager_id)
);
alter table public.child_list_managers enable row level security;
drop policy if exists child_managers_read on public.child_list_managers;
create policy child_managers_read on public.child_list_managers for select to authenticated
using (manager_id = (select auth.uid()) or exists(select 1 from public.children c where c.id=child_id and c.parent_id=(select auth.uid())));
drop policy if exists child_managers_insert on public.child_list_managers;
create policy child_managers_insert on public.child_list_managers for insert to authenticated
with check(manager_id <> (select auth.uid()) and exists(select 1 from public.children c where c.id=child_id and c.parent_id=(select auth.uid())));
drop policy if exists child_managers_delete on public.child_list_managers;
create policy child_managers_delete on public.child_list_managers for delete to authenticated
using(exists(select 1 from public.children c where c.id=child_id and c.parent_id=(select auth.uid())));
-- Une fonction contrôlée permet au co-gestionnaire de modifier les cadeaux
-- sans devenir propriétaire de la fiche ni contourner les restrictions d'autres enfants.
create or replace function public.add_managed_child_gift(p_child_id uuid,p_title text,p_description text default '',p_url text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_parent uuid;v_id uuid;
begin
 select parent_id into v_parent from public.children where id=p_child_id;
 if auth.uid() is null or v_parent is null or not
 (v_parent=auth.uid() or exists(select 1 from public.child_list_managers where child_id=p_child_id and manager_id=auth.uid()))
 then raise exception 'Gestion de cette liste non autorisée';end if;
 if length(trim(coalesce(p_title,'')))<1 or length(p_title)>120 then raise exception 'Titre invalide';end if;
 insert into public.gifts(owner_id,child_id,title,description,url)
 values(v_parent,p_child_id,trim(p_title),left(coalesce(p_description,''),1000),left(coalesce(p_url,''),2048))
 returning id into v_id;
 return v_id;
end $$;
create or replace function public.delete_managed_child_gift(p_child_id uuid,p_gift_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_parent uuid;
begin
 select parent_id into v_parent from public.children where id=p_child_id;
 if auth.uid() is null or v_parent is null or not
 (v_parent=auth.uid() or exists(select 1 from public.child_list_managers where child_id=p_child_id and manager_id=auth.uid()))
 then raise exception 'Gestion de cette liste non autorisée';end if;
 if not exists(select 1 from public.gifts where id=p_gift_id and child_id=p_child_id and owner_id=v_parent)
 then raise exception 'Cadeau introuvable';end if;
 delete from public.reservations where gift_id=p_gift_id;
 -- Certains déploiements protègent la suppression de cadeaux par un trigger.
 -- Respecter ce verrou existant : la fonction remonte alors l'erreur.
 delete from public.gifts where id=p_gift_id and child_id=p_child_id and owner_id=v_parent;
end $$;
revoke all on function public.add_managed_child_gift(uuid,text,text,text) from public;
revoke all on function public.delete_managed_child_gift(uuid,uuid) from public;
grant execute on function public.add_managed_child_gift(uuid,text,text,text) to authenticated;
grant execute on function public.delete_managed_child_gift(uuid,uuid) to authenticated;
