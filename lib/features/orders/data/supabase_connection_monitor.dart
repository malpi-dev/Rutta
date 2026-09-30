import 'package:rutta/core/supabase/realtime_status_hub.dart';
import 'package:rutta/features/orders/domain/connection_monitor.dart';

class SupabaseConnectionMonitor implements ConnectionMonitor {
  SupabaseConnectionMonitor(this._hub);

  final RealtimeStatusHub _hub;

  @override
  Stream<bool> watchIsConnected() => _hub.watchIsConnected();
}
