import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while a delivery is being shared.
abstract interface class ScreenAwake {
  Future<void> enable();

  Future<void> disable();
}

class WakelockScreenAwake implements ScreenAwake {
  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } on Object catch (_) {
      // Best effort: the screen may simply turn off.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } on Object catch (_) {
      // Best effort.
    }
  }
}
