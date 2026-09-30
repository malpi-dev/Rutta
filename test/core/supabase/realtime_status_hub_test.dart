import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/supabase/realtime_status_hub.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late RealtimeStatusHub hub;
  late List<bool> values;

  setUp(() async {
    hub = RealtimeStatusHub();
    values = [];
    hub.watchIsConnected().listen(values.add);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() => hub.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('no channels means connected', () {
    expect(values, [true]);
  });

  test('a failing channel disconnects; recovering reconnects', () async {
    hub
      ..report('a', RealtimeSubscribeStatus.subscribed)
      ..report('a', RealtimeSubscribeStatus.timedOut)
      ..report('a', RealtimeSubscribeStatus.channelError)
      ..report('a', RealtimeSubscribeStatus.subscribed);
    await settle();
    expect(values, [true, false, true]);
  });

  test(
    'removing a failed channel reconnects; closed is not a failure',
    () async {
      hub
        ..report('a', RealtimeSubscribeStatus.channelError)
        ..report('b', RealtimeSubscribeStatus.closed);
      await settle();
      expect(values, [true, false]);
      hub.remove('a');
      await settle();
      expect(values, [true, false, true]);
    },
  );

  test('a late listener gets the current value first', () async {
    hub.report('a', RealtimeSubscribeStatus.timedOut);
    final late = <bool>[];
    hub.watchIsConnected().listen(late.add);
    await settle();
    expect(late, [false]);
  });
}
