-- PREPARATION ONLY. Does not alter legacy data or enable the new application.
begin;
create schema noel_private;
revoke all on schema noel_private from public,anon,authenticated;
create table noel_private.settings(singleton boolean primary key default true check(singleton),enabled boolean not null default false,original_family uuid);
insert into noel_private.settings default values;
create table noel_private.accounts(user_id uuid primary key references public.profiles(id),login text not null,login_key text not null unique,recovery_email text,verified_at timestamptz);
create table noel_private.families(id uuid primary key default gen_random_uuid(),name text not null check(length(name) between 2 and 60),palette text not null default 'forest' check(palette in('forest','berry','midnight')),ornament text not null default 'stars' check(ornament in('stars','ribbon','snow','photo')),invite_code text not null unique default ('NOEL-'||upper(replace(gen_random_uuid()::text,'-',''))),created_by uuid references public.profiles(id),created_at timestamptz default now());
create table noel_private.memberships(family_id uuid references noel_private.families on delete cascade,user_id uuid references public.profiles,role text not null default 'member' check(role in('admin','member')),organizer boolean not null default false,primary key(family_id,user_id));
create table noel_private.children(id uuid primary key default gen_random_uuid(),parent_id uuid not null references public.profiles,display_name text not null check(length(display_name) between 1 and 60),avatar text not null default '🧸');
create table noel_private.lists(id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.profiles,child_id uuid unique references noel_private.children on delete cascade);
create unique index one_personal_list on noel_private.lists(owner_id) where child_id is null;
create table noel_private.publications(list_id uuid references noel_private.lists on delete cascade,family_id uuid references noel_private.families on delete cascade,primary key(list_id,family_id));
create table noel_private.managers(list_id uuid references noel_private.lists on delete cascade,user_id uuid references public.profiles,family_id uuid references noel_private.families,primary key(list_id,user_id));
create table noel_private.gifts(id uuid primary key default gen_random_uuid(),list_id uuid not null references noel_private.lists on delete cascade,title text not null check(length(title) between 1 and 120),description text not null default '' check(length(description)<=1000),url text not null default '' check(length(url)<=2048 and (url='' or url ~ '^https?://')),created_at timestamptz default now());
create table noel_private.reservations(gift_id uuid primary key references noel_private.gifts on delete cascade,reserver_id uuid not null references public.profiles,family_id uuid not null references noel_private.families,created_at timestamptz default now());
create table noel_private.shares(owner_id uuid references public.profiles,viewer_id uuid references public.profiles,family_id uuid references noel_private.families on delete cascade,primary key(owner_id,viewer_id,family_id),check(owner_id<>viewer_id));
create table noel_private.meals(family_id uuid references noel_private.families on delete cascade,key text,title text not null,starts_at timestamptz,primary key(family_id,key));
create table noel_private.attendance(family_id uuid,meal_key text,user_id uuid references public.profiles,child_id uuid references noel_private.children on delete cascade,foreign key(family_id,meal_key) references noel_private.meals on delete cascade,check((user_id is null)<>(child_id is null)));
create unique index adult_attendance on noel_private.attendance(family_id,meal_key,user_id) where user_id is not null;
create unique index child_attendance on noel_private.attendance(family_id,meal_key,child_id) where child_id is not null;
create table noel_private.contributions(family_id uuid,meal_key text,category text check(category in('Apéro','Entrée','Plat','Dessert')),user_id uuid references public.profiles,primary key(family_id,meal_key,category,user_id),foreign key(family_id,meal_key) references noel_private.meals on delete cascade);
create table noel_private.entries(id uuid primary key default gen_random_uuid(),family_id uuid references noel_private.families,user_id uuid references public.profiles,child_id uuid references noel_private.children,check((user_id is null)<>(child_id is null)),unique(family_id,id),unique(family_id,user_id),unique(family_id,child_id));
create table noel_private.assignments(family_id uuid,giver_id uuid,recipient_id uuid not null,primary key(family_id,giver_id),unique(family_id,recipient_id),foreign key(family_id,giver_id) references noel_private.entries(family_id,id),foreign key(family_id,recipient_id) references noel_private.entries(family_id,id),check(giver_id<>recipient_id));
create table noel_private.challenges(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles,purpose text check(purpose in('verify','reset')),email text not null,token_hash text not null,expires_at timestamptz not null,used_at timestamptz);
create table noel_private.limits(key text primary key,started_at timestamptz not null default now(),attempts integer not null default 1);
create table noel_private.audit(id bigint generated always as identity primary key,user_id uuid,action text not null,reason text,created_at timestamptz default now());
do $$ declare t record;begin for t in select tablename from pg_tables where schemaname='noel_private' loop execute format('alter table noel_private.%I enable row level security',t.tablename);end loop;end $$;

