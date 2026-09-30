import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/core/map/rutta_map.dart';

class _FakeDelegate implements RuttaMapDelegate {
  List<GeoPoint>? fitted;
  EdgeInsets? fitPadding;
  GeoPoint? centered;
  double? centeredZoom;

  @override
  void fitPoints(
    List<GeoPoint> points, {
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    fitted = points;
    fitPadding = padding;
  }

  @override
  void centerOn(GeoPoint point, {double? zoom}) {
    centered = point;
    centeredZoom = zoom;
  }
}

void main() {
  const a = GeoPoint(1, 2);
  const b = GeoPoint(3, 4);

  test('calls without a delegate are ignored', () {
    final c = RuttaMapController();
    expect(c.isAttached, isFalse);
    expect(() => c.fitPoints([a, b]), returnsNormally);
    expect(() => c.centerOn(a, zoom: 15), returnsNormally);
  });

  test('forwards fitPoints and centerOn to the attached delegate', () {
    final c = RuttaMapController();
    final d = _FakeDelegate();
    c
      ..attach(d)
      ..fitPoints([a, b], padding: const EdgeInsets.all(10))
      ..centerOn(b, zoom: 15);
    expect(c.isAttached, isTrue);
    expect(d.fitted, [a, b]);
    expect(d.fitPadding, const EdgeInsets.all(10));
    expect(d.centered, b);
    expect(d.centeredZoom, 15);
  });

  test('default padding is 48', () {
    final c = RuttaMapController();
    final d = _FakeDelegate();
    c
      ..attach(d)
      ..fitPoints([a]);
    expect(d.fitPadding, const EdgeInsets.all(48));
  });

  test('detach of another delegate keeps the current one', () {
    final c = RuttaMapController();
    final d = _FakeDelegate();
    c
      ..attach(d)
      ..detach(_FakeDelegate());
    expect(c.isAttached, isTrue);
    c.detach(d);
    expect(c.isAttached, isFalse);
  });
}
