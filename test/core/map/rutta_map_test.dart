import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/map/map_models.dart';
import 'package:rutta/core/map/rutta_map.dart';

import '../../helpers/fake_rutta_map.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_overrides.dart';

void main() {
  testWidgets('RuttaMap renders the overridden implementation with props', (
    tester,
  ) async {
    const p = GeoPoint(19.4, -99.1);
    await pumpApp(
      tester,
      const RuttaMap(
        props: RuttaMapProps(
          initialFit: [p],
          markers: [
            MapMarker(id: 'pickup', point: p, child: Text('pickup-child')),
          ],
          polylines: [
            MapPolyline(id: 'route', points: [p, p], color: Colors.red),
          ],
        ),
      ),
      overrides: testOverrides(),
    );
    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    expect(find.byKey(const Key('marker-pickup')), findsOneWidget);
    expect(find.text('pickup-child'), findsOneWidget);
    expect(find.text('polyline:route:2'), findsOneWidget);
    expect(FakeRuttaMap.lastProps!.initialFit, [p]);
    await tester.pumpWidget(const SizedBox());
  });
}
