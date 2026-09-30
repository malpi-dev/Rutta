import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/presentation/empty_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';

/// Provisional: the full screen arrives in phase 12. For now it only offers
/// sign out (live) or exit demo (demo).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDemo = ref.watch(appModeControllerProvider) is AppModeDemo;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Column(
        children: [
          Expanded(
            child: EmptyState(icon: Icons.construction, title: l10n.comingSoon),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isDemo
                  ? Semantics(
                      identifier: 'settings-exit-demo',
                      container: true,
                      child: OutlinedButton(
                        key: const Key('settings-exit-demo'),
                        onPressed: () => ref
                            .read(appModeControllerProvider.notifier)
                            .exitDemo(),
                        child: Text(l10n.exitDemo),
                      ),
                    )
                  : Semantics(
                      identifier: 'settings-sign-out',
                      container: true,
                      child: OutlinedButton(
                        key: const Key('settings-sign-out'),
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        child: Text(l10n.signOut),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
