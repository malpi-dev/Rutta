// ignore_for_file: cascade_invocations, rig steps read better as statements.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';
import 'package:rutta/features/tracking/domain/should_send_location.dart';
import 'package:rutta/features/tracking/presentation/location_publisher_engine.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/demo.dart';
import '../../../helpers/location_fakes.dart';

/// Clock that follows `fakeAsync` time.
class AsyncClock implements Clock {
  AsyncClock(this._async);

  final FakeAsync _async;
  final _start = DateTime.utc(2026, 10, 7, 18);

  @override
  DateTime nowUtc() => _start.add(_async.elapsed);
}

/// ~20 m of longitude at the equator.
const _step = 0.00018;

class Rig {
  Rig(this.async, {LocationAccess access = LocationAccess.granted})
    : device = FakeDeviceLocation(access: access),
      clock = AsyncClock(async) {
    engine = LocationPublisherEngine(
      device: device,
      tracking: tracking,
      shouldSend: const ShouldSendLocation(),
      clock: clock,
      screenAwake: awake,
      courierId: 'k1',
    );
    states = Collected(engine.states);
  }

  final FakeAsync async;
  final FakeDeviceLocation device;
  final tracking = RecordingTracking();
  final awake = FakeScreenAwake();
  final AsyncClock clock;
  late final LocationPublisherEngine engine;
  late final Collected<LocationSharingState> states;

  final Order inTransit = buildOrder(status: OrderStatus.inTransit);

  void emit(double lng, {double? accuracy = 5}) => device.emit(
    buildPosition(GeoPoint(0, lng), clock.nowUtc(), accuracy: accuracy),
  );

  void start() => setOrder(inTransit);

  // Futures cannot be awaited inside fakeAsync: flush instead.
  void setOrder(Order? order) {
    unawaited(engine.setActiveOrder(order));
    async.flushMicrotasks();
  }

  void resume() {
    unawaited(engine.resume());
    async.flushMicrotasks();
  }

  void retry() {
    unawaited(engine.retryAccess());
    async.flushMicrotasks();
  }

  void appResumed() {
    unawaited(engine.onAppResumed());
    async.flushMicrotasks();
  }

  /// One reading per second for [seconds], moving [stepDegrees] each time.
  void drive(int seconds, {double stepDegrees = _step, double? accuracy = 5}) {
    var lng = 0.0;
    for (var i = 0; i <= seconds; i++) {
      emit(lng, accuracy: accuracy);
      async.flushMicrotasks();
      lng += stepDegrees;
      async.elapse(const Duration(seconds: 1));
    }
  }

  SharingStatus get status => engine.state.status;
}

void fake(void Function(Rig rig) body, {LocationAccess? access}) {
  fakeAsync((async) {
    final rig = Rig(async, access: access ?? LocationAccess.granted);
    body(rig);
    rig.engine.dispose();
    rig.states.cancel();
    async.flushMicrotasks();
  });
}

