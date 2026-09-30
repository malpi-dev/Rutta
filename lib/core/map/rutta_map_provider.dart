import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/map/flutter_map/flutter_map_rutta_map.dart';
import 'package:rutta/core/map/rutta_map.dart';

part 'rutta_map_provider.g.dart';

@Riverpod(keepAlive: true)
RuttaMapBuilder ruttaMapBuilder(Ref ref) =>
    (props) => FlutterMapRuttaMap(props: props);
