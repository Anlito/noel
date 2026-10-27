-- Suivi des réservations : accès exclusif au super-admin.
-- À exécuter après migration-secret-santa.sql.
-- Une fonction SECURITY DEFINER permet au super-admin de consulter les réservations
-- sans ouvrir la table réservations aux destinataires.
create or replace function public.admin_gift_reservations()
returns table (
 gift_id uuid,
 gift_title text,
 gift_description text,
 recipient_name text,
 reserver_name text,
 is_reserved boolean
)
language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not exists(
   select 1 from public.santa_admins a where a.user_id=auth.uid()
 ) then
   raise exception 'Accès super-administrateur uniquement';
 end if;
 return query
 select
   g.id,
   g.title,
   g.description,
   coalesce(c.display_name,p.display_name),
   rp.display_name,
   (r.gift_id is not null)
 from public.gifts g
 join public.profiles p on p.id=g.owner_id
 left join public.children c on c.id=g.child_id
 left join public.reservations r on r.gift_id=g.id
 left join public.profiles rp on rp.id=r.reserver_id
 order by coalesce(c.display_name,p.display_name),g.created_at;
end $$;
revoke all on function public.admin_gift_reservations() from public;
revoke all on function public.admin_gift_reservations() from anon;
grant execute on function public.admin_gift_reservations() to authenticated;