void main() {
  test('no order: idle, no GPS subscription', () {
    fake((r) {
      r.async.flushMicrotasks();
      expect(r.status, SharingStatus.idle);
      expect(r.device.isWatching, isFalse);
      expect(r.awake.enabled, isFalse);
    });
  });

  test('order in transit with permission: waiting for fix, screen awake', () {
    fake((r) {
      r.start();
      expect(r.status, SharingStatus.waitingForFix);
      expect(r.engine.state.orderId, 'o1');
      expect(r.device.isWatching, isTrue);
      expect(r.awake.enabled, isTrue);
    });
  });

  test('moving 20 m per second sends at most once every 5 s', () {
    fake((r) {
      r.start();
      r.drive(15);
      expect(r.tracking.published.length, 4);
      final times = r.tracking.published.map((l) => l.recordedAt).toList();
      for (var i = 1; i < times.length; i++) {
        expect(
          times[i].difference(times[i - 1]),
          greaterThanOrEqualTo(const Duration(seconds: 5)),
        );
      }
      expect(r.status, SharingStatus.sharing);
      expect(r.tracking.published.first.courierId, 'k1');
      expect(r.tracking.published.first.orderId, 'o1');
    });
  });

  test('standing still sends a heartbeat every 30 s', () {
    fake((r) {
      r.start();
      r.drive(35, stepDegrees: 0);
      expect(r.tracking.published.length, 2);
      expect(
        r.tracking.published[1].recordedAt.difference(
          r.tracking.published[0].recordedAt,
        ),
        const Duration(seconds: 30),
      );
    });
  });

  test('readings with accuracy worse than 50 m are discarded', () {
    fake((r) {
      r.start();
      r.drive(10, accuracy: 80);
      expect(r.tracking.published, isEmpty);
      expect(r.status, SharingStatus.waitingForFix);
      // The marker still follows the raw fix.
      expect(r.engine.state.lastPosition, isNotNull);
    });
  });

  test('pause stops sending and the wakelock; resume restarts them', () {
    fake((r) {
      r.start();
      r.drive(6);
      final sent = r.tracking.published.length;
      r.engine.pause();
      r.async.flushMicrotasks();
      expect(r.status, SharingStatus.paused);
      expect(r.device.isWatching, isFalse);
      expect(r.awake.enabled, isFalse);
      r.async.elapse(const Duration(seconds: 20));
      expect(r.tracking.published.length, sent);

      r.resume();
      r.async.flushMicrotasks();
      expect(r.status, SharingStatus.waitingForFix);
      expect(r.device.isWatching, isTrue);
      expect(r.awake.enabled, isTrue);
      r.drive(2);
      expect(r.tracking.published.length, greaterThan(sent));
    });
  });

  test('app paused cancels the GPS and resumed restarts it by itself', () {
    fake((r) {
      r.start();
      r.engine.onAppPaused();
      r.async.flushMicrotasks();
      expect(r.device.isWatching, isFalse);
      expect(r.status, isNot(SharingStatus.paused));

      r.appResumed();
      r.async.flushMicrotasks();
      expect(r.device.isWatching, isTrue);
      expect(r.device.listeners, 2);
    });
  });

  test('a manual pause survives the app going to the background', () {
    fake((r) {
      r.start();
      r.engine.pause();
      r.engine.onAppPaused();
      r.appResumed();
      r.async.flushMicrotasks();
      expect(r.status, SharingStatus.paused);
      expect(r.device.isWatching, isFalse);
    });
  });

  test('denied permission: blocked, no subscription, no wakelock', () {
    fake(access: LocationAccess.denied, (r) {
      r.start();
      expect(r.status, SharingStatus.blocked);
      expect(r.engine.state.blockedBy, LocationAccess.denied);
      expect(r.device.isWatching, isFalse);
      expect(r.awake.enabled, isFalse);

      // The access is granted later (permission sheet / settings).
      r.device.access = LocationAccess.granted;
      r.retry();
      r.async.flushMicrotasks();
      expect(r.status, SharingStatus.waitingForFix);
      expect(r.device.isWatching, isTrue);
    });
  });

  test('a service-disabled error from the stream blocks sharing', () {
    fake((r) {
      r.start();
      r.device.emitError(const LocationServiceDisabledError());
      r.async.flushMicrotasks();
      expect(r.status, SharingStatus.blocked);
      expect(r.engine.state.blockedBy, LocationAccess.serviceDisabled);
      expect(r.device.isWatching, isFalse);
    });
  });

  test('a permission error from the stream blocks sharing', () {
    fake((r) {
      r.start();
      r.device.emitError(
        const LocationPermissionDeniedError(permanently: true),
      );
      r.async.flushMicrotasks();
      expect(r.engine.state.blockedBy, LocationAccess.deniedForever);
    });
  });

  test('a NetworkError while publishing does not stop the engine', () {
    fake((r) {
      r.start();
      r.tracking.failWith = const NetworkError();
      r.drive(6);
      expect(r.tracking.published, isEmpty);
      expect(r.device.isWatching, isTrue);
      expect(r.status, SharingStatus.waitingForFix);

      r.tracking.failWith = null;
      r.drive(6);
      expect(r.tracking.published, isNotEmpty);
      expect(r.status, SharingStatus.sharing);
    });
  });

  test('NoActiveOrderError stops sharing that order', () {
    fake((r) {
      r.start();
      r.tracking.failWith = const NoActiveOrderError();
      r.drive(2);
      expect(r.status, SharingStatus.idle);
      expect(r.device.isWatching, isFalse);
      expect(r.awake.enabled, isFalse);
    });
  });

  test('the same order again does not restart the GPS', () {
    fake((r) {
      r.start();
      r.setOrder(buildOrder(status: OrderStatus.pickedUp));
      r.setOrder(buildOrder(status: OrderStatus.inTransit));
      r.async.flushMicrotasks();
      expect(r.device.listeners, 1);
    });
  });

  test('a delivered order goes back to idle and turns the screen lock on', () {
    fake((r) {
      r.start();
      r.drive(2);
      r.setOrder(buildOrder(status: OrderStatus.delivered));
      r.async.flushMicrotasks();
      expect(r.status, SharingStatus.idle);
      expect(r.engine.state.orderId, isNull);
      expect(r.device.isWatching, isFalse);
      expect(r.awake.enabled, isFalse);
    });
  });

  test('a new subscriber receives the current state first', () {
    fake((r) {
      r.start();
      final late = Collected(r.engine.states);
      r.async.flushMicrotasks();
      expect(late.values.first.status, SharingStatus.waitingForFix);
      late.cancel();
    });
  });
}
