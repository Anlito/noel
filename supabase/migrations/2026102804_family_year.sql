-- Apply after 2026102803_short_family_codes.sql.
begin;
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
