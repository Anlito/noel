-- Suivi des achats, propre a chaque reservation.
begin;
alter table noel_private.reservations add column if not exists purchased boolean not null default false;
create or replace function public.mf_purchase(p_gift uuid,p_purchased boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform noel_private.ready();
 if p_purchased is null then raise exception 'Statut achat invalide';end if;
 update noel_private.reservations set purchased=p_purchased where gift_id=p_gift and reserver_id=auth.uid();
 if not found then raise exception 'Seule la personne qui reserve ce cadeau peut modifier son achat';end if;
 return jsonb_build_object('purchased',p_purchased);
end $$;
revoke all on function public.mf_purchase(uuid,boolean) from public,anon;
grant execute on function public.mf_purchase(uuid,boolean) to authenticated;
do $migration$
declare definition text;updated text;
begin
 select pg_get_functiondef('public.mf_read(text,uuid,uuid)'::regprocedure) into definition;
 if position('r.purchased' in definition)=0 then
  updated:=replace(definition,'jsonb_build_object(''recipient'',noel_private.summary(g.list_id)->>''name'') else jsonb_build_object(''id'',g.id,''private'',true,''recipient'',''Liste privée'')','jsonb_build_object(''recipient'',noel_private.summary(g.list_id)->>''name'',''purchased'',r.purchased) else jsonb_build_object(''id'',g.id,''private'',true,''recipient'',''Liste privée'',''purchased'',r.purchased)');
  if updated=definition then raise exception 'Lecture des reservations inattendue';end if;execute updated;
 end if;
 select pg_get_functiondef('public.mf_status()'::regprocedure) into definition;
 if position('purchase_tracking' in definition)=0 then
  updated:=replace(definition,'''version'',2','''purchase_tracking'',true,''version'',2');
  if updated=definition then raise exception 'mf_status inattendue';end if;execute updated;
 end if;
end $migration$;
commit;
