-- À exécuter dans Supabase > SQL Editor après les migrations enfants.
-- Partage en lecture seule, sans changement des règles de lecture des réservations.
begin;
create table if not exists public.reservation_list_shares (
 owner_id uuid not null references public.profiles(id) on delete cascade,
 viewer_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(owner_id,viewer_id),
 constraint reservation_share_not_self check(owner_id<>viewer_id)
);
alter table public.reservation_list_shares enable row level security;
revoke all on public.reservation_list_shares from public,anon,authenticated;
grant select,insert,delete on public.reservation_list_shares to authenticated;
drop policy if exists reservation_shares_read on public.reservation_list_shares;
create policy reservation_shares_read on public.reservation_list_shares
 for select to authenticated using(owner_id=(select auth.uid()) or viewer_id=(select auth.uid()));
drop policy if exists reservation_shares_insert on public.reservation_list_shares;
create policy reservation_shares_insert on public.reservation_list_shares
 for insert to authenticated with check(owner_id=(select auth.uid()) and viewer_id<>(select auth.uid()));
drop policy if exists reservation_shares_delete on public.reservation_list_shares;
create policy reservation_shares_delete on public.reservation_list_shares
 for delete to authenticated using(owner_id=(select auth.uid()));

create or replace function public.shared_reserved_gifts(p_owner_id uuid)
returns table(gift_id uuid,gift_title text,gift_description text,gift_url text,
 recipient_id uuid,recipient_kind text,recipient_name text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(
   select 1 from public.reservation_list_shares s
   where s.owner_id=p_owner_id and s.viewer_id=auth.uid()
 ) then raise exception 'Partage inexistant ou accès retiré';end if;
 return query
 select g.id,g.title,g.description,g.url,coalesce(g.child_id,g.owner_id),
 case when g.child_id is null then 'adult'::text else 'child'::text end,
 coalesce(c.display_name,p.display_name)
 from public.reservations r
 join public.gifts g on g.id=r.gift_id
 join public.profiles p on p.id=g.owner_id
 left join public.children c on c.id=g.child_id
 where r.reserver_id=p_owner_id
 -- Le destinataire et le parent de ses enfants ne voient jamais leurs cadeaux.
 and g.owner_id<>auth.uid()
 and (g.child_id is null or (c.id is not null and c.parent_id<>auth.uid()))
 order by coalesce(c.display_name,p.display_name),g.created_at,g.id;
end $$;
revoke all on function public.shared_reserved_gifts(uuid) from public,anon;
grant execute on function public.shared_reserved_gifts(uuid) to authenticated;
commit;
