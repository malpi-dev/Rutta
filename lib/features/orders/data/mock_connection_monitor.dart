import 'dart:async';

import 'package:rutta/features/orders/domain/connection_monitor.dart';

class MockConnectionMonitor implements ConnectionMonitor {
  MockConnectionMonitor() : _controlled = null;

  /// For tests: the caller drives the connection state.
  MockConnectionMonitor.controlled(StreamController<bool> controller)
    : _controlled = controller;

  final StreamController<bool>? _controlled;

  @override
  Stream<bool> watchIsConnected() =>
      _controlled?.stream ?? Stream<bool>.value(true);
}
