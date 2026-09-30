import 'dart:async';

import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/domain/device_location_repository.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';
import 'package:rutta/features/tracking/domain/tracking_repository.dart';
import 'package:rutta/features/tracking/presentation/screen_awake.dart';

/// Device GPS controlled by the test.
class FakeDeviceLocation implements DeviceLocationRepository {
  FakeDeviceLocation({this.access = LocationAccess.granted});

  LocationAccess access;

  /// What `requestAccess` turns [access] into (null: unchanged).
  LocationAccess? accessAfterRequest;
  int checkCalls = 0;
  int requestCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;
  int listeners = 0;

  StreamController<DevicePosition>? _controller;

  bool get isWatching => _controller?.hasListener ?? false;

  @override
  Future<LocationAccess> checkAccess() async {
    checkCalls++;
    return access;
  }

  @override
  Future<LocationAccess> requestAccess() async {
    requestCalls++;
    return access = accessAfterRequest ?? access;
  }

  @override
  Future<void> openAppSettings() async => openAppSettingsCalls++;

  @override
  Future<void> openLocationSettings() async => openLocationSettingsCalls++;

  @override
  Stream<DevicePosition> watchPosition() {
    final controller = StreamController<DevicePosition>(
      onListen: () => listeners++,
    );
    _controller = controller;
    return controller.stream;
  }

  void emit(DevicePosition position) => _controller?.add(position);

  void emitError(Object error) => _controller?.addError(error);
}

/// Records published locations; can be told to fail.
class RecordingTracking implements TrackingRepository {
  final published = <CourierLocation>[];
  DomainError? failWith;

  @override
  Stream<CourierLocation?> watchCourierLocation(String orderId) =>
      const Stream.empty();

  @override
  Future<void> publishLocation(CourierLocation location) async {
    if (failWith case final error?) throw error;
    published.add(location);
  }
}

class FakeScreenAwake implements ScreenAwake {
  bool enabled = false;
  int enableCalls = 0;

  @override
  Future<void> enable() async {
    enabled = true;
    enableCalls++;
  }

  @override
  Future<void> disable() async => enabled = false;
}
