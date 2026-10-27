-- Accès à toutes les attributions uniquement pour le super-admin et les organisateurs.
create or replace function public.santa_organizer_assignments()
returns table(giver_id uuid,recipient_id uuid)
language plpgsql security definer set search_path = ''
as $$
begin
 if auth.uid() is null or not (
  exists(select 1 from public.santa_admins where user_id=auth.uid())
  or exists(select 1 from public.santa_organizers where user_id=auth.uid())
 ) then raise exception 'Accès réservé aux organisateurs'; end if;
 return query select a.giver_id,a.recipient_id from public.santa_entry_assignments a;
end $$;
revoke all on function public.santa_organizer_assignments() from public;
grant execute on function public.santa_organizer_assignments() to authenticated;
