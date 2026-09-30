// ignore: one_member_abstracts, port implemented by Realtime and the demo mock.
abstract interface class ConnectionMonitor {
  /// true while the live channel is connected. Emits the current value first.
  Stream<bool> watchIsConnected();
}
