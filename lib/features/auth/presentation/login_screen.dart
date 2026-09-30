import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutta/core/presentation/empty_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/router/routes.dart';
import 'package:rutta/features/demo/presentation/demo_role_picker_sheet.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        children: [
          Expanded(
            child: EmptyState(icon: Icons.construction, title: l10n.comingSoon),
          ),
          Semantics(
            identifier: 'login-explore-demo',
            child: OutlinedButton(
              key: const Key('login-explore-demo'),
              onPressed: () => showDemoRolePicker(context, ref),
              child: Text(l10n.exploreDemo),
            ),
          ),
          if (kDebugMode)
            TextButton(
              key: const Key('dev-map-preview'),
              onPressed: () => context.push(Routes.devMap),
              child: Text(l10n.devMapPreview),
            ),
        ],
      ),
    );
  }
}
