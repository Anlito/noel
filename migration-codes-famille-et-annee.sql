-- Mise à jour du projet déjà activé : codes à quatre chiffres et année par famille.
begin;

-- Run once on the already prepared multi-family database.
-- Changes invitation codes only; accounts, memberships and lists are preserved.

create or replace function noel_private.assign_family_code()
returns trigger language plpgsql security definer set search_path='' as $$
declare start_at integer; offset_by integer; candidate text;
begin
 -- Serialize allocation until commit so concurrent creations cannot pick the same code.
 perform pg_advisory_xact_lock(75812027);
 if new.invite_code ~ '^[0-9]{4}$' then return new;end if;
 start_at=floor(random()*10000)::integer;
 for offset_by in 0..9999 loop
  candidate=lpad(((start_at+offset_by)%10000)::text,4,'0');
  if not exists(select 1 from noel_private.families where invite_code=candidate) then
   new.invite_code=candidate;
   return new;
  end if;
 end loop;
 raise exception 'Aucun code famille disponible. Contacte Thomas.';
end $$;
revoke all on function noel_private.assign_family_code() from public,anon,authenticated;

alter table noel_private.families alter column invite_code drop default;
drop trigger if exists assign_short_family_code on noel_private.families;
create trigger assign_short_family_code
before insert or update of invite_code on noel_private.families
for each row execute function noel_private.assign_family_code();

-- Keep any existing four-digit code; replace the old long codes.
update noel_private.families set invite_code=null
where invite_code !~ '^[0-9]{4}$';

alter table noel_private.families drop constraint if exists family_code_four_digits;
alter table noel_private.families add constraint family_code_four_digits
check(invite_code ~ '^[0-9]{4}$');

create or replace function public.mf_status()
returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object('enabled',enabled,'version',2,'family_code_digits',4,'family_year',to_regprocedure('public.mf_family_year(uuid,integer)') is not null)
 from noel_private.settings
$$;
revoke all on function public.mf_status() from public;
grant execute on function public.mf_status() to anon,authenticated,service_role;

notify pgrst,'reload schema';

-- Apply after 2026102803_short_family_codes.sql.
do $$begin
 if not exists(select 1 from pg_constraint where conrelid='noel_private.families'::regclass and conname='family_code_four_digits') then
  raise exception 'Exécuter d’abord la migration des codes famille à quatre chiffres';
 end if;
end$$;

alter table noel_private.families add column if not exists year integer
not null default extract(year from current_date)::integer;
alter table noel_private.families drop constraint if exists family_year_range;
alter table noel_private.families add constraint family_year_range check(year between 2000 and 2100);

create or replace function public.mf_family_year(p_family uuid,p_year integer default null)
returns integer language plpgsql security definer set search_path='' as $$
declare result integer;
begin
 perform noel_private.ready();
 if not noel_private.member(p_family) then raise exception 'Famille non autorisée';end if;
 if p_year is not null then
  perform 1 from noel_private.families where id=p_family for update;
  if not noel_private.admin(p_family) then raise exception 'Administration requise';end if;
  if p_year not between 2000 and 2100 then raise exception 'Année invalide';end if;
  update noel_private.families set year=p_year where id=p_family;
 end if;
 select year into result from noel_private.families where id=p_family;
 return result;
end$$;
revoke all on function public.mf_family_year(uuid,integer) from public,anon;
grant execute on function public.mf_family_year(uuid,integer) to authenticated;

create or replace function public.mf_status()
returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object('enabled',enabled,'version',2,'family_code_digits',4,'family_year',true)
 from noel_private.settings
$$;
revoke all on function public.mf_status() from public;
grant execute on function public.mf_status() to anon,authenticated,service_role;
notify pgrst,'reload schema';

commit;
