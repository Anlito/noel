-- Preferences cadeaux : 0 sans preference, puis 1 a 3 etoiles.
begin;
alter table noel_private.gifts add column if not exists preference integer not null default 0;
do $migration$
declare definition text;updated text;
begin
 if not exists(select 1 from pg_constraint where conrelid='noel_private.gifts'::regclass and conname='gift_preference_range') then alter table noel_private.gifts add constraint gift_preference_range check(preference between 0 and 3);end if;
 select pg_get_functiondef('noel_private.gift_json(uuid,uuid)'::regprocedure) into definition;
 if position('x.preference' in definition)=0 then
  updated:=replace(definition,'''description'',x.description','''description'',x.description,''preference'',x.preference');
  if updated=definition then raise exception 'gift_json inattendue';end if;execute updated;
 end if;
 select pg_get_functiondef('public.mf_write(text,uuid,uuid,jsonb)'::regprocedure) into definition;
 if position('p_data->>''preference''' in definition)=0 then
  updated:=replace(definition,'insert into noel_private.gifts(list_id,','insert into noel_private.gifts(preference,list_id,');
  if updated=definition then raise exception 'Insertion cadeau inattendue';end if;
  definition:=updated;updated:=replace(definition,'values(v_list.id,trim(p_data->>''title'')','values(coalesce((p_data->>''preference'')::integer,0),v_list.id,trim(p_data->>''title'')');
  if updated=definition then raise exception 'Valeurs cadeau inattendues';end if;
  definition:=updated;updated:=replace(definition,'update noel_private.gifts set title=','update noel_private.gifts set preference=coalesce((p_data->>''preference'')::integer,preference),title=');
  if updated=definition then raise exception 'Modification cadeau inattendue';end if;execute updated;
 end if;
 select pg_get_functiondef('public.mf_read(text,uuid,uuid)'::regprocedure) into definition;
 if position('preference desc' in definition)=0 then
  updated:=replace(definition,'gift_json(id,p_family) order by created_at','gift_json(id,p_family) order by preference desc,created_at,id');
  if updated=definition then raise exception 'Tri des cadeaux inattendu';end if;execute updated;
 end if;
 select pg_get_functiondef('public.mf_status()'::regprocedure) into definition;
 if position('gift_preference' in definition)=0 then
  updated:=replace(definition,'''version'',2','''gift_preference'',true,''version'',2');
  if updated=definition then raise exception 'mf_status inattendue';end if;execute updated;
 end if;
end $migration$;
commit;