create function public.mf_status() returns jsonb language sql security definer set search_path='' as $$ select jsonb_build_object('enabled',enabled,'version',2) from noel_private.settings $$;
create function noel_private.member(f uuid,u uuid default auth.uid()) returns boolean language sql stable security definer set search_path='' as $$select u is not null and exists(select 1 from noel_private.memberships where family_id=f and user_id=u)$$;
create function noel_private.admin(f uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from noel_private.memberships where family_id=f and user_id=auth.uid() and role='admin')$$;
create function noel_private.organizer(f uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from noel_private.memberships where family_id=f and user_id=auth.uid() and (role='admin' or organizer))$$;
create function noel_private.manage(l uuid,u uuid default auth.uid()) returns boolean language sql stable security definer set search_path='' as $$select u is not null and exists(select 1 from noel_private.lists x where x.id=l and (x.owner_id=u or exists(select 1 from noel_private.managers m where m.list_id=l and m.user_id=u and noel_private.member(m.family_id,u) and noel_private.member(m.family_id,x.owner_id) and exists(select 1 from noel_private.publications p where p.list_id=l and p.family_id=m.family_id))))$$;
create function noel_private.access(l uuid,u uuid default auth.uid()) returns boolean language sql stable security definer set search_path='' as $$select noel_private.manage(l,u) or exists(select 1 from noel_private.publications p join noel_private.memberships m using(family_id) where p.list_id=l and m.user_id=u)$$;
create function noel_private.ready() returns void language plpgsql security definer set search_path='' as $$begin if auth.uid() is null or not(select enabled from noel_private.settings) then raise exception 'Connexion requise ou évolution non activée';end if;if not exists(select 1 from auth.sessions where id=(auth.jwt()->>'session_id')::uuid and user_id=auth.uid()) then raise exception 'Session expirée : reconnecte-toi';end if;end$$;
create function noel_private.summary(l uuid) returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('id',x.id,'owner_id',x.owner_id,'child_id',x.child_id,'name',coalesce(c.display_name,p.display_name),'avatar',coalesce(c.avatar,p.avatar,'🎅'),'manage',noel_private.manage(x.id),'owner',x.owner_id=auth.uid(),'count',(select count(*) from noel_private.gifts where list_id=x.id),'families',case when x.owner_id=auth.uid() then (select coalesce(jsonb_agg(family_id),'[]') from noel_private.publications where list_id=x.id) else '[]'::jsonb end) from noel_private.lists x join public.profiles p on p.id=x.owner_id left join noel_private.children c on c.id=x.child_id where x.id=l$$;
create function noel_private.gift_json(g uuid,f uuid default null) returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('id',x.id,'list_id',x.list_id,'title',x.title,'description',x.description,'url',x.url)||case when noel_private.manage(x.list_id) then '{}'::jsonb else jsonb_build_object('reserved',r.gift_id is not null,'mine',r.reserver_id=auth.uid(),'reserver',case when noel_private.member(f,r.reserver_id) then p.display_name when r.gift_id is not null then 'une personne d’une autre famille' else null end) end
from noel_private.gifts x left join noel_private.reservations r on r.gift_id=x.id left join public.profiles p on p.id=r.reserver_id where x.id=g$$;

