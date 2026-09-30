import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/presentation/async_state_view.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('loading shows the skeleton', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AsyncStateView<List<int>>(
          value: const AsyncValue.loading(),
          data: (_) => const Text('data'),
        ),
      ),
    );
    expect(find.byKey(const Key('skeleton-list')), findsOneWidget);
    expect(find.text('data'), findsNothing);
  });

  testWidgets('empty data shows the empty widget', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AsyncStateView<List<int>>(
          value: const AsyncValue.data([]),
          isEmpty: (d) => d.isEmpty,
          empty: const Text('nothing here'),
          data: (_) => const Text('data'),
        ),
      ),
    );
    expect(find.text('nothing here'), findsOneWidget);
    expect(find.text('data'), findsNothing);
  });

  testWidgets('non-empty data shows the data widget', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AsyncStateView<List<int>>(
          value: const AsyncValue.data([1]),
          isEmpty: (d) => d.isEmpty,
          empty: const Text('nothing here'),
          data: (_) => const Text('data'),
        ),
      ),
    );
    expect(find.text('data'), findsOneWidget);
  });

  testWidgets('error shows its message and Retry calls back', (tester) async {
    var retried = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: AsyncStateView<List<int>>(
          value: const AsyncValue<List<int>>.error(
            NetworkError(),
            StackTrace.empty,
          ),
          data: (_) => const Text('data'),
          onRetry: () => retried++,
        ),
      ),
    );
    expect(
      find.text("You're offline. Check your connection and try again."),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('error-retry')));
    expect(retried, 1);
  });
}
