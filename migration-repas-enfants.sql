-- Présence des enfants aux repas : exécuter après migration-enfants.sql.
create table if not exists public.meal_child_attendance (
 meal_key text not null check(meal_key in ('24-soir','25-midi','25-soir','26-midi','26-soir')),
 child_id uuid not null references public.children(id) on delete cascade,
 primary key(meal_key,child_id)
);
alter table public.meal_child_attendance enable row level security;
drop policy if exists meal_child_attendance_read on public.meal_child_attendance;
create policy meal_child_attendance_read on public.meal_child_attendance for select to authenticated using(true);
drop policy if exists meal_child_attendance_insert on public.meal_child_attendance;
create policy meal_child_attendance_insert on public.meal_child_attendance for insert to authenticated
with check(exists(select 1 from public.children c where c.id=child_id and c.parent_id=(select auth.uid())));
drop policy if exists meal_child_attendance_delete on public.meal_child_attendance;
create policy meal_child_attendance_delete on public.meal_child_attendance for delete to authenticated
using(exists(select 1 from public.children c where c.id=child_id and c.parent_id=(select auth.uid())));
