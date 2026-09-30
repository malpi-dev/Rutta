import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/presentation/external_links.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/presentation/skeleton.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/auth/presentation/session_providers.dart';
import 'package:rutta/features/orders/presentation/widgets/section_header.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';
import 'package:rutta/features/settings/presentation/theme_controller.dart';
import 'package:rutta/l10n/app_localizations.dart';

const _logoAsset = 'assets/icon/splash_logo.png';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final open = ref.watch(externalLinkOpenerProvider);

    Widget link(String text, Uri uri) => ListTile(
      title: Text(text),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => unawaited(open(uri)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          SectionHeader(title: l10n.appearanceSection),
          const _ThemeSelector(),
          SectionHeader(title: l10n.accountSection),
          const _AccountSection(),
          SectionHeader(title: l10n.creditsSection),
          link(l10n.creditsOsm, ExternalLinks.osmCopyright),
          link(l10n.creditsTiles, ExternalLinks.osmTilePolicy),
          link(l10n.creditsOsrm, ExternalLinks.osrm),
          SectionHeader(title: l10n.aboutSection),
          ListTile(
            key: const Key('settings-licenses'),
            title: Text(l10n.licenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationIcon: const Padding(
                padding: EdgeInsets.all(8),
                child: _Logo(size: 56),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White mark inside a circle of the primary color.
class _Logo extends StatelessWidget {
  const _Logo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
      child: Image.asset(_logoAsset, height: size),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(themeControllerProvider);

    ButtonSegment<ThemePreference> segment(
      ThemePreference value,
      String id,
      String label,
    ) => ButtonSegment(
      value: value,
      label: Semantics(
        identifier: id,
        child: Text(label, key: Key(id)),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<ThemePreference>(
        key: const Key('settings-theme'),
        segments: [
          segment(
            ThemePreference.system,
            'settings-theme-system',
            l10n.themeSystem,
          ),
          segment(
            ThemePreference.light,
            'settings-theme-light',
            l10n.themeLight,
          ),
          segment(ThemePreference.dark, 'settings-theme-dark', l10n.themeDark),
        ],
        selected: {current},
        showSelectedIcon: false,
        onSelectionChanged: (s) => unawaited(
          ref.read(themeControllerProvider.notifier).change(s.first),
        ),
      ),
    );
  }
}

String _roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
  UserRole.customer => l10n.roleCustomer,
  UserRole.courier => l10n.roleCourier,
};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(appModeControllerProvider);

    if (mode case AppModeDemo(:final role)) {
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: Text(l10n.demoExploringAs(_roleLabel(l10n, role))),
          ),
          _ActionButton(
            id: 'settings-exit-demo',
            label: l10n.exitDemo,
            onPressed: () =>
                ref.read(appModeControllerProvider.notifier).exitDemo(),
          ),
        ],
      );
    }

    final session = ref.watch(sessionStateProvider);
    if (session.isLoading && !session.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonBox(height: 56, radius: 12),
      );
    }
    return switch (session.value) {
      SessionSignedIn(:final profile, :final email) => Column(
        children: [
          ListTile(
            leading: CircleAvatar(child: Text(_initials(profile.fullName))),
            title: Text(profile.fullName),
            subtitle: Text('$email · ${_roleLabel(l10n, profile.role)}'),
          ),
          _ActionButton(
            id: 'settings-sign-out',
            label: l10n.signOut,
            onPressed: () => unawaited(_confirmSignOut(context, ref)),
          ),
        ],
      ),
      _ => _ActionButton(
        id: 'settings-sign-out',
        label: l10n.signOut,
        onPressed: () => unawaited(ref.read(authRepositoryProvider).signOut()),
      ),
    };
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutConfirm),
        actions: [
          TextButton(
            key: const Key('settings-sign-out-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('settings-sign-out-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.id,
    required this.label,
    required this.onPressed,
  });

  final String id;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          identifier: id,
          container: true,
          child: OutlinedButton(
            key: Key(id),
            onPressed: onPressed,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
