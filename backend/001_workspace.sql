create schema if not exists grove;
revoke all on schema grove from public, anon, authenticated;
grant usage on schema grove to authenticated;
create table grove.catalog (
  id integer primary key, title text not null, category text not null, description text not null,
  price numeric(12,2) not null, detail text not null, lat numeric, lng numeric
);
create table grove.accounts (uid uuid primary key references auth.users on delete cascade, role text not null check(role in ('demo','admin')));
create table grove.profiles (uid uuid references auth.users on delete cascade, space uuid, display_name text not null, primary key(uid,space));
create table grove.records (
  id uuid primary key default gen_random_uuid(), owner uuid not null references auth.users on delete cascade,
  space uuid not null, pool uuid not null, item integer references grove.catalog, kind text not null,
  status text not null, slot text, payload jsonb not null default '{}', created_at timestamptz not null default now()
);
create unique index on grove.records(pool,item,slot) where kind in ('seat','appointment','viewing','assignment') and status <> 'Cancelled';
create unique index on grove.records(owner,space,item,kind) where kind in ('favorite','course');
alter table grove.catalog enable row level security;
alter table grove.accounts enable row level security;
alter table grove.profiles enable row level security;
alter table grove.records enable row level security;
revoke all on all tables in schema grove from public,anon,authenticated;

insert into grove.catalog values ('1','Tomatoes on the vine','Produce','Ripe, fragrant tomatoes from the morning harvest.','3.8','500 g',NULL,NULL),
('2','Country sourdough','Bakery','A slow-fermented wheat loaf with a crisp crust.','5.2','650 g',NULL,NULL),
('3','Hass avocados','Produce','Creamy, ready-to-ripen fruit for your kitchen.','4.6','2 pieces',NULL,NULL),
('4','Extra virgin olive oil','Pantry','Cold-pressed oil with a light pepper finish.','12.5','500 ml',NULL,NULL),
('5','Valencia oranges','Produce','Sweet citrus for breakfast or a fresh squeeze.','4.2','1 kg',NULL,NULL);

create or replace function grove.handle(action text, args jsonb, installation uuid)
returns jsonb language plpgsql security definer set search_path='' as $body$
<<handle>>
declare
  uid uuid := auth.uid();
  mode text;
  scope uuid;
  pool_id uuid := '00000000-0000-0000-0000-000000000000';
  product grove.catalog%rowtype;
  rec grove.records%rowtype;
  target integer;
  slot_key text;
  day date;
  amount numeric := 0;
  qty int;
  line jsonb;
  lines jsonb := '[]';
  info jsonb := '{}';
  label text;
begin
  if uid is null or installation is null then raise exception 'Sign in to continue'; end if;
  select a.role into mode from grove.accounts a where a.uid=handle.uid;
  if mode is null and (auth.jwt()->>'email') like '%@demo.mobile.invalid' then raise exception 'Use this app’s demo account'; end if;
  scope := case when mode='demo' then installation else uid end;
  if mode='demo' then if installation=pool_id then raise exception 'Invalid demo installation'; end if; pool_id := installation; end if;
  if action='profile' then
    label := trim(args->>'name');
    if coalesce(length(label),0) not between 1 and 60 then raise exception 'Enter a name of 1–60 characters'; end if;
    insert into grove.profiles values(uid,scope,label) on conflict on constraint profiles_pkey do update set display_name=excluded.display_name;
  elsif action='cancel' then
    update grove.records r set status='Cancelled' where r.id=(args->>'id')::uuid and r.owner=uid and r.space=scope and r.kind in ('seat','viewing','appointment') and r.status='Confirmed';
    if not found then raise exception 'Reservation no longer available'; end if;
  elsif action not in ('state','availability') then
    
if action='checkout' then
  if jsonb_typeof(args->'lines') is distinct from 'array' then raise exception 'Add products to your basket'; end if;
  if jsonb_array_length(args->'lines') not between 1 and 30 then raise exception 'Choose 1–30 lines'; end if;
  label := trim(args->>'address');
  if coalesce(length(label),0) not between 5 and 160 then raise exception 'Enter a delivery address'; end if;
  for line in select value from jsonb_array_elements(args->'lines') loop
    select * into strict product from grove.catalog where id=(line->>'id')::int;
    qty := (line->>'qty')::int;
    if qty is null or qty not between 1 and 20 then raise exception 'Choose 1–20 units per product'; end if;
    amount := amount+product.price*qty;
    lines := lines || jsonb_build_array(jsonb_build_object('title',product.title,'qty',qty,'price',product.price));
  end loop;
  insert into grove.records(id,owner,space,pool,kind,status,payload) values((args->>'requestId')::uuid,uid,scope,pool_id,'order','Received',jsonb_build_object('lines',lines,'total',amount,'address',label)) on conflict(id) do nothing;
elsif action='advance' and mode in ('demo','admin') then
  select * into strict rec from grove.records r where r.id=(args->>'id')::uuid and r.pool=pool_id and r.kind='order' for update;
  label := case rec.status when 'Received' then 'Packing' when 'Packing' then 'Out for delivery' when 'Out for delivery' then 'Delivered' end;
  if label is null then raise exception 'Order already delivered'; end if;
  update grove.records set status=label where id=rec.id;
else raise exception 'Order action unavailable'; end if;

  end if;
  if action='availability' then
    select coalesce(jsonb_agg(r.slot),'[]') into info from grove.records r where r.pool=pool_id and r.item=(args->>'item')::integer and r.status <> 'Cancelled' and r.kind in ('seat','viewing','appointment','assignment');
    return info;
  end if;
  return jsonb_build_object(
    'catalog',(select coalesce(jsonb_agg(to_jsonb(c) order by c.id),'[]') from grove.catalog c),
    'records',(select coalesce(jsonb_agg(to_jsonb(r)-'owner'-'space'-'pool' order by r.created_at desc),'[]') from grove.records r where (r.owner=uid and r.space=scope) or (mode='admin' and r.pool=pool_id)),
    'name',(select p.display_name from grove.profiles p where p.uid=handle.uid and p.space=scope),
    'demo',coalesce(mode='demo',false),'admin',coalesce(mode in ('demo','admin'),false)
  );
exception when unique_violation then raise exception 'Just reserved. Choose another option.';
end $body$;
revoke all on function grove.handle(text,jsonb,uuid) from public,anon;
grant execute on function grove.handle(text,jsonb,uuid) to authenticated;
create or replace function public.grove_workspace(action text,args jsonb,installation uuid)
returns jsonb language sql security invoker set search_path='' as $$
  select grove.handle(action,args,installation);
$$;
revoke all on function public.grove_workspace(text,jsonb,uuid) from public,anon;
grant execute on function public.grove_workspace(text,jsonb,uuid) to authenticated;
notify pgrst,'reload schema';

