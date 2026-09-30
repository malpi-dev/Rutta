-- RLS, privilege and RPC-permission tests for schema "rutta".
begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

-- Fixtures (as postgres): customers A and B, couriers K1 and K2, and five orders.
insert into auth.users (id, email, aud, role) values
  ('b1000000-0000-4000-8000-00000000000a', 'a@rutta.test', 'authenticated', 'authenticated'),
  ('b1000000-0000-4000-8000-00000000000b', 'b@rutta.test', 'authenticated', 'authenticated'),
  ('b2000000-0000-4000-8000-000000000001', 'k1@rutta.test', 'authenticated', 'authenticated'),
  ('b2000000-0000-4000-8000-000000000002', 'k2@rutta.test', 'authenticated', 'authenticated'),
  ('b3000000-0000-4000-8000-00000000000e', 'n@rutta.test', 'authenticated', 'authenticated');
insert into rutta.profiles (id, full_name, role) values
  ('b1000000-0000-4000-8000-00000000000a', 'Customer A', 'customer'),
  ('b1000000-0000-4000-8000-00000000000b', 'Customer B', 'customer'),
  ('b2000000-0000-4000-8000-000000000001', 'Courier K1', 'courier'),
  ('b2000000-0000-4000-8000-000000000002', 'Courier K2', 'courier');

insert into rutta.orders (id, code, customer_id, courier_id, status, pickup_name, pickup_address, pickup_lat, pickup_lng,
  dropoff_address, dropoff_lat, dropoff_lng, items, total_cents, route, route_distance_m, route_duration_s)
select o.id::uuid, o.code, o.customer_id::uuid, o.courier_id::uuid, o.status, 'Shop', 'Street 1', 19.4, -99.1,
  'Street 2', 19.41, -99.11, '[{"name":"Item","quantity":1}]'::jsonb, 1000,
  '[[-99.1,19.4],[-99.11,19.41]]'::jsonb, 1500, 300
from (values
  ('c0000000-0000-4000-8000-000000000001', 'T-1', 'b1000000-0000-4000-8000-00000000000a', 'b2000000-0000-4000-8000-000000000001', 'in_transit'),
  ('c0000000-0000-4000-8000-000000000002', 'T-2', 'b1000000-0000-4000-8000-00000000000a', 'b2000000-0000-4000-8000-000000000002', 'assigned'),
  ('c0000000-0000-4000-8000-000000000003', 'T-3', 'b1000000-0000-4000-8000-00000000000b', 'b2000000-0000-4000-8000-000000000002', 'picked_up'),
  ('c0000000-0000-4000-8000-000000000004', 'T-4', 'b1000000-0000-4000-8000-00000000000a', 'b2000000-0000-4000-8000-000000000001', 'assigned'),
  ('c0000000-0000-4000-8000-000000000005', 'T-5', 'b1000000-0000-4000-8000-00000000000a', null, 'created')
) as o (id, code, customer_id, courier_id, status);