create function public.mf_read(p_kind text,p_family uuid default null,p_id uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; v_list noel_private.lists;begin
 perform noel_private.ready();
 if p_kind='bootstrap' then
 return jsonb_build_object('account',(select to_jsonb(a)||jsonb_build_object('name',p.display_name,'avatar',p.avatar) from noel_private.accounts a join public.profiles p on p.id=a.user_id where a.user_id=auth.uid()),'families',(select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'name',f.name,'palette',f.palette,'ornament',f.ornament,'role',m.role) order by f.created_at),'[]') from noel_private.families f join noel_private.memberships m on m.family_id=f.id where m.user_id=auth.uid()),'lists',(select coalesce(jsonb_agg(noel_private.summary(id)),'[]') from noel_private.lists where noel_private.manage(id)));
 end if;
 if p_kind='offerings' then
 if coalesce(p_id,auth.uid())<>auth.uid() and not exists(select 1 from noel_private.shares s where s.owner_id=p_id and s.viewer_id=auth.uid() and s.family_id=p_family and noel_private.member(p_family) and noel_private.member(p_family,p_id)) then raise exception 'Partage non autorisé';end if;
 select coalesce(jsonb_agg(case when noel_private.access(g.list_id) then noel_private.gift_json(g.id,p_family)||jsonb_build_object('recipient',noel_private.summary(g.list_id)->>'name') else jsonb_build_object('id',g.id,'private',true,'recipient','Liste privée') end order by r.created_at),'[]') into result from noel_private.reservations r join noel_private.gifts g on g.id=r.gift_id where r.reserver_id=coalesce(p_id,auth.uid()) and not noel_private.manage(g.list_id) and (coalesce(p_id,auth.uid())=auth.uid() or noel_private.access(g.list_id));return result;
 end if;
 if not noel_private.member(p_family) then raise exception 'Famille non autorisée';end if;
 if p_kind='family' then
 return jsonb_build_object('lists',(select coalesce(jsonb_agg(noel_private.summary(list_id)),'[]') from noel_private.publications where family_id=p_family),'members',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.display_name,'avatar',p.avatar,'role',m.role,'organizer',m.organizer)),'[]') from noel_private.memberships m join public.profiles p on p.id=m.user_id where m.family_id=p_family),'shares',(select coalesce(jsonb_agg(to_jsonb(s)),'[]') from noel_private.shares s where s.family_id=p_family and (s.owner_id=auth.uid() or s.viewer_id=auth.uid())),'managers',(select coalesce(jsonb_agg(to_jsonb(m)),'[]') from noel_private.managers m join noel_private.lists x on x.id=m.list_id where m.family_id=p_family and (x.owner_id=auth.uid() or m.user_id=auth.uid())));
 elsif p_kind='list' then
 select * into v_list from noel_private.lists where id=p_id;
 if v_list.id is null or not(noel_private.manage(p_id) or exists(select 1 from noel_private.publications where list_id=p_id and family_id=p_family)) then raise exception 'Liste non accessible';end if;
 return noel_private.summary(p_id)||jsonb_build_object('gifts',(select coalesce(jsonb_agg(noel_private.gift_json(id,p_family) order by created_at),'[]') from noel_private.gifts where list_id=p_id));
 elsif p_kind='admin-gifts' then
 if not noel_private.admin(p_family) then raise exception 'Administration requise';end if;
 return (select coalesce(jsonb_agg(noel_private.gift_json(g.id,p_family)||jsonb_build_object('recipient',noel_private.summary(g.list_id)->>'name')),'[]') from noel_private.gifts g join noel_private.publications p on p.list_id=g.list_id where p.family_id=p_family and not noel_private.manage(g.list_id));
 elsif p_kind='admin' then
 if not noel_private.admin(p_family) then raise exception 'Administration requise';end if;
 return (select jsonb_build_object('invite_code',invite_code) from noel_private.families where id=p_family);
 elsif p_kind='meals' then
 return jsonb_build_object('meals',(select coalesce(jsonb_agg(to_jsonb(m) order by starts_at),'[]') from noel_private.meals m where family_id=p_family),'attendance',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from noel_private.attendance a where family_id=p_family),'contributions',(select coalesce(jsonb_agg(to_jsonb(c)),'[]') from noel_private.contributions c where family_id=p_family));
 elsif p_kind='santa' then
 return jsonb_build_object('organizer',noel_private.organizer(p_family),'entries',(select coalesce(jsonb_agg(to_jsonb(e)),'[]') from noel_private.entries e where family_id=p_family),'drawn',exists(select 1 from noel_private.assignments where family_id=p_family),'assignments',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from noel_private.assignments a join noel_private.entries e on e.id=a.giver_id where a.family_id=p_family and (e.user_id=auth.uid() or exists(select 1 from noel_private.children c where c.id=e.child_id and c.parent_id=auth.uid()))));
 elsif p_kind='santa-admin' then
 if not noel_private.organizer(p_family) then raise exception 'Organisation requise';end if;
 return (select coalesce(jsonb_agg(to_jsonb(a)),'[]') from noel_private.assignments a where family_id=p_family);
 end if;raise exception 'Vue inconnue';end$$;

