-- À exécuter après migration-repas-personnalisables.sql.
-- Seul le super-admin peut modifier ou supprimer un repas.
drop policy if exists family_meals_update on public.family_meals;
create policy family_meals_update on public.family_meals for update to authenticated
using(exists(select 1 from public.santa_admins a where a.user_id=(select auth.uid())))
with check(exists(select 1 from public.santa_admins a where a.user_id=(select auth.uid())));
-- Suppression atomique du repas et de toutes ses inscriptions.
create or replace function public.admin_delete_family_meal(p_key text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.santa_admins where user_id=auth.uid()) then
  raise exception 'Accès réservé au super-administrateur';
 end if;
 if not exists(select 1 from public.family_meals where key=p_key) then
  raise exception 'Repas introuvable';
 end if;
 delete from public.meal_child_attendance where meal_key=p_key;
 delete from public.meal_contributions where meal_key=p_key;
 delete from public.meal_attendance where meal_key=p_key;
 delete from public.family_meals where key=p_key;
end $$;
revoke all on function public.admin_delete_family_meal(text) from public;
grant execute on function public.admin_delete_family_meal(text) to authenticated;
