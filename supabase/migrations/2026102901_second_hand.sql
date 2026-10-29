-- Seconde main : conserve les cadeaux et les reservations existantes.
begin;
alter table noel_private.gifts add column if not exists second_hand boolean not null default false;
do $migration$
declare definition text; updated text;
begin
 select pg_get_functiondef('noel_private.gift_json(uuid,uuid)'::regprocedure) into definition;
 if position('second_hand' in definition)=0 then
  updated:=replace(definition,'''description'',x.description','''description'',x.description,''second_hand'',x.second_hand');
  if updated=definition then raise exception 'gift_json : definition inattendue'; end if;
  execute updated;
 end if;
 select pg_get_functiondef('public.mf_write(text,uuid,uuid,jsonb)'::regprocedure) into definition;
 if position('second_hand' in definition)=0 then
  updated:=replace(definition,'insert into noel_private.gifts(list_id,title,description,url) values(v_list.id,trim(p_data->>''title''),coalesce(p_data->>''description'',''''),coalesce(p_data->>''url'',''''))','insert into noel_private.gifts(list_id,title,description,url,second_hand) values(v_list.id,trim(p_data->>''title''),coalesce(p_data->>''description'',''''),coalesce(p_data->>''url'',''''),coalesce((p_data->>''second_hand'')::boolean,false))');
  if updated=definition then raise exception 'gift-save insertion : definition inattendue'; end if;
  definition:=updated;
  updated:=replace(definition,'url=coalesce(p_data->>''url'','''') where id=gid','url=coalesce(p_data->>''url'',''''),second_hand=coalesce((p_data->>''second_hand'')::boolean,second_hand) where id=gid');
  if updated=definition then raise exception 'gift-save modification : definition inattendue'; end if;
  execute updated;
 end if;
 select pg_get_functiondef('public.mf_status()'::regprocedure) into definition;
 if position('second_hand' in definition)=0 then
  updated:=replace(definition,'''version'',2','''second_hand'',true,''version'',2');
  if updated=definition then raise exception 'mf_status : definition inattendue'; end if;
  execute updated;
 end if;
end $migration$;
commit;
