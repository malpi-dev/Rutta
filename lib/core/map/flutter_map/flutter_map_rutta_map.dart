import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutta/core/config/env.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/map/flutter_map/lat_lng_mapper.dart';
import 'package:rutta/core/map/rutta_map.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:url_launcher/url_launcher.dart';

/// [RuttaMap] implementation on top of `flutter_map` + OpenStreetMap tiles.
class FlutterMapRuttaMap extends StatefulWidget {
  const FlutterMapRuttaMap({required this.props, super.key});

  final RuttaMapProps props;

  @override
  State<FlutterMapRuttaMap> createState() => _FlutterMapRuttaMapState();
}

class _FlutterMapRuttaMapState extends State<FlutterMapRuttaMap>
    implements RuttaMapDelegate {
  static const _maxZoom = 17.0;
  static const _tileErrorThreshold = 3;

  final _mapController = MapController();
  int _tileErrors = 0;
  bool _showUnavailable = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    widget.props.controller?.attach(this);
  }

  @override
  void didUpdateWidget(FlutterMapRuttaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.props.controller;
    final newController = widget.props.controller;
    if (!identical(oldController, newController)) {
      oldController?.detach(this);
      newController?.attach(this);
    }
  }

  @override
  void dispose() {
    widget.props.controller?.detach(this);
    _mapController.dispose();
    super.dispose();
  }

  @override
  void fitPoints(
    List<GeoPoint> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
  }) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(toLatLng(points.first), 16);
      return;
    }
    _mapController.fitCamera(_fit(points, padding));
  }

  @override
  void centerOn(GeoPoint point, {double? zoom}) {
    _mapController.move(
      toLatLng(point),
      zoom ?? _mapController.camera.zoom,
    );
  }

  CameraFit _fit(List<GeoPoint> points, EdgeInsets padding) =>
      CameraFit.coordinates(
        coordinates: points.map(toLatLng).toList(),
        padding: padding,
        maxZoom: _maxZoom,
      );

  void _onTileError() {
    _tileErrors++;
    if (_tileErrors < _tileErrorThreshold || _showUnavailable || _dismissed) {
      return;
    }
    // The callback can arrive during build.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_showUnavailable) setState(() => _showUnavailable = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final scheme = Theme.of(context).colorScheme;
    final initial = props.initialFit;
    final options = MapOptions(
      initialCameraFit: initial.length > 1
          ? _fit(initial, props.padding)
          : null,
      initialCenter: initial.isEmpty
          ? const LatLng(19.4326, -99.1332)
          : toLatLng(initial.first),
      initialZoom: 16,
      backgroundColor: scheme.surfaceContainerHighest,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
    );
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: options,
          children: [
            TileLayer(
              urlTemplate: Env.mapTileUrl,
              // Required by the OSM tile usage policy.
              userAgentPackageName: Env.mapUserAgentPackage,
              tileBuilder: props.darkMode ? darkModeTileBuilder : null,
              errorTileCallback: (_, _, _) => _onTileError(),
            ),
            PolylineLayer(
              polylines: [
                for (final line in props.polylines)
                  Polyline(
                    points: line.points.map(toLatLng).toList(),
                    color: line.color,
                    strokeWidth: line.width,
                    pattern: line.dotted
                        ? const StrokePattern.dotted()
                        : const StrokePattern.solid(),
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final m in props.markers)
                  Marker(
                    key: ValueKey(m.id),
                    point: toLatLng(m.point),
                    width: m.width,
                    height: m.height,
                    alignment: m.alignment,
                    child: m.child,
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  context.l10n.mapAttributionOsm,
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_showUnavailable)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                key: const Key('map-unavailable'),
                color: scheme.surfaceContainerHigh,
                elevation: 2,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 18, color: scheme.onSurface),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.l10n.mapUnavailable,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.close,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _showUnavailable = false;
                          _dismissed = true;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
