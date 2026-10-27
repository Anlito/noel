-- Avatars personnalisables (adultes et enfants).
alter table public.profiles add column if not exists avatar text not null default '🎅';
alter table public.children add column if not exists avatar text not null default '🧸';
-- Les règles RLS existantes restent applicables : chaque membre gère son profil,
-- et chaque parent gère uniquement ses enfants.
