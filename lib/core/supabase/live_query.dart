import 'dart:async';

import 'package:rutta/core/supabase/realtime_status_hub.dart';
import 'package:rutta/core/supabase/supabase_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

var _channelCounter = 0;

/// Unique channel name: `rutta:<topic>:<id>:<n>`. The suffix keeps two screens
/// watching the same thing from joining the same Realtime topic.
String nextChannelName(String topic, String id) =>
    'rutta:$topic:$id:${_channelCounter++}';

/// Initial fetch + postgres_changes subscription. On every change (debounced)
/// and on every (re)subscribe it fetches again, so nothing is lost across
/// reconnections (definition 8.4).
///
/// [bind] registers the `onPostgresChanges` listeners. It receives `refetch`
/// (schedule a debounced re-read) and `emit` (push a value straight from the
/// payload, for high-frequency streams that should not re-read every time).
Stream<T> liveQuery<T>({
  required SupabaseClient client,
  required RealtimeStatusHub hub,
  required String channelName,
  required Future<T> Function() fetch,
  required void Function(
    RealtimeChannel channel,
    void Function() refetch,
    void Function(T value) emit,
  )
  bind,
  Duration debounce = const Duration(milliseconds: 250),
}) {
  late StreamController<T> controller;
  RealtimeChannel? channel;
  Timer? timer;
  var sequence = 0;
  var hasValue = false;

  Future<void> run() async {
    final mine = ++sequence;
    try {
      final value = await fetch();
      if (mine != sequence || controller.isClosed) return;
      hasValue = true;
      controller.add(value);
    } on Object catch (error) {
      if (mine != sequence || controller.isClosed) return;
      // After a first value, a failed re-read is ignored: the hub already
      // reports the broken connection and the next (re)subscribe re-reads.
      if (!hasValue) controller.addError(mapSupabaseError(error));
    }
  }

  void scheduleRefetch() {
    timer?.cancel();
    timer = Timer(debounce, () => unawaited(run()));
  }

  void emit(T value) {
    // Invalidate in-flight reads: this payload is newer.
    sequence++;
    if (controller.isClosed) return;
    hasValue = true;
    controller.add(value);
  }

  controller = StreamController<T>(
    onListen: () {
      unawaited(run());
      final ch = client.channel(channelName);
      channel = ch;
      bind(ch, scheduleRefetch, emit);
      ch.subscribe((status, error) {
        hub.report(channelName, status);
        if (status == RealtimeSubscribeStatus.subscribed) scheduleRefetch();
      });
    },
    onCancel: () async {
      timer?.cancel();
      sequence++;
      hub.remove(channelName);
      final ch = channel;
      if (ch != null) {
        try {
          await client.removeChannel(ch);
        } on Object {
          // Channel teardown must never throw into the caller.
        }
      }
    },
  );
  return controller.stream;
}
