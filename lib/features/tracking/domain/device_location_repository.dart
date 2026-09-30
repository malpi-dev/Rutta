import 'package:rutta/features/tracking/domain/device_position.dart';

abstract interface class DeviceLocationRepository {
  Future<LocationAccess> checkAccess();

  /// Shows the system dialog when possible. Returns the resulting access.
  Future<LocationAccess> requestAccess();

  /// Throws `LocationPermissionDeniedError` / `LocationServiceDisabledError`
  /// (as stream errors) when not available.
  Stream<DevicePosition> watchPosition();

  Future<void> openAppSettings();

  Future<void> openLocationSettings();
}
