import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';

/// Persistent strip shown on every screen while the app runs in demo mode.
class DemoBanner extends ConsumerWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      key: const Key('demo-banner'),
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.science_outlined,
                size: 18,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.demoBannerMessage,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
              Semantics(
                identifier: 'demo-exit',
                child: TextButton(
                  key: const Key('demo-exit'),
                  onPressed: () =>
                      ref.read(appModeControllerProvider.notifier).exitDemo(),
                  child: Text(l10n.exitDemo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
