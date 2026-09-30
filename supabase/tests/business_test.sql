-- Business rules: state machine, RPCs, triggers and constraints for schema "rutta".
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

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

-- ================================================================ transition table
select results_eq(
  $$select f, t from (values ('created'), ('assigned'), ('picked_up'), ('in_transit'), ('delivered'), ('cancelled')) a (f)
    cross join (values ('created'), ('assigned'), ('picked_up'), ('in_transit'), ('delivered'), ('cancelled')) b (t)
    where rutta.is_valid_transition(f, t) order by f, t$$,
  $$values ('assigned', 'cancelled'), ('assigned', 'picked_up'), ('created', 'assigned'), ('created', 'cancelled'),
           ('in_transit', 'delivered'), ('picked_up', 'in_transit')$$,
  'is_valid_transition matches the six transitions of the definition');

-- ================================================================ advance_order_status errors
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b2000000-0000-4000-8000-000000000001","role":"authenticated"}';

select throws_like($$select rutta.advance_order_status('c0000000-0000-4000-8000-000000000004', 'delivered')$$, 'RUTTA_INVALID_TRANSITION from=assigned to=delivered',
  'skipping states is rejected');
select throws_like($$select rutta.advance_order_status('c0000000-0000-4000-8000-000000000004', 'picked_up')$$, 'RUTTA_COURIER_BUSY',
  'K1 with T-1 in transit cannot pick up T-4');
select throws_like($$select rutta.advance_order_status('c0000000-0000-4000-8000-000000000002', 'picked_up')$$, 'RUTTA_NOT_ASSIGNED', 'K1 cannot advance the order of K2');
select throws_like($$select rutta.advance_order_status('c0000000-0000-4000-8000-0000000000ff', 'picked_up')$$, 'RUTTA_NOT_FOUND',
  'unknown order id');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b1000000-0000-4000-8000-00000000000a","role":"authenticated"}';

select throws_like($$select rutta.advance_order_status('c0000000-0000-4000-8000-000000000001', 'delivered')$$, 'RUTTA_NOT_ASSIGNED', 'a customer cannot advance an order');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b2000000-0000-4000-8000-000000000002","role":"authenticated"}';

select throws_like($$select rutta.advance_order_status('c0000000-0000-4000-8000-000000000001', 'delivered')$$, 'RUTTA_NOT_ASSIGNED', 'K2 cannot advance the order of K1');

-- ================================================================ happy path (after the BUSY check)
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b2000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is((select status from rutta.advance_order_status('c0000000-0000-4000-8000-000000000001', 'delivered')), 'delivered', 'K1 delivers T-1');
reset role;
select is((select count(*)::int from rutta.order_status_events where order_id = 'c0000000-0000-4000-8000-000000000001' and status = 'delivered'
  and changed_by = 'b2000000-0000-4000-8000-000000000001'), 1, 'delivery is logged with changed_by = K1');
select is((select count(*)::int from rutta.courier_locations where courier_id = 'b2000000-0000-4000-8000-000000000001'), 0, 'K1 location is deleted on delivery');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b2000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is((select status from rutta.advance_order_status('c0000000-0000-4000-8000-000000000004', 'picked_up')), 'picked_up', 'K1 picks up T-4 once free');
select is((select status from rutta.advance_order_status('c0000000-0000-4000-8000-000000000004', 'in_transit')), 'in_transit', 'K1 starts T-4');

-- ================================================================ triggers
reset role;
select throws_like($$update rutta.orders set status = 'assigned' where id = 'c0000000-0000-4000-8000-000000000001'$$, 'RUTTA_INVALID_TRANSITION%',
  'the guard trigger rejects delivered -> assigned even as postgres');
select is((select count(*)::int from rutta.order_status_events where order_id = 'c0000000-0000-4000-8000-000000000004' and status = 'in_transit'), 1,
  'history trigger logs each transition');
update rutta.orders set updated_at = '2000-01-01' where id = 'c0000000-0000-4000-8000-000000000005';
select ok((select updated_at > '2000-01-01' from rutta.orders where id = 'c0000000-0000-4000-8000-000000000005'), 'updated_at is refreshed on update');

