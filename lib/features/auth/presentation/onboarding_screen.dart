import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/presentation/error_messages.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/features/auth/presentation/auth_controllers.dart';
import 'package:rutta/features/auth/presentation/widgets/auth_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() {
    return ref.read(onboardingControllerProvider.notifier).submit(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final busy = state.isLoading;
    final error = state.error;
    final errorText = switch (error) {
      null => null,
      ValidationError(:final reason) => validationMessage(reason, l10n),
      _ => messageFor(error, l10n),
    };

    return AuthScaffold(
      children: [
        Text(
          l10n.onboardingTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingSubtitle,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Semantics(
          identifier: 'onboarding-name',
          child: TextField(
            key: const Key('onboarding-name'),
            controller: _name,
            enabled: !busy,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
              errorText: errorText,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          identifier: 'onboarding-continue',
          container: true,
          child: FilledButton(
            key: const Key('onboarding-continue'),
            onPressed: busy ? null : _submit,
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.continueLabel),
          ),
        ),
        TextButton(
          key: const Key('onboarding-use-different-account'),
          onPressed: busy
              ? null
              : () => ref.read(authRepositoryProvider).signOut(),
          child: Text(l10n.useDifferentAccount),
        ),
      ],
    );
  }
}
