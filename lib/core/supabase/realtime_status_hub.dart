import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Collects the subscribe status of every live channel. Connected = no
/// channel is failing.
class RealtimeStatusHub {
  final Map<String, RealtimeSubscribeStatus> _statuses = {};
  final StreamController<bool> _changes = StreamController<bool>.broadcast(
    sync: true,
  );
  bool _connected = true;

  bool get _computeConnected => !_statuses.values.any(
    (s) =>
        s == RealtimeSubscribeStatus.channelError ||
        s == RealtimeSubscribeStatus.timedOut,
  );

  void _update() {
    final next = _computeConnected;
    if (next == _connected) return;
    _connected = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  void report(String channelKey, RealtimeSubscribeStatus status) {
    _statuses[channelKey] = status;
    _update();
  }

  /// Call when a channel is removed on purpose (its `closed` is not a failure).
  void remove(String channelKey) {
    _statuses.remove(channelKey);
    _update();
  }

  /// Emits the current value first, then only changes.
  Stream<bool> watchIsConnected() {
    late StreamController<bool> controller;
    StreamSubscription<bool>? sub;
    controller = StreamController<bool>(
      onListen: () {
        controller.add(_connected);
        sub = _changes.stream.listen(controller.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  void dispose() {
    unawaited(_changes.close());
  }
}