-- ================================================================ admin_assign_order
select is((select status from rutta.admin_assign_order('c0000000-0000-4000-8000-000000000005', 'b2000000-0000-4000-8000-000000000002')), 'assigned', 'admin assigns a created order');
select is((select count(*)::int from rutta.order_status_events where order_id = 'c0000000-0000-4000-8000-000000000005' and status = 'assigned'), 1,
  'assignment is logged');
select throws_like($$select rutta.admin_assign_order('c0000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-00000000000a')$$, 'RUTTA_NOT_COURIER', 'cannot assign to a customer');
select throws_like($$select rutta.admin_assign_order('c0000000-0000-4000-8000-000000000005', 'b2000000-0000-4000-8000-000000000002')$$, 'RUTTA_INVALID_TRANSITION from=assigned to=assigned',
  'cannot assign an already assigned order');

-- ================================================================ recorded_at
update rutta.courier_locations set recorded_at = '2000-01-01' where courier_id = 'b2000000-0000-4000-8000-000000000002';
select ok((select recorded_at > now() - interval '1 minute' from rutta.courier_locations where courier_id = 'b2000000-0000-4000-8000-000000000002'),
  'recorded_at always uses the server clock');

-- ================================================================ constraints
select throws_ok($$insert into rutta.orders (code, customer_id, status, pickup_name, pickup_address, pickup_lat, pickup_lng,
  dropoff_address, dropoff_lat, dropoff_lng, items, total_cents, route, route_distance_m, route_duration_s)
  values ('T-9', 'b1000000-0000-4000-8000-00000000000a', 'bogus', 's', 'a', 1, 1, 'b', 1, 1, '[]', 1, '[[1,1],[2,2]]', 1, 1)$$,
  '23514', null, 'unknown status is rejected');
select throws_ok($$insert into rutta.orders (code, customer_id, courier_id, status, pickup_name, pickup_address, pickup_lat, pickup_lng,
  dropoff_address, dropoff_lat, dropoff_lng, items, total_cents, route, route_distance_m, route_duration_s)
  values ('T-9', 'b1000000-0000-4000-8000-00000000000a', null, 'assigned', 's', 'a', 1, 1, 'b', 1, 1, '[]', 1, '[[1,1],[2,2]]', 1, 1)$$, '23514', null,
  'assigned without courier is rejected');
select throws_ok($$insert into rutta.orders (code, customer_id, status, pickup_name, pickup_address, pickup_lat, pickup_lng,
  dropoff_address, dropoff_lat, dropoff_lng, items, total_cents, route, route_distance_m, route_duration_s)
  values ('T-9', 'b1000000-0000-4000-8000-00000000000a', 'created', 's', 'a', 1, 1, 'b', 1, 1, '[]', 1, '[[1,1]]', 1, 1)$$, '23514', null,
  'a one-point route is rejected');
select throws_ok($$insert into rutta.orders (code, customer_id, status, pickup_name, pickup_address, pickup_lat, pickup_lng,
  dropoff_address, dropoff_lat, dropoff_lng, items, total_cents, route, route_distance_m, route_duration_s)
  values ('T-9', 'b1000000-0000-4000-8000-00000000000a', 'created', 's', 'a', 1, 1, 'b', 1, 1, '[]', 1, '{}', 1, 1)$$, '23514', null,
  'a non-array route is a check violation, not a function error');
select throws_ok($$insert into rutta.orders (code, customer_id, courier_id, status, pickup_name, pickup_address, pickup_lat, pickup_lng,
  dropoff_address, dropoff_lat, dropoff_lng, items, total_cents, route, route_distance_m, route_duration_s)
  values ('T-9', 'b1000000-0000-4000-8000-00000000000a', 'b2000000-0000-4000-8000-000000000001', 'picked_up', 's', 'a', 1, 1, 'b', 1, 1, '[]', 1, '[[1,1],[2,2]]', 1, 1)$$, '23505', null,
  'a second order in progress for the same courier is rejected');

select * from finish();
rollback;
