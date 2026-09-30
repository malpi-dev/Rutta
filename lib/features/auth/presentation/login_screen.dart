import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutta/core/presentation/error_messages.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/router/routes.dart';
import 'package:rutta/core/supabase/supabase_client_provider.dart';
import 'package:rutta/features/auth/presentation/auth_controllers.dart';
import 'package:rutta/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:rutta/features/demo/presentation/demo_role_picker_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    final sent = await ref
        .read(sendCodeControllerProvider.notifier)
        .send(email);
    if (sent && mounted) {
      await context.push(
        '${Routes.verify}?email=${Uri.encodeQueryComponent(email)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hasBackend = ref.watch(backendConfiguredProvider);
    final sending = ref.watch(sendCodeControllerProvider);
    final busy = sending.isLoading;

    final demoButton = Semantics(
      identifier: 'login-explore-demo',
      container: true,
      child: hasBackend
          ? OutlinedButton(
              key: const Key('login-explore-demo'),
              onPressed: () => showDemoRolePicker(context, ref),
              child: Text(l10n.exploreDemo),
            )
          : FilledButton(
              key: const Key('login-explore-demo'),
              onPressed: () => showDemoRolePicker(context, ref),
              child: Text(l10n.exploreDemo),
            ),
    );

    return AuthScaffold(
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Image.asset('assets/icon/splash_logo.png', height: 96),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.appTitle,
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.tagline,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (hasBackend) ...[
          Semantics(
            identifier: 'login-email',
            child: TextField(
              key: const Key('login-email'),
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                labelText: l10n.emailLabel,
                errorText: sending.hasError
                    ? messageFor(sending.error!, l10n)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'login-send-code',
            container: true,
            child: FilledButton(
              key: const Key('login-send-code'),
              onPressed: busy ? null : _send,
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.sendCode),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l10n.orDivider, style: theme.textTheme.bodySmall),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text(
            l10n.demoOnlyNotice,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
        demoButton,
      ],
    );
  }
}