create function public.mf_write(p_action text,p_family uuid default null,p_id uuid default null,p_data jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare v_list noel_private.lists; f noel_private.families; gid uuid; target uuid; ids uuid[]; recipients uuid[]; n integer;i integer; chosen uuid; txt text;begin
 perform noel_private.ready();
 if p_action='profile' then
 if length(trim(p_data->>'name')) not between 1 and 60 then raise exception 'Prénom invalide';end if;
 update public.profiles set display_name=trim(p_data->>'name'),avatar=left(coalesce(p_data->>'avatar','🎅'),32) where id=auth.uid();return '{}';
 elsif p_action='create-family' then
 insert into noel_private.families(name,palette,ornament,created_by) values(trim(p_data->>'name'),coalesce(p_data->>'palette','forest'),coalesce(p_data->>'ornament','stars'),auth.uid()) returning * into f;
 if f.ornament='photo' then raise exception 'Décoration non disponible';end if;
 insert into noel_private.memberships values(f.id,auth.uid(),'admin',true);
 if coalesce((p_data->>'publish')::boolean,false) then insert into noel_private.publications select id,f.id from noel_private.lists where owner_id=auth.uid() and child_id is null;end if;
 return jsonb_build_object('id',f.id);
 elsif p_action in('preview-family','join-family') then
 if not noel_private.rate('join:'||auth.uid()::text,20,3600) then return jsonb_build_object('error','Trop de tentatives. Réessaie plus tard.');end if;
 select * into f from noel_private.families where invite_code=upper(trim(p_data->>'code'));
 if f.id is null then return jsonb_build_object('error','Code famille incorrect');end if;
 if p_action='join-family' then
 insert into noel_private.memberships(family_id,user_id) values(f.id,auth.uid()) on conflict do nothing;
 if coalesce((p_data->>'publish')::boolean,false) then insert into noel_private.publications select id,f.id from noel_private.lists where owner_id=auth.uid() and child_id is null on conflict do nothing;end if;
 end if;return jsonb_build_object('id',f.id,'name',f.name,'palette',f.palette,'ornament',f.ornament);
 elsif p_action='child-create' then
 insert into noel_private.children(parent_id,display_name,avatar) values(auth.uid(),trim(p_data->>'name'),left(coalesce(p_data->>'avatar','🧸'),32)) returning id into gid;
 insert into noel_private.lists(owner_id,child_id) values(auth.uid(),gid) returning id into gid;return jsonb_build_object('id',gid);
 elsif p_action in('gift-save','gift-delete','publish','manager','child-edit','child-delete') then
 select * into v_list from noel_private.lists where id=p_id for update;
 if v_list.id is null or not noel_private.manage(v_list.id) then raise exception 'Gestion non autorisée';end if;
 if p_action in('gift-save','gift-delete') then
 gid=nullif(p_data->>'gift_id','')::uuid;
 if gid is not null and not exists(select 1 from noel_private.gifts where id=gid and list_id=v_list.id) then raise exception 'Cadeau inconnu';end if;
 if p_action='gift-delete' then delete from noel_private.gifts where id=gid;else
 if gid is null then insert into noel_private.gifts(list_id,title,description,url) values(v_list.id,trim(p_data->>'title'),coalesce(p_data->>'description',''),coalesce(p_data->>'url',''));else update noel_private.gifts set title=trim(p_data->>'title'),description=coalesce(p_data->>'description',''),url=coalesce(p_data->>'url','') where id=gid;end if;end if;return '{}';end if;
 if v_list.owner_id<>auth.uid() then raise exception 'Parent ou propriétaire requis';end if;
 if p_action='publish' then
 select coalesce(array_agg(value::uuid),'{}') into ids from jsonb_array_elements_text(p_data->'families');
 if exists(select 1 from unnest(ids) x where not noel_private.member(x)) then raise exception 'Famille non autorisée';end if;
 if exists(select 1 from noel_private.entries e join noel_private.assignments a using(family_id) where e.child_id=v_list.child_id and not e.family_id=any(ids)) then raise exception 'Réinitialiser le tirage concerné avant de retirer cet enfant';end if;
 delete from noel_private.entries where child_id=v_list.child_id and not family_id=any(ids);
 delete from noel_private.managers where list_id=v_list.id and not family_id=any(ids);
 delete from noel_private.publications where list_id=v_list.id and not family_id=any(ids);
 insert into noel_private.publications select v_list.id,x from unnest(ids) x on conflict do nothing;
 elsif p_action='manager' then
 target=(p_data->>'user_id')::uuid;
 if v_list.child_id is null or target=auth.uid() or not noel_private.member(p_family) or not noel_private.member(p_family,target) or not exists(select 1 from noel_private.publications where list_id=v_list.id and family_id=p_family) then raise exception 'Gestionnaire non autorisé';end if;
 if (p_data->>'enabled')::boolean then insert into noel_private.managers values(v_list.id,target,p_family) on conflict do nothing;else delete from noel_private.managers where list_id=v_list.id and user_id=target;end if;
 elsif p_action='child-edit' then update noel_private.children set display_name=trim(p_data->>'name'),avatar=left(coalesce(p_data->>'avatar','🧸'),32) where id=v_list.child_id;
 elsif p_action='child-delete' then
 if exists(select 1 from noel_private.entries e join noel_private.assignments a using(family_id) where e.child_id=v_list.child_id) then raise exception 'Réinitialiser les tirages concernés avant de supprimer cet enfant';end if;
 delete from noel_private.entries where child_id=v_list.child_id;delete from noel_private.children where id=v_list.child_id;
 end if;return '{}';
 elsif p_action='release' then delete from noel_private.reservations where gift_id=p_id and reserver_id=auth.uid();return '{}';
 end if;
 if not noel_private.member(p_family) then raise exception 'Famille non autorisée';end if;
 -- Serializes membership changes, reservation visibility, draws and meal changes per family.
 perform 1 from noel_private.families where id=p_family for update;
 if not noel_private.member(p_family) then raise exception 'Famille non autorisée';end if;
 if p_action='reserve' then
 select x.* into v_list from noel_private.gifts g join noel_private.lists x on x.id=g.list_id where g.id=p_id for update of x;
 if v_list.id is null or noel_private.manage(v_list.id) or not exists(select 1 from noel_private.publications where list_id=v_list.id and family_id=p_family) then raise exception 'Réservation non autorisée';end if;
 insert into noel_private.reservations values(p_id,auth.uid(),p_family,now()) on conflict do nothing;
 if not exists(select 1 from noel_private.reservations where gift_id=p_id and reserver_id=auth.uid()) then raise exception 'Ce cadeau est déjà réservé';end if;
 elsif p_action='share' then
 if p_id=auth.uid() or not noel_private.member(p_family,p_id) then raise exception 'Membre non autorisé';end if;
 if (p_data->>'enabled')::boolean then insert into noel_private.shares values(auth.uid(),p_id,p_family) on conflict do nothing;else delete from noel_private.shares where owner_id=auth.uid() and viewer_id=p_id and family_id=p_family;end if;
 elsif p_action in('settings','member','meal-save','meal-delete') then
 if not noel_private.admin(p_family) then raise exception 'Administration requise';end if;
 if p_action='settings' then
 select * into f from noel_private.families where id=p_family;
 update noel_private.families set name=trim(p_data->>'name'),palette=p_data->>'palette',ornament=case when f.ornament='photo' then 'photo' else p_data->>'ornament' end where id=p_family;
 if (p_data->>'ornament')='photo' and f.ornament<>'photo' then raise exception 'Décoration non disponible';end if;
 elsif p_action='member' then
 if not noel_private.member(p_family,p_id) then raise exception 'Membre inconnu';end if;
 if exists(select 1 from noel_private.memberships where family_id=p_family and user_id=p_id and role='admin') and (p_data->>'role') is distinct from 'admin' and (select count(*) from noel_private.memberships where family_id=p_family and role='admin')<2 then raise exception 'Conserver au moins un administrateur';end if;
 if coalesce((p_data->>'remove')::boolean,false) then
 if exists(select 1 from noel_private.entries e join noel_private.assignments a using(family_id) where e.family_id=p_family and (e.user_id=p_id or exists(select 1 from noel_private.children c where c.id=e.child_id and c.parent_id=p_id))) then raise exception 'Réinitialiser le tirage avant de retirer ce membre';end if;
 delete from noel_private.entries e where family_id=p_family and (user_id=p_id or exists(select 1 from noel_private.children c where c.id=e.child_id and c.parent_id=p_id));
 delete from noel_private.publications p using noel_private.lists x where p.list_id=x.id and p.family_id=p_family and x.owner_id=p_id;
 delete from noel_private.managers m using noel_private.lists x where m.list_id=x.id and m.family_id=p_family and (m.user_id=p_id or x.owner_id=p_id);
 delete from noel_private.shares where family_id=p_family and (owner_id=p_id or viewer_id=p_id);
 delete from noel_private.attendance a where family_id=p_family and (user_id=p_id or exists(select 1 from noel_private.children c where c.id=a.child_id and c.parent_id=p_id));
 delete from noel_private.contributions where family_id=p_family and user_id=p_id;
 delete from noel_private.memberships where family_id=p_family and user_id=p_id;
 else update noel_private.memberships set role=p_data->>'role',organizer=coalesce((p_data->>'organizer')::boolean,false) where family_id=p_family and user_id=p_id;end if;
 elsif p_action='meal-delete' then delete from noel_private.meals where family_id=p_family and key=p_data->>'key';
 else
 if length(trim(p_data->>'title')) not between 1 and 100 then raise exception 'Titre invalide';end if;
 insert into noel_private.meals values(p_family,coalesce(nullif(p_data->>'key',''),gen_random_uuid()::text),trim(p_data->>'title'),nullif(p_data->>'starts_at','')::timestamptz) on conflict(family_id,key) do update set title=excluded.title,starts_at=excluded.starts_at;
 end if;
 elsif p_action in('attend','contribute') then
 txt=p_data->>'key';target=nullif(p_data->>'child_id','')::uuid;
 if target is not null and not exists(select 1 from noel_private.children c join noel_private.lists lx on lx.child_id=c.id join noel_private.publications p on p.list_id=lx.id where c.id=target and c.parent_id=auth.uid() and p.family_id=p_family) then raise exception 'Enfant non autorisé';end if;
 if p_action='attend' then
 delete from noel_private.attendance where family_id=p_family and meal_key=txt and (case when target is null then user_id=auth.uid() else child_id=target end);
 if (p_data->>'enabled')::boolean then insert into noel_private.attendance values(p_family,txt,case when target is null then auth.uid() end,target);end if;
 else
 delete from noel_private.contributions where family_id=p_family and meal_key=txt and user_id=auth.uid() and category=p_data->>'category';
 if (p_data->>'enabled')::boolean then insert into noel_private.contributions values(p_family,txt,p_data->>'category',auth.uid());end if;
 end if;
 elsif p_action like 'santa-%' then
 if not noel_private.organizer(p_family) then raise exception 'Organisation requise';end if;
 if p_action='santa-entry' then
 if exists(select 1 from noel_private.assignments where family_id=p_family) then raise exception 'Tirage déjà effectué';end if;
 target=nullif(p_data->>'child_id','')::uuid;
 if target is null then
 if not noel_private.member(p_family,p_id) then raise exception 'Membre inconnu';end if;
 if (p_data->>'enabled')::boolean then insert into noel_private.entries(family_id,user_id) values(p_family,p_id) on conflict do nothing;else delete from noel_private.entries where family_id=p_family and user_id=p_id;end if;
 else
 if not exists(select 1 from noel_private.lists lx join noel_private.publications p on p.list_id=lx.id where lx.child_id=target and p.family_id=p_family) then raise exception 'Enfant inconnu';end if;
 if (p_data->>'enabled')::boolean then insert into noel_private.entries(family_id,child_id) values(p_family,target) on conflict do nothing;else delete from noel_private.entries where family_id=p_family and child_id=target;end if;end if;
 elsif p_action='santa-reset' then delete from noel_private.assignments where family_id=p_family;
 elsif p_action in('santa-draw','santa-manual') then
 select array_agg(id order by random()) into ids from noel_private.entries where family_id=p_family;n=coalesce(array_length(ids,1),0);
 if n<2 then raise exception 'Deux participants minimum';end if;
 if p_action='santa-manual' then
 if jsonb_array_length(p_data->'pairs')<>n then raise exception 'Attributions incomplètes';end if;
 select array_agg((v->>'giver')::uuid),array_agg((v->>'recipient')::uuid) into ids,recipients from jsonb_array_elements(p_data->'pairs') v;
 if (select count(distinct x) from unnest(ids) x)<>n or (select count(distinct x) from unnest(recipients) x)<>n or exists(select 1 from unnest(ids||recipients) x where not exists(select 1 from noel_private.entries e where e.id=x and e.family_id=p_family)) then raise exception 'Attributions invalides';end if;
 else recipients=ids[2:n]||ids[1];end if;
 delete from noel_private.assignments where family_id=p_family;
 for i in 1..n loop insert into noel_private.assignments values(p_family,ids[i],recipients[i]);end loop;
 else raise exception 'Action inconnue';end if;
 else raise exception 'Action inconnue';end if;
 return '{}';end$$;

-- Service-only authentication and recovery primitives. Never grant these to browsers.
create function noel_private.rate(k text,max_attempts integer,seconds integer) returns boolean language plpgsql security definer set search_path='' as $$declare a integer;begin
 insert into noel_private.limits(key) values(k) on conflict(key) do update set attempts=case when noel_private.limits.started_at<now()-make_interval(secs=>seconds) then 1 else noel_private.limits.attempts+1 end,started_at=case when noel_private.limits.started_at<now()-make_interval(secs=>seconds) then now() else noel_private.limits.started_at end returning attempts into a;return a<=max_attempts;end$$;
create function public.mf_service(p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$declare a noel_private.accounts;c noel_private.challenges;uid uuid;begin
 if p_action='limit' then return to_jsonb(noel_private.rate(p_data->>'key',(p_data->>'max')::integer,(p_data->>'seconds')::integer));end if;
 if p_action='resolve' then select * into a from noel_private.accounts where login_key=lower(normalize(trim(p_data->>'login'),NFKC));return to_jsonb(a);end if;
 uid=(p_data->>'user_id')::uuid;
 if p_action='revoke-sessions' then delete from auth.sessions where user_id=uid;delete from auth.refresh_tokens where user_id=uid::text;return '{}';end if;
 if p_action='register' then
 insert into noel_private.accounts(user_id,login,login_key) values(uid,trim(p_data->>'login'),lower(normalize(trim(p_data->>'login'),NFKC)));
 insert into noel_private.lists(owner_id) values(uid);return '{}';
 elsif p_action='issue' then
 delete from noel_private.challenges where user_id=uid and purpose=p_data->>'purpose';
 insert into noel_private.challenges(user_id,purpose,email,token_hash,expires_at) values(uid,p_data->>'purpose',p_data->>'email',p_data->>'hash',now()+interval '30 minutes') returning * into c;
 return jsonb_build_object('id',c.id);
 elsif p_action='consume' then
 select * into c from noel_private.challenges where id=(p_data->>'id')::uuid and token_hash=p_data->>'hash' and purpose=p_data->>'purpose' and used_at is null and expires_at>now() for update;
 if c.id is null then raise exception 'Lien expiré ou invalide';end if;
 update noel_private.challenges set used_at=now() where id=c.id;
 if c.purpose='verify' then update noel_private.accounts set recovery_email=c.email,verified_at=now() where user_id=c.user_id;end if;
 return jsonb_build_object('user_id',c.user_id);
 elsif p_action='support-audit' then insert into noel_private.audit(user_id,action,reason) values(uid,'manual-password-reset',p_data->>'reason');return '{}';
 end if;raise exception 'Action inconnue';end$$;

revoke all on all functions in schema noel_private from public,anon,authenticated;
revoke all on function public.mf_read(text,uuid,uuid),public.mf_write(text,uuid,uuid,jsonb),public.mf_service(text,jsonb),public.mf_status() from public,anon,authenticated;
grant execute on function public.mf_status() to anon,authenticated,service_role;
grant execute on function public.mf_read(text,uuid,uuid),public.mf_write(text,uuid,uuid,jsonb) to authenticated;
grant execute on function public.mf_service(text,jsonb) to service_role;
commit;
