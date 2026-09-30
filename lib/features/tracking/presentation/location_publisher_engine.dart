import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/orders/domain/order.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/domain/device_location_repository.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';
import 'package:rutta/features/tracking/domain/should_send_location.dart';
import 'package:rutta/features/tracking/domain/tracking_repository.dart';
import 'package:rutta/features/tracking/presentation/screen_awake.dart';

part 'location_publisher_engine.freezed.dart';

enum SharingStatus { idle, waitingForFix, sharing, paused, blocked }

@freezed
abstract class LocationSharingState with _$LocationSharingState {
  const factory LocationSharingState({
    @Default(SharingStatus.idle) SharingStatus status,

    /// Active delivery being shared.
    String? orderId,

    /// Latest GPS fix (drives the courier's own marker).
    DevicePosition? lastPosition,
    DateTime? lastSentAt,

    /// Set when [status] is [SharingStatus.blocked].
    LocationAccess? blockedBy,
  }) = _LocationSharingState;
}

/// Shares the courier's position while a delivery is in progress and the app
/// is in the foreground. Plain Dart (no Flutter) so it can be tested with
/// `fakeAsync`; Riverpod only wires it up.
class LocationPublisherEngine {
  LocationPublisherEngine({
    required this._device,
    required this._tracking,
    required this._shouldSend,
    required this._clock,
    required this._screenAwake,
    required this._courierId,
  });

  final DeviceLocationRepository _device;
  final TrackingRepository _tracking;
  final ShouldSendLocation _shouldSend;
  final Clock _clock;
  final ScreenAwake _screenAwake;
  final String _courierId;

  final _controller = StreamController<LocationSharingState>.broadcast(
    sync: true,
  );
  var _state = const LocationSharingState();
  Order? _order;
  // ignore: cancel_subscriptions, cancelled in _cancelGps().
  StreamSubscription<DevicePosition>? _subscription;
  var _userPaused = false;
  var _appPaused = false;
  var _sending = false;
  var _disposed = false;

  /// Bumped on every (re)start so stale async continuations are ignored.
  var _generation = 0;
  GeoPoint? _lastSentPoint;
  DateTime? _lastSentAt;

  /// Order the backend said is over (`NoActiveOrderError`): not shared again.
  String? _endedOrderId;

  /// Emits the current state on listen, then every change.
  Stream<LocationSharingState> get states {
    late StreamController<LocationSharingState> out;
    StreamSubscription<LocationSharingState>? inner;
    out = StreamController<LocationSharingState>(
      onListen: () {
        out.add(_state);
        inner = _controller.stream.listen(out.add);
      },
      onCancel: () => inner?.cancel(),
    );
    return out.stream;
  }

  LocationSharingState get state => _state;

  /// null or an order that is not in progress stops everything.
  Future<void> setActiveOrder(Order? order) async {
    if (_disposed) return;
    if (order == null || !order.status.isInProgress) {
      _order = null;
      _userPaused = false;
      _endedOrderId = null;
      _stop();
      return;
    }
    final sameOrder = _order?.id == order.id;
    _order = order;
    if (sameOrder) return;
    _userPaused = false;
    _lastSentAt = null;
    _lastSentPoint = null;
    _emit(LocationSharingState(orderId: order.id));
    await _start();
  }

  void pause() {
    if (_disposed || _order == null) return;
    _userPaused = true;
    _generation++;
    _cancelGps();
    unawaited(_screenAwake.disable());
    _emit(
      LocationSharingState(status: SharingStatus.paused, orderId: _order!.id),
    );
  }

  Future<void> resume() async {
    _userPaused = false;
    await _start();
  }

  /// Foreground only: the GPS stops in the background.
  void onAppPaused() {
    if (_disposed) return;
    _appPaused = true;
    _generation++;
    _cancelGps();
    unawaited(_screenAwake.disable());
  }

  Future<void> onAppResumed() async {
    _appPaused = false;
    await _start();
  }

  /// After the permission sheet or the system settings.
  Future<void> retryAccess() => _start();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _cancelGps();
    unawaited(_screenAwake.disable());
    unawaited(_controller.close());
  }

  Future<void> _start() async {
    final order = _order;
    if (_disposed ||
        order == null ||
        _userPaused ||
        _appPaused ||
        order.id == _endedOrderId) {
      return;
    }
    final generation = ++_generation;
    final LocationAccess access;
    try {
      access = await _device.checkAccess();
    } on Exception {
      return;
    }
    if (generation != _generation || _disposed) return;
    if (access != LocationAccess.granted) {
      _cancelGps();
      unawaited(_screenAwake.disable());
      _emit(
        LocationSharingState(
          status: SharingStatus.blocked,
          orderId: order.id,
          blockedBy: access,
        ),
      );
      return;
    }
    if (_subscription != null) return;
    await _screenAwake.enable();
    if (generation != _generation || _disposed) return;
    _emit(
      LocationSharingState(
        status: SharingStatus.waitingForFix,
        orderId: order.id,
      ),
    );
    _subscription = _device.watchPosition().listen(
      _onPosition,
      onError: _onGpsError,
    );
  }

  void _stop() {
    _generation++;
    _cancelGps();
    unawaited(_screenAwake.disable());
    _emit(const LocationSharingState());
  }

  void _cancelGps() {
    final subscription = _subscription;
    _subscription = null;
    // Not awaited: a platform stream can take a while to acknowledge.
    unawaited(subscription?.cancel());
  }

  void _emit(LocationSharingState next) {
    if (_disposed) return;
    _state = next;
    _controller.add(next);
  }

  void _onPosition(DevicePosition position) {
    final order = _order;
    if (order == null || _disposed) return;
    _emit(_state.copyWith(lastPosition: position));
    if (_sending) return;
    final now = _clock.nowUtc();
    if (!_shouldSend(
      candidate: position,
      nowUtc: now,
      lastSentPoint: _lastSentPoint,
      lastSentAt: _lastSentAt,
    )) {
      return;
    }
    unawaited(_publish(order, position, now));
  }

  Future<void> _publish(
    Order order,
    DevicePosition position,
    DateTime now,
  ) async {
    _sending = true;
    final generation = _generation;
    try {
      await _tracking.publishLocation(
        CourierLocation(
          courierId: _courierId,
          orderId: order.id,
          point: position.point,
          recordedAt: position.timestamp,
          heading: position.heading,
          speedMps: position.speedMps,
          accuracyMeters: position.accuracyMeters,
        ),
      );
      if (_disposed || generation != _generation) return;
      _lastSentPoint = position.point;
      _lastSentAt = now;
      _emit(
        _state.copyWith(status: SharingStatus.sharing, lastSentAt: now),
      );
    } on NoActiveOrderError {
      if (_disposed || generation != _generation) return;
      _endedOrderId = order.id;
      _stop();
    } on Exception {
      // Network / backend hiccups: the next reading that passes the filter
      // retries. Nothing else to do here.
    } finally {
      _sending = false;
    }
  }

  void _onGpsError(Object error) {
    final order = _order;
    if (order == null || _disposed) return;
    final blockedBy = switch (error) {
      LocationPermissionDeniedError(:final permanently) =>
        permanently ? LocationAccess.deniedForever : LocationAccess.denied,
      LocationServiceDisabledError() => LocationAccess.serviceDisabled,
      _ => null,
    };
    if (blockedBy == null) return;
    _generation++;
    _cancelGps();
    unawaited(_screenAwake.disable());
    _emit(
      LocationSharingState(
        status: SharingStatus.blocked,
        orderId: order.id,
        blockedBy: blockedBy,
      ),
    );
  }
}
