import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';

void main() {
  testWidgets('shows the app name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RuttaApp()));
    await tester.pumpAndSettle();
    expect(find.text('Rutta'), findsOneWidget);
  });
}
