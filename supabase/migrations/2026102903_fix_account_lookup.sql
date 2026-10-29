-- Corrige la recherche d'un compte absent, sans modifier les comptes existants.
begin;
do $fix$
declare definition text; updated text;
begin
 select pg_get_functiondef('public.mf_service(text,jsonb)'::regprocedure) into definition;
 if position('return to_jsonb(a);' in definition)>0 then
  updated:=replace(definition,'return to_jsonb(a);','return case when a.user_id is null then null else to_jsonb(a) end;');
  execute updated;
 elsif position('case when a.user_id is null then null else to_jsonb(a) end' in definition)=0 then
  raise exception 'Definition mf_service inattendue : aucune modification appliquee';
 end if;
end $fix$;
commit;
