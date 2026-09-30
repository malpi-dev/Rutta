import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/presentation/error_messages.dart';
import 'package:rutta/core/presentation/error_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/features/auth/presentation/session_providers.dart';

/// Shown while the session is being read (or if reading it failed). The
/// redirect moves away from here as soon as there is a session state.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStateProvider);
    return Scaffold(
      body: switch (session) {
        AsyncError(:final error) => ErrorState(
          message: messageFor(error, context.l10n),
          onRetry: () => ref.invalidate(sessionStateProvider),
        ),
        _ => const Center(
          child: CircularProgressIndicator(key: Key('startup-loading')),
        ),
      },
    );
  }
}
