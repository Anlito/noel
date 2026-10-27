-- Gestion des comptes réservée au super-admin.
-- Exécuter après les migrations Secret Santa, enfants et repas.
create or replace function public.admin_rename_account(p_user uuid,p_name text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.santa_admins where user_id=auth.uid()) then raise exception 'Super-admin requis';end if;
 if p_user is null or length(trim(coalesce(p_name,''))) not between 1 and 60 then raise exception 'Prénom invalide';end if;
 update public.profiles set display_name=trim(p_name) where id=p_user;
 if not found then raise exception 'Compte introuvable';end if;
end $$;

-- Exception au blocage de suppression des cadeaux uniquement pendant
-- la suppression explicite d'un compte par le super-admin.
create or replace function public.block_gift_delete() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if current_setting('app.admin_account_deletion',true)='yes'
 and exists(select 1 from public.santa_admins where user_id=auth.uid()) then
   return old;
 end if;
 raise exception 'Suppression des cadeaux désactivée pour préserver le secret';
end $$;

create or replace function public.admin_delete_account(p_user uuid,p_confirmation text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.santa_admins where user_id=auth.uid()) then raise exception 'Super-admin requis';end if;
 if p_user is null or p_user=auth.uid() then raise exception 'Impossible de supprimer votre propre compte';end if;
 if p_confirmation is distinct from 'SUPPRIMER' then raise exception 'Confirmation incorrecte';end if;
 if not exists(select 1 from public.profiles where id=p_user) then raise exception 'Compte introuvable';end if;
 perform pg_advisory_xact_lock(75812026);
 perform set_config('app.admin_account_deletion','yes',true);
 -- Efface les tirages devenus incomplets : il faudra refaire le tirage.
 if exists(select 1 from public.santa_entries e where e.user_id=p_user
   or e.child_id in(select id from public.children where parent_id=p_user)) then
   delete from public.santa_entry_assignments;
 end if;
 if exists(select 1 from public.santa_assignments where giver_id=p_user or recipient_id=p_user) then
   delete from public.santa_assignments;
 end if;
 delete from public.santa_participants where user_id=p_user;
 delete from public.santa_organizers where user_id=p_user;
 delete from public.santa_admins where user_id=p_user;
 delete from public.santa_entries where user_id=p_user or child_id in(select id from public.children where parent_id=p_user);
 delete from public.meal_child_attendance where child_id in(select id from public.children where parent_id=p_user);
 delete from public.meal_attendance where user_id=p_user;
 delete from public.meal_contributions where user_id=p_user;
 delete from public.reservations where reserver_id=p_user or gift_id in(select id from public.gifts where owner_id=p_user);
 delete from public.gifts where owner_id=p_user;
 delete from public.children where parent_id=p_user;
 delete from auth.users where id=p_user;
 if not found then raise exception 'Compte Auth introuvable';end if;
end $$;
revoke all on function public.admin_rename_account(uuid,text) from public,anon;
revoke all on function public.admin_delete_account(uuid,text) from public,anon;
grant execute on function public.admin_rename_account(uuid,text) to authenticated;
grant execute on function public.admin_delete_account(uuid,text) to authenticated;
