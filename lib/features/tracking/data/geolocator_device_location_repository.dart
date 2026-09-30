import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/tracking/domain/device_location_repository.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

/// Thin wrapper over the static Geolocator API so the repository can be unit
/// tested.
class GeolocatorApi {
  const GeolocatorApi();

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Stream<Position> getPositionStream({
    required LocationSettings locationSettings,
  }) => Geolocator.getPositionStream(locationSettings: locationSettings);

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Real device GPS. Foreground only: no background location, no foreground
/// service.
class GeolocatorDeviceLocationRepository implements DeviceLocationRepository {
  const GeolocatorDeviceLocationRepository({
    this._api = const GeolocatorApi(),
  });

  final GeolocatorApi _api;

  @override
  Future<LocationAccess> checkAccess() async {
    try {
      if (!await _api.isLocationServiceEnabled()) {
        return LocationAccess.serviceDisabled;
      }
      return _map(await _api.checkPermission());
    } on Exception catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<LocationAccess> requestAccess() async {
    try {
      if (!await _api.isLocationServiceEnabled()) {
        return LocationAccess.serviceDisabled;
      }
      return _map(await _api.requestPermission());
    } on Exception catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Stream<DevicePosition> watchPosition() {
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            intervalDuration: const Duration(seconds: 2),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high);
    return _api
        .getPositionStream(locationSettings: settings)
        .map(_toDevicePosition)
        .transform(
          StreamTransformer<DevicePosition, DevicePosition>.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.addError(_mapError(error), stackTrace),
          ),
        );
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _api.openAppSettings();
    } on Object catch (_) {
      // Best effort: nothing useful to do when settings cannot be opened.
    }
  }

  @override
  Future<void> openLocationSettings() async {
    try {
      await _api.openLocationSettings();
    } on Object catch (_) {
      // Best effort.
    }
  }

  static LocationAccess _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.whileInUse ||
        LocationPermission.always => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine => LocationAccess.denied,
      };

  static DevicePosition _toDevicePosition(Position p) => DevicePosition(
    point: GeoPoint(p.latitude, p.longitude),
    timestamp: p.timestamp.toUtc(),
    heading: p.heading >= 0 ? p.heading : null,
    speedMps: p.speed >= 0 ? p.speed : null,
    accuracyMeters: p.accuracy,
  );

  static DomainError _mapError(Object error) => switch (error) {
    final DomainError e => e,
    PermissionDeniedException() => const LocationPermissionDeniedError(
      permanently: false,
    ),
    LocationServiceDisabledException() => const LocationServiceDisabledError(),
    _ => UnknownError(error),
  };
}
