@Tags(['supabase'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/supabase/realtime_status_hub.dart';
import 'package:rutta/features/orders/data/supabase_orders_repository.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/data/supabase_tracking_repository.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Runs against `supabase start` (local) right after `supabase db reset`:
/// `RUTTA_IT=1 RUTTA_PUBLISHABLE_KEY=<key> flutter test --tags supabase test/integration/`
final _enabled = Platform.environment['RUTTA_IT'] == '1';
const _mailpit = 'http://127.0.0.1:54324';

Future<String> _codeFor(String email) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final list =
        jsonDecode(
              (await http.get(Uri.parse('$_mailpit/api/v1/messages'))).body,
            )
            as Map<String, dynamic>;
    final messages = (list['messages'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final message in messages) {
      final to = (message['To'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (!to.any((a) => a['Address'] == email)) continue;
      final detail =
          jsonDecode(
                (await http.get(
                  Uri.parse('$_mailpit/api/v1/message/${message['ID']}'),
                )).body,
              )
              as Map<String, dynamic>;
      final match = RegExp(
        r'\b\d{6}\b',
      ).firstMatch('${detail['Text']}${detail['HTML']}');
      if (match != null) return match.group(0)!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('No email for $email in Mailpit');
}

Future<SupabaseClient> _signIn(String email) async {
  final client = SupabaseClient(
    'http://127.0.0.1:54321',
    Platform.environment['RUTTA_PUBLISHABLE_KEY'] ?? '',
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  await client.auth.signInWithOtp(email: email);
  final code = await _codeFor(email);
  await client.auth.verifyOTP(email: email, token: code, type: OtpType.email);
  return client;
}

void main() {
  group(
    'orders and tracking against local Supabase',
    skip: _enabled ? false : 'Set RUTTA_IT=1 (and supabase start) to run',
    () {
      test('realtime, RLS and typed errors across two sessions', () async {
        await http.delete(Uri.parse('$_mailpit/api/v1/messages'));
        final customerClient = await _signIn('customer@rutta.test');
        final courierClient = await _signIn('courier1@rutta.test');
        final customerHub = RealtimeStatusHub();
        final courierHub = RealtimeStatusHub();
        final customerId = customerClient.auth.currentUser!.id;
        final courierId = courierClient.auth.currentUser!.id;
        final customerOrders = SupabaseOrdersRepository(
          customerClient,
          customerHub,
          userId: customerId,
          role: UserRole.customer,
        );
        final courierOrders = SupabaseOrdersRepository(
          courierClient,
          courierHub,
          userId: courierId,
          role: UserRole.courier,
        );
        final customerTracking = SupabaseTrackingRepository(
          customerClient,
          customerHub,
        );
        final courierTracking = SupabaseTrackingRepository(
          courierClient,
          courierHub,
        );
        addTearDown(() async {
          await customerClient.removeAllChannels();
          await courierClient.removeAllChannels();
          customerHub.dispose();
          courierHub.dispose();
          await customerClient.dispose();
          await courierClient.dispose();
        });

        // 1. Visibility per role.
        final mine = await customerOrders.watchMyOrders().first;
        expect(mine, hasLength(8));
        final courierMine = await courierOrders.watchMyOrders().first;
        expect(
          courierMine.map((o) => o.code).toSet(),
          containsAll(<String>['RT-1042', 'RT-1044', 'RT-1038']),
        );
        Order byCode(List<Order> list, String code) =>
            list.firstWhere((o) => o.code == code);
        final rt1042 = byCode(mine, 'RT-1042');
        final rt1044 = byCode(courierMine, 'RT-1044');
        expect(rt1042.route.length, greaterThan(1));
        expect(rt1042.courierName, isNotNull);

        // 2. The customer receives the courier position in real time.
        final locations = <CourierLocation?>[];
        final locSub = customerTracking
            .watchCourierLocation(rt1042.id)
            .listen(locations.add);
        addTearDown(locSub.cancel);
        await _until(() => locations.isNotEmpty);
        await Future<void>.delayed(const Duration(seconds: 1));
        const target = GeoPoint(19.4321, -99.1321);
        await courierTracking.publishLocation(
          CourierLocation(
            courierId: courierId,
            orderId: rt1042.id,
            point: target,
            recordedAt: DateTime.now().toUtc(),
            speedMps: 7,
          ),
        );
        await _until(
          () => locations.any((l) => l != null && l.point == target),
        );

        // 3. One delivery at a time.
        await expectLater(
          courierOrders.advanceStatus(rt1044.id, OrderStatus.pickedUp),
          throwsA(isA<CourierBusyError>()),
        );

        // 4. The customer cannot publish or advance.
        await expectLater(
          customerTracking.publishLocation(
            CourierLocation(
              courierId: customerId,
              orderId: rt1042.id,
              point: target,
              recordedAt: DateTime.now().toUtc(),
            ),
          ),
          throwsA(isA<NoActiveOrderError>()),
        );
        await expectLater(
          customerOrders.advanceStatus(rt1042.id, OrderStatus.delivered),
          throwsA(isA<NotAssignedToYouError>()),
        );

        // 5. Status change and history reach the customer.
        final orderStates = <Order>[];
        final eventLists = <List<OrderStatusEvent>>[];
        final orderSub = customerOrders
            .watchOrder(rt1042.id)
            .listen(orderStates.add);
        final eventSub = customerOrders
            .watchStatusEvents(rt1042.id)
            .listen(eventLists.add);
        addTearDown(orderSub.cancel);
        addTearDown(eventSub.cancel);
        await _until(() => orderStates.isNotEmpty && eventLists.isNotEmpty);
        expect(orderStates.last.status, OrderStatus.inTransit);
        final eventsBefore = eventLists.last.length;
        await Future<void>.delayed(const Duration(seconds: 1));

        final updated = await courierOrders.advanceStatus(
          rt1042.id,
          OrderStatus.delivered,
        );
        expect(updated.status, OrderStatus.delivered);
        expect(updated.customerName, isNotNull);
        await _until(
          () => orderStates.any((o) => o.status == OrderStatus.delivered),
        );
        await _until(() => eventLists.last.length == eventsBefore + 1);
        expect(eventLists.last.last.status, OrderStatus.delivered);

        // 6. Channels and sessions close in the tear-down.
      });
    },
  );
}

Future<void> _until(bool Function() test) async {
  for (var i = 0; i < 50; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for a realtime event (5 s)');
}
