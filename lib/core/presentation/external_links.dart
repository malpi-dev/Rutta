import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'external_links.g.dart';

typedef ExternalLinkOpener = Future<void> Function(Uri uri);

/// Opens https links in the browser. Overridden in tests. Failures are
/// swallowed: a missing browser must not crash the app.
@Riverpod(keepAlive: true)
ExternalLinkOpener externalLinkOpener(Ref ref) => (uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object catch (e) {
    debugPrint('Could not open $uri: $e');
  }
};

abstract final class ExternalLinks {
  static final Uri osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );
  static final Uri osmTilePolicy = Uri.parse(
    'https://operations.osmfoundation.org/policies/tiles/',
  );
  static final Uri osrm = Uri.parse('https://project-osrm.org/');
}
