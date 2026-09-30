import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/supabase/live_query.dart';
import 'package:rutta/core/supabase/realtime_status_hub.dart';
import 'package:rutta/core/supabase/supabase_error_mapper.dart';
import 'package:rutta/features/tracking/data/courier_location_mapper.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/domain/tracking_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTrackingRepository implements TrackingRepository {
  SupabaseTrackingRepository(this._client, this._hub);

  final SupabaseClient _client;
  final RealtimeStatusHub _hub;

  SupabaseQuerySchema get _db => _client.schema('rutta');

  @override
  Stream<CourierLocation?> watchCourierLocation(String orderId) =>
      liveQuery<CourierLocation?>(
        client: _client,
        hub: _hub,
        channelName: nextChannelName('location', orderId),
        fetch: () => guardSupabase(() async {
          final row = await _db
              .from('courier_locations')
              .select()
              .eq('order_id', orderId)
              .maybeSingle();
          return row == null ? null : courierLocationFromRow(row);
        }),
        // A position arrives every ~5 s: emit it straight from the payload
        // instead of re-reading. (Filtered DELETEs are not delivered: the
        // marker disappears because the order stops being in progress.)
        bind: (channel, refetch, emit) => channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'rutta',
          table: 'courier_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              emit(null);
              return;
            }
            try {
              emit(courierLocationFromRow(payload.newRecord));
            } on DomainError {
              refetch();
            }
          },
        ),
      );

  @override
  Future<void> publishLocation(CourierLocation location) async {
    try {
      await _db
          .from('courier_locations')
          .upsert(
            courierLocationToUpsertRow(location),
            onConflict: 'courier_id',
          )
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (error) {
      // RLS: the order is not in progress or not assigned to the caller.
      if (error.code == '42501') throw const NoActiveOrderError();
      throw mapSupabaseError(error);
    } on Object catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