insert into rutta.courier_locations (courier_id, order_id, lat, lng) values
  ('b2000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 19.4, -99.1),
  ('b2000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000003', 19.4, -99.1);

-- ================================================================ customer A
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b1000000-0000-4000-8000-00000000000a","role":"authenticated"}';

select results_eq($$select code from rutta.orders order by code$$, $$values ('T-1'), ('T-2'), ('T-4'), ('T-5')$$,
  'A: sees exactly own orders');
select is((select count(*)::int from rutta.order_status_events e where e.order_id = 'c0000000-0000-4000-8000-000000000003'), 0, 'A: sees no events of B orders');
select is((select count(*)::int from rutta.order_status_events), 4, 'A: sees events of own orders');
select results_eq($$select courier_id from rutta.courier_locations$$, $$values ('b2000000-0000-4000-8000-000000000001'::uuid)$$,
  'A: sees only K1 location (own order in progress), not K2 on B order');
select results_eq($$select full_name from rutta.profiles order by full_name$$,
  $$values ('Courier K1'::text), ('Courier K2'), ('Customer A')$$, 'A: sees own profile and their couriers, not B');
select throws_ok($$update rutta.profiles set role = 'courier' where id = 'b1000000-0000-4000-8000-00000000000a'$$, '42501', null, 'A: cannot change own role');
with u as (update rutta.profiles set full_name = 'Alex R.' where id = 'b1000000-0000-4000-8000-00000000000a' returning 1)
select is(count(*)::int, 1, 'A: can change own full_name') from u;
select throws_ok($$insert into rutta.orders (code, customer_id) values ('X', 'b1000000-0000-4000-8000-00000000000a')$$, '42501', null, 'A: cannot insert orders');
select throws_ok($$update rutta.orders set status = 'cancelled' where id = 'c0000000-0000-4000-8000-000000000005'$$, '42501', null, 'A: cannot update orders');
select throws_ok($$delete from rutta.orders where id = 'c0000000-0000-4000-8000-000000000005'$$, '42501', null, 'A: cannot delete orders');
select throws_ok($$insert into rutta.order_status_events (order_id, status) values ('c0000000-0000-4000-8000-000000000005', 'assigned')$$, '42501', null,
  'A: cannot insert events');
select throws_ok($$update rutta.order_status_events set status = 'created'$$, '42501', null, 'A: cannot update events');
select throws_ok($$delete from rutta.order_status_events$$, '42501', null, 'A: cannot delete events');
select throws_ok($$insert into rutta.courier_locations (courier_id, order_id, lat, lng) values ('b1000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-000000000001', 1, 1)$$,
  '42501', null, 'A: cannot insert locations');
select throws_ok($$select rutta.admin_assign_order('c0000000-0000-4000-8000-000000000005', 'b2000000-0000-4000-8000-000000000001')$$, '42501', null, 'authenticated: cannot call admin_assign_order');

-- ================================================================ customer B
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b1000000-0000-4000-8000-00000000000b","role":"authenticated"}';

select results_eq($$select code from rutta.orders$$, $$values ('T-3')$$, 'B: sees only own order');
select results_eq($$select courier_id from rutta.courier_locations$$, $$values ('b2000000-0000-4000-8000-000000000002'::uuid)$$, 'B: sees K2 location');

-- ================================================================ courier K1
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b2000000-0000-4000-8000-000000000001","role":"authenticated"}';

select results_eq($$select code from rutta.orders order by code$$, $$values ('T-1'), ('T-4')$$, 'K1: sees own assigned orders');
select is((select count(*)::int from rutta.profiles where id = 'b1000000-0000-4000-8000-00000000000a'), 1, 'K1: sees the profile of customer A');
select lives_ok($$insert into rutta.courier_locations (courier_id, order_id, lat, lng)
  values ('b2000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 19.5, -99.2)
  on conflict (courier_id) do update set order_id = excluded.order_id, lat = excluded.lat, lng = excluded.lng,
    courier_id = excluded.courier_id$$, 'K1: can upsert own location on an order in progress');
select throws_ok($$update rutta.courier_locations set order_id = 'c0000000-0000-4000-8000-000000000004' where courier_id = 'b2000000-0000-4000-8000-000000000001'$$, '42501', null,
  'K1: cannot point location to an assigned (not in progress) order');
select throws_ok($$insert into rutta.courier_locations (courier_id, order_id, lat, lng) values ('b2000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000004', 1, 1)
  on conflict (courier_id) do update set order_id = excluded.order_id$$, '42501', null,
  'K1: cannot publish location for an order not in progress');

-- ================================================================ courier K2
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b2000000-0000-4000-8000-000000000002","role":"authenticated"}';

select throws_ok($$insert into rutta.courier_locations (courier_id, order_id, lat, lng) values ('b2000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 1, 1)$$,
  '42501', null, 'K2: cannot publish a location as K1');

-- ================================================================ anon
reset role;
set local role anon;
set local request.jwt.claims = '';
select throws_ok($$select count(*) from rutta.orders$$, '42501', null, 'anon: cannot select orders');
select throws_ok($$select rutta.ensure_profile('x')$$, '42501', null, 'anon: cannot call ensure_profile');

-- ================================================================ ensure_profile
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b3000000-0000-4000-8000-00000000000e","role":"authenticated"}';

select is((select role from rutta.ensure_profile('Newbie')), 'customer', 'N: ensure_profile creates a customer profile');
select is((select full_name from rutta.ensure_profile('Other name')), 'Newbie', 'N: ensure_profile is idempotent');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b3000000-0000-4000-8000-0000000000ff","role":"authenticated"}';
select throws_ok($$select rutta.ensure_profile('   ')$$, '22023', 'RUTTA_INVALID_NAME', 'ensure_profile: blank name is rejected');
set local request.jwt.claims = '{"role":"authenticated"}';
select throws_ok($$select rutta.ensure_profile('x')$$, '28000', 'RUTTA_UNAUTHORIZED', 'ensure_profile: no session is rejected');

select * from finish();
rollback;
