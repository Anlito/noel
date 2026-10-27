-- Repas personnalisables, réservés au super-admin pour la création.
create table if not exists public.family_meals(
 key text primary key,
 title text not null,
 starts_at timestamptz,
 created_at timestamptz not null default now()
);
insert into public.family_meals(key,title) values
 ('24-soir','24 décembre · soir'),('25-midi','25 décembre · midi'),
 ('25-soir','25 décembre · soir'),('26-midi','26 décembre · midi'),
 ('26-soir','26 décembre · soir') on conflict(key) do nothing;
alter table public.family_meals enable row level security;
drop policy if exists family_meals_read on public.family_meals;
create policy family_meals_read on public.family_meals for select to authenticated using(true);
drop policy if exists family_meals_insert on public.family_meals;
create policy family_meals_insert on public.family_meals for insert to authenticated
with check(exists(select 1 from public.santa_admins a where a.user_id=(select auth.uid())));
-- Les anciennes contraintes n'acceptaient que cinq repas fixes.
alter table public.meal_attendance drop constraint if exists meal_attendance_meal_key_check;
alter table public.meal_contributions drop constraint if exists meal_contributions_meal_key_check;
alter table public.meal_child_attendance drop constraint if exists meal_child_attendance_meal_key_check;
-- Ne pas supprimer les lignes existantes : elles restent associées à leur clé historique.
