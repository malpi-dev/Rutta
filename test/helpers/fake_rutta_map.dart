import 'package:flutter/material.dart';
import 'package:rutta/core/map/rutta_map.dart';

/// Test double: no network, no timers. Renders one widget per marker and one
/// Text per polyline id so tests can assert on them.
class FakeRuttaMap extends StatelessWidget {
  const FakeRuttaMap(this.props, {super.key});

  final RuttaMapProps props;
  static RuttaMapProps? lastProps;

  @override
  Widget build(BuildContext context) {
    lastProps = props;
    return ColoredBox(
      key: const Key('fake-map'),
      color: Colors.grey,
      child: Column(
        children: [
          for (final m in props.markers)
            KeyedSubtree(key: Key('marker-${m.id}'), child: m.child),
          for (final p in props.polylines)
            Text('polyline:${p.id}:${p.points.length}'),
        ],
      ),
    );
  }
}
