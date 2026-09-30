import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutta/core/config/env.dart';
import 'package:rutta/core/presentation/error_messages.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/presentation/root_scaffold_messenger.dart';
import 'package:rutta/features/auth/presentation/auth_controllers.dart';
import 'package:rutta/features/auth/presentation/widgets/auth_scaffold.dart';

const _resendSeconds = 60;

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify() {
    return ref
        .read(verifyCodeControllerProvider.notifier)
        .verify(email: widget.email, code: _code.text);
  }

  Future<void> _resend() async {
    final sent = await ref
        .read(verifyCodeControllerProvider.notifier)
        .resend(widget.email);
    if (!sent || !mounted) return;
    _startCountdown();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(context.l10n.codeSent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(verifyCodeControllerProvider);
    final busy = state.isLoading;
    final showMailHint =
        kDebugMode &&
        (Env.supabaseUrl.contains('10.0.2.2') ||
            Env.supabaseUrl.contains('127.0.0.1'));

    return AuthScaffold(
      appBar: AppBar(),
      children: [
        Text(
          l10n.verifyTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.verifySubtitle(widget.email),
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Semantics(
          identifier: 'verify-code',
          child: TextField(
            key: const Key('verify-code'),
            controller: _code,
            enabled: !busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8),
            onChanged: (value) {
              if (value.length == 6 && !busy) unawaited(_verify());
            },
            decoration: InputDecoration(
              counterText: '',
              errorText: state.hasError ? messageFor(state.error!, l10n) : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          identifier: 'verify-submit',
          container: true,
          child: FilledButton(
            key: const Key('verify-submit'),
            onPressed: busy ? null : _verify,
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.verify),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'verify-resend',
          container: true,
          child: TextButton(
            key: const Key('verify-resend'),
            onPressed: (busy || _secondsLeft > 0) ? null : _resend,
            child: Text(
              _secondsLeft > 0 ? l10n.resendIn(_secondsLeft) : l10n.resendCode,
            ),
          ),
        ),
        TextButton(
          key: const Key('verify-use-different-email'),
          onPressed: busy ? null : () => context.pop(),
          child: Text(l10n.useDifferentEmail),
        ),
        if (showMailHint) ...[
          const SizedBox(height: 8),
          Text(
            l10n.localMailHint,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
