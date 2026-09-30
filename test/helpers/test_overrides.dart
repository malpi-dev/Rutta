import 'package:flutter_riverpod/misc.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/clock.dart';
import 'package:rutta/features/settings/data/in_memory_settings_repository.dart';

/// Base overrides for full-app tests.
List<Override> testOverrides() => [
  settingsRepositoryProvider.overrideWithValue(InMemorySettingsRepository()),
  clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 10, 7, 18))),
];
