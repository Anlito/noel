-- À exécuter dans Supabase > SQL Editor avant de supprimer un enfant.
-- Suppression autorisée uniquement au parent de l'enfant.
create or replace function public.delete_my_child(p_child_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.children
    where id = p_child_id and parent_id = auth.uid()
  ) then
    raise exception 'Suppression non autorisée';
  end if;
  -- Les listes et réservations de cadeaux associés sont supprimées.
  delete from public.reservations
  where gift_id in (select id from public.gifts where child_id = p_child_id);
  delete from public.gifts where child_id = p_child_id;
  -- Retirer les affectations du Secret Santa avant de retirer le participant.
  delete from public.santa_entry_assignments
  where giver_id in (select id from public.santa_entries where child_id = p_child_id)
     or recipient_id in (select id from public.santa_entries where child_id = p_child_id);
  delete from public.santa_entries where child_id = p_child_id;
  delete from public.children where id = p_child_id and parent_id = auth.uid();
end;
$$;
revoke all on function public.delete_my_child(uuid) from public;
grant execute on function public.delete_my_child(uuid) to authenticated;
