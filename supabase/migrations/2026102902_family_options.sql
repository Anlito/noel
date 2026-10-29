-- Options propres a chaque famille. Aucun repas ni tirage supprime.
begin;
alter table noel_private.families add column if not exists meals_enabled boolean not null default false;
alter table noel_private.families add column if not exists santa_enabled boolean not null default false;
alter table noel_private.families alter column meals_enabled set default false;
alter table noel_private.families alter column santa_enabled set default false;
create or replace function public.mf_family_options(p_family uuid,p_options jsonb default null)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform noel_private.ready();
 if not noel_private.member(p_family) then raise exception 'Famille non autorisée';end if;
 if p_options is not null then
  if not noel_private.admin(p_family) then raise exception 'Administration requise';end if;
  if jsonb_typeof(p_options->'meals') is distinct from 'boolean' or jsonb_typeof(p_options->'santa') is distinct from 'boolean' then raise exception 'Options invalides';end if;
  update noel_private.families set meals_enabled=(p_options->>'meals')::boolean,santa_enabled=(p_options->>'santa')::boolean where id=p_family;
 end if;
 return (select jsonb_build_object('meals',meals_enabled,'santa',santa_enabled) from noel_private.families where id=p_family);
end $$;
revoke all on function public.mf_family_options(uuid,jsonb) from public,anon;
grant execute on function public.mf_family_options(uuid,jsonb) to authenticated;
do $migration$
declare definition text;updated text;
begin
 select pg_get_functiondef('public.mf_status()'::regprocedure) into definition;
 if position('family_options' in definition)=0 then
  updated:=replace(definition,'''version'',2','''family_options'',true,''version'',2');
  if updated=definition then raise exception 'mf_status : definition inattendue';end if;
  execute updated;
 end if;
end $migration$;
commit;
