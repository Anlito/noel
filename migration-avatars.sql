-- Avatars personnalisables (adultes et enfants).
alter table public.profiles add column if not exists avatar text not null default '🎅';
alter table public.children add column if not exists avatar text not null default '🧸';
drop policy if exists profiles_avatar_update on public.profiles;
create policy profiles_avatar_update on public.profiles for update to authenticated
using(id=(select auth.uid())) with check(id=(select auth.uid()));
-- La politique enfants existante autorise déjà chaque parent à modifier ses enfants.
