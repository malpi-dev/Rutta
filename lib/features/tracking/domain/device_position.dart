import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rutta/core/domain/geo_point.dart';

part 'device_position.freezed.dart';

@freezed
abstract class DevicePosition with _$DevicePosition {
  const factory DevicePosition({
    required GeoPoint point,

    /// UTC.
    required DateTime timestamp,
    double? heading,
    double? speedMps,
    double? accuracyMeters,
  }) = _DevicePosition;
}

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }
