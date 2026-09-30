import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/demo/data/demo_store.dart';
import 'package:rutta/features/demo/data/demo_stream.dart';
import 'package:rutta/features/tracking/domain/courier_location.dart';
import 'package:rutta/features/tracking/domain/tracking_repository.dart';

class MockTrackingRepository implements TrackingRepository {
  MockTrackingRepository(this._store);

  final DemoStore _store;

  @override
  Stream<CourierLocation?> watchCourierLocation(String orderId) => watchStore(
    _store,
    () => _store.location(orderId),
    onStart: () => _store.ensureCustomerSimulation(orderId),
  ).distinct();

  @override
  Future<void> publishLocation(CourierLocation location) async {
    final order = _store.order(location.orderId);
    if (order == null ||
        !order.status.isInProgress ||
        order.courierId != _store.currentUserId) {
      throw const NoActiveOrderError();
    }
    _store.setLocation(location.orderId, location);
  }
}
