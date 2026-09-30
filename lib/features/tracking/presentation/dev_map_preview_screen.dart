import 'package:flutter/material.dart';
import 'package:rutta/core/domain/geo.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/map/map_models.dart';
import 'package:rutta/core/map/rutta_map.dart';
import 'package:rutta/core/theme/rutta_colors.dart';
import 'package:rutta/features/tracking/presentation/widgets/map_pins.dart';

/// TEMPORARY development screen (removed in phase 06). The route comes from
/// the router (composition root) so this file does not import `data/`.
class DevMapPreviewScreen extends StatefulWidget {
  const DevMapPreviewScreen({
    required this.route,
    required this.pickup,
    required this.dropoff,
    super.key,
  });

  final List<GeoPoint> route;
  final GeoPoint pickup;
  final GeoPoint dropoff;

  @override
  State<DevMapPreviewScreen> createState() => _DevMapPreviewScreenState();
}

class _DevMapPreviewScreenState extends State<DevMapPreviewScreen> {
  final _controller = RuttaMapController();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mid = pointAlongRoute(
      widget.route,
      routeLengthMeters(widget.route) / 2,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Map preview')),
      body: RuttaMap(
        props: RuttaMapProps(
          initialFit: widget.route,
          controller: _controller,
          darkMode: Theme.of(context).brightness == Brightness.dark,
          polylines: [
            MapPolyline(
              id: 'route',
              points: widget.route,
              color: colors.routeRemaining,
            ),
          ],
          markers: [
            MapMarker(
              id: 'pickup',
              point: widget.pickup,
              alignment: Alignment.topCenter,
              child: const PickupPin(),
            ),
            MapMarker(
              id: 'dropoff',
              point: widget.dropoff,
              alignment: Alignment.topCenter,
              child: const DropoffPin(),
            ),
            MapMarker(
              id: 'courier',
              point: mid.point,
              width: 36,
              height: 36,
              child: const CourierPin(headingDegrees: 0, stale: false),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _controller.fitPoints(widget.route),
        child: const Icon(Icons.fit_screen),
      ),
    );
  }
}
