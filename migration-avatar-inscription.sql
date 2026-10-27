-- À exécuter après migration-avatars.sql.
-- Le personnage choisi à l'inscription est enregistré immédiatement.
create or replace function public.create_profile_on_signup()
returns trigger language plpgsql security definer set search_path='' as $$
declare chosen_avatar text;
begin
 chosen_avatar := coalesce(nullif(new.raw_user_meta_data->>'avatar',''),'🎅');
 if chosen_avatar not in ('🎅','🤶','🧑‍🎄','🧝','🧝‍♀️','🦌','⛄','☃️','🎄','🎁','🍪','🐧','🐻‍❄️','🦊','🐻','🐱','🐼','🦄','🦖','🐸','🐨','🐯','🧙','🧙‍♀️','👸','🤴','🦸','🦸‍♀️','⭐','❄️','🛷','🔔','🍭','🧸','🥨','🧑‍🚀') then chosen_avatar:='🎅'; end if;
 insert into public.profiles(id,display_name,avatar)
 values(new.id,left(coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''),'Invité'),60),chosen_avatar);
 return new;
end $$;
