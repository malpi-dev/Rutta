import 'package:rutta/features/tracking/domain/courier_location.dart';

abstract interface class TrackingRepository {
  /// Customer side: the courier's last position for [orderId] while the order
  /// is in progress; null otherwise.
  Stream<CourierLocation?> watchCourierLocation(String orderId);

  /// Courier side: upserts the courier's last position. Throws
  /// `NoActiveOrderError` if the order is not in progress or not assigned to
  /// the caller.
  Future<void> publishLocation(CourierLocation location);
}
