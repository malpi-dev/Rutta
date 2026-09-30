import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/tracking/data/geolocator_device_location_repository.dart';
import 'package:rutta/features/tracking/domain/device_position.dart';

class _MockApi extends Mock implements GeolocatorApi {}

Position position({
  double heading = 90,
  double speed = 5,
  double accuracy = 8,
  DateTime? timestamp,
}) => Position(
  latitude: 19.4,
  longitude: -99.1,
  timestamp: timestamp ?? DateTime.utc(2026, 10, 7, 18),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: heading,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

void main() {
  late _MockApi api;
  late GeolocatorDeviceLocationRepository repo;

  setUpAll(() => registerFallbackValue(const LocationSettings()));
  setUp(() {
    api = _MockApi();
    repo = GeolocatorDeviceLocationRepository(api: api);
    when(() => api.isLocationServiceEnabled()).thenAnswer((_) async => true);
  });

  group('access', () {
    test(
      'service off: serviceDisabled without asking for permission',
      () async {
        when(
          () => api.isLocationServiceEnabled(),
        ).thenAnswer((_) async => false);
        expect(await repo.checkAccess(), LocationAccess.serviceDisabled);
        expect(await repo.requestAccess(), LocationAccess.serviceDisabled);
        verifyNever(() => api.checkPermission());
        verifyNever(() => api.requestPermission());
      },
    );

    const expected = {
      LocationPermission.whileInUse: LocationAccess.granted,
      LocationPermission.always: LocationAccess.granted,
      LocationPermission.deniedForever: LocationAccess.deniedForever,
      LocationPermission.denied: LocationAccess.denied,
      LocationPermission.unableToDetermine: LocationAccess.denied,
    };
    for (final MapEntry(key: permission, value: access) in expected.entries) {
      test('$permission maps to $access', () async {
        when(() => api.checkPermission()).thenAnswer((_) async => permission);
        when(() => api.requestPermission()).thenAnswer((_) async => permission);
        expect(await repo.checkAccess(), access);
        expect(await repo.requestAccess(), access);
      });
    }

    test('platform failures become typed errors', () async {
      when(() => api.checkPermission()).thenThrow(Exception('boom'));
      await expectLater(repo.checkAccess(), throwsA(isA<UnknownError>()));
    });
  });

  group('watchPosition', () {
    late StreamController<Position> source;

    setUp(() {
      source = StreamController<Position>();
      when(
        () => api.getPositionStream(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) => source.stream);
    });
    tearDown(() => unawaited(source.close()));

    test('maps positions, UTC timestamps and unknown heading/speed', () async {
      final future = repo.watchPosition().take(2).toList();
      source
        ..add(position(timestamp: DateTime(2026, 10, 7, 12)))
        ..add(position(heading: -1, speed: -1));
      final result = await future;
      expect(result.first.point, const GeoPoint(19.4, -99.1));
      expect(result.first.timestamp.isUtc, isTrue);
      expect(result.first.heading, 90);
      expect(result.first.speedMps, 5);
      expect(result.first.accuracyMeters, 8);
      expect(result.last.heading, isNull);
      expect(result.last.speedMps, isNull);
    });

    test('maps stream exceptions to typed errors', () async {
      final errors = <Object>[];
      final sub = repo.watchPosition().listen((_) {}, onError: errors.add);
      source
        ..addError(const PermissionDeniedException('no'))
        ..addError(const LocationServiceDisabledException())
        ..addError(StateError('other'));
      await pumpEventQueue();
      expect(errors[0], isA<LocationPermissionDeniedError>());
      expect((errors[0] as LocationPermissionDeniedError).permanently, isFalse);
      expect(errors[1], isA<LocationServiceDisabledError>());
      expect(errors[2], isA<UnknownError>());
      await sub.cancel();
    });
  });

  test(
    'openAppSettings / openLocationSettings delegate and never throw',
    () async {
      when(() => api.openAppSettings()).thenAnswer((_) async => true);
      when(
        () => api.openLocationSettings(),
      ).thenThrow(Exception('no activity'));
      await repo.openAppSettings();
      await repo.openLocationSettings();
      verify(() => api.openAppSettings()).called(1);
      verify(() => api.openLocationSettings()).called(1);
    },
  );
}
