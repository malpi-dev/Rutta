import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rutta/core/presentation/empty_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/router/routes.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        children: [
          Expanded(
            child: EmptyState(icon: Icons.construction, title: l10n.comingSoon),
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
