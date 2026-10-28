-- CUTOVER: run only AFTER preparation, Edge deployment and validation on a copy.
-- Entire transaction rolls back on any error. Historical public tables remain frozen.
begin;
lock table public.profiles,public.children,public.gifts,public.reservations in access exclusive mode;
do $$declare t record;f uuid;cnt integer;begin
 if (select enabled from noel_private.settings) then raise exception 'Déjà activé';end if;
 if exists(select 1 from public.profiles group by lower(normalize(trim(display_name),NFKC)) having count(*)>1) then raise exception 'Identifiants existants en doublon : résoudre avant activation, sans supprimer les comptes';end if;
 if not exists(select 1 from public.santa_admins) then raise exception 'Administrateur historique manquant';end if;
 -- Lock every historical application table, including optional migrations.
 for t in select tablename from pg_tables where schemaname='public' and tablename in ('child_list_managers','children','family_meals','gifts','meal_attendance','meal_child_attendance','meal_contributions','profiles','reservation_list_shares','reservations','santa_admins','santa_assignments','santa_entries','santa_entry_assignments','santa_organizers','santa_participants') loop execute format('lock table public.%I in access exclusive mode',t.tablename);end loop;
 insert into noel_private.families(name,ornament,created_by) select 'Noël en famille','photo',user_id from public.santa_admins order by user_id limit 1 returning id into f;
 insert into noel_private.accounts(user_id,login,login_key) select id,trim(display_name),lower(normalize(trim(display_name),NFKC)) from public.profiles;
 insert into noel_private.memberships select f,p.id,case when a.user_id is null then 'member' else 'admin' end,exists(select 1 from public.santa_organizers o where o.user_id=p.id) from public.profiles p left join public.santa_admins a on a.user_id=p.id;
 insert into noel_private.children select id,parent_id,display_name,coalesce(avatar,'🧸') from public.children;
 insert into noel_private.lists(owner_id) select id from public.profiles;
 insert into noel_private.lists(owner_id,child_id) select parent_id,id from public.children;
 insert into noel_private.publications select id,f from noel_private.lists;
 insert into noel_private.managers select l.id,m.manager_id,f from public.child_list_managers m join noel_private.lists l on l.child_id=m.child_id;
 -- Invalid legacy URLs are preserved as text descriptions; never made clickable.
 insert into noel_private.gifts select g.id,l.id,g.title,g.description||case when g.url<>'' and g.url!~'^https?://' then E'\nAncien lien : '||g.url else '' end,case when g.url~'^https?://' then g.url else '' end,g.created_at from public.gifts g join noel_private.lists l on l.owner_id=g.owner_id and l.child_id is not distinct from g.child_id;
 insert into noel_private.reservations select gift_id,reserver_id,f,created_at from public.reservations;
 if to_regclass('public.reservation_list_shares') is not null then execute 'insert into noel_private.shares select owner_id,viewer_id,$1 from public.reservation_list_shares' using f;end if;
 if to_regclass('public.family_meals') is not null then
 execute 'insert into noel_private.meals select $1,key,title,starts_at from public.family_meals' using f;
 else insert into noel_private.meals values(f,'24-soir','24 décembre · soir','2026-12-24 19:00+01'),(f,'25-midi','25 décembre · midi','2026-12-25 12:00+01'),(f,'25-soir','25 décembre · soir','2026-12-25 19:00+01'),(f,'26-midi','26 décembre · midi','2026-12-26 12:00+01'),(f,'26-soir','26 décembre · soir','2026-12-26 19:00+01');end if;
 insert into noel_private.attendance select f,meal_key,user_id,null from public.meal_attendance;
 if to_regclass('public.meal_child_attendance') is not null then execute 'insert into noel_private.attendance select $1,meal_key,null,child_id from public.meal_child_attendance' using f;end if;
 insert into noel_private.contributions select f,meal_key,category,user_id from public.meal_contributions;
 insert into noel_private.entries select id,f,user_id,child_id from public.santa_entries;
 insert into noel_private.assignments select f,giver_id,recipient_id from public.santa_entry_assignments;
 -- An older adult draw may still be the authoritative draw. Never discard it.
 if exists(select 1 from public.santa_assignments) then
 if exists(select 1 from noel_private.assignments) then
 if exists(select 1 from public.santa_assignments a join noel_private.entries g on g.user_id=a.giver_id join noel_private.entries r on r.user_id=a.recipient_id where not exists(select 1 from noel_private.assignments x where x.giver_id=g.id and x.recipient_id=r.id)) then raise exception 'Deux tirages historiques incompatibles : arbitrage requis';end if;
 else
 insert into noel_private.entries(family_id,user_id) select f,giver_id from public.santa_assignments union select f,recipient_id from public.santa_assignments on conflict do nothing;
 insert into noel_private.assignments select f,g.id,r.id from public.santa_assignments a join noel_private.entries g on g.user_id=a.giver_id and g.family_id=f join noel_private.entries r on r.user_id=a.recipient_id and r.family_id=f;
 end if;end if;
 if (select count(*) from noel_private.accounts)<>(select count(*) from public.profiles) or (select count(*) from noel_private.gifts)<>(select count(*) from public.gifts) or (select count(*) from noel_private.children)<>(select count(*) from public.children) or (select count(*) from noel_private.reservations)<>(select count(*) from public.reservations) then raise exception 'Comptage de migration incorrect';end if;
 -- Old browser versions must fail closed, including SECURITY DEFINER RPCs.
 for t in select tablename from pg_tables where schemaname='public' and tablename in ('child_list_managers','children','family_meals','gifts','meal_attendance','meal_child_attendance','meal_contributions','profiles','reservation_list_shares','reservations','santa_admins','santa_assignments','santa_entries','santa_entry_assignments','santa_organizers','santa_participants') loop execute format('revoke all on public.%I from public,anon,authenticated',t.tablename);end loop;
 for t in select viewname from pg_views where schemaname='public' and viewname='visible_reservations' loop execute format('revoke all on public.%I from public,anon,authenticated',t.viewname);end loop;
 for t in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('add_managed_child_gift','admin_delete_account','admin_delete_family_meal','admin_gift_reservations','admin_rename_account','block_gift_delete','create_profile_on_signup','delete_managed_child_gift','delete_my_child','delete_my_gift','santa_draw','santa_draw_manual','santa_entry_draw','santa_entry_draw_manual','santa_entry_redraw','santa_entry_replace_manual','santa_entry_reset','santa_entry_set','santa_is_organizer','santa_organizer_assignments','santa_set_organizer','santa_set_participant','shared_reserved_gifts','update_managed_child_gift') and p.prokind='f' and not exists(select 1 from pg_depend d where d.objid=p.oid and d.deptype='e') loop execute format('revoke execute on function %s from public,anon,authenticated',t.signature);end loop;
 update noel_private.settings set enabled=true,original_family=f;
 insert into noel_private.audit(action,reason) values('activate','Migration atomique des données historiques');
end$$;
commit;
