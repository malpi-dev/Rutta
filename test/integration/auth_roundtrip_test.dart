@Tags(['supabase'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/features/auth/data/supabase_auth_repository.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Runs against `supabase start` (local). Enable with:
/// `RUTTA_IT=1 RUTTA_PUBLISHABLE_KEY=<key> flutter test --tags supabase test/integration/`
final _enabled = Platform.environment['RUTTA_IT'] == '1';
const _mailpit = 'http://127.0.0.1:54324';

Future<String> _latestCodeFor(String email) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final list =
        jsonDecode(
              (await http.get(Uri.parse('$_mailpit/api/v1/messages'))).body,
            )
            as Map<String, dynamic>;
    final messages = (list['messages'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final message in messages) {
      final to = (message['To'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (to.any((a) => a['Address'] == email)) {
        final detail =
            jsonDecode(
                  (await http.get(
                    Uri.parse('$_mailpit/api/v1/message/${message['ID']}'),
                  )).body,
                )
                as Map<String, dynamic>;
        final text = '${detail['Text']}${detail['HTML']}';
        final match = RegExp(r'\b\d{6}\b').firstMatch(text);
        if (match != null) return match.group(0)!;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('No email for $email in Mailpit');
}

void main() {
  group(
    'auth roundtrip against local Supabase',
    skip: _enabled ? false : 'Set RUTTA_IT=1 (and supabase start) to run',
    () {
      test('OTP login, onboarding with ensure_profile, sign out', () async {
        final key = Platform.environment['RUTTA_PUBLISHABLE_KEY'] ?? '';
        final client = SupabaseClient(
          'http://127.0.0.1:54321',
          key,
          // No asyncStorage outside Supabase.initialize: PKCE is unavailable.
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );
        addTearDown(client.dispose);
        final repo = SupabaseAuthRepository(client);
        final states = <SessionState>[];
        final sub = repo.watchSession().listen(states.add);
        addTearDown(sub.cancel);

        Future<void> waitFor(bool Function(SessionState) test) async {
          for (var i = 0; i < 40; i++) {
            if (states.isNotEmpty && test(states.last)) return;
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
          fail('Timed out. States: $states');
        }

        final email = 'it-${DateTime.now().millisecondsSinceEpoch}@rutta.test';
        // A bare SupabaseClient (no Supabase.initialize) emits no
        // initialSession event, so the first state arrives after verifyCode.
        await repo.sendCode(email);
        final code = await _latestCodeFor(email);
        await repo.verifyCode(email: email, code: code);
        await waitFor((s) => s is SessionNeedsProfile);

        final profile = await repo.ensureProfile('IT User');
        expect(profile.fullName, 'IT User');
        expect(profile.role, UserRole.customer);
        await waitFor((s) => s is SessionSignedIn);
        expect((states.last as SessionSignedIn).profile.fullName, 'IT User');

        // Idempotent: the second call returns the existing profile.
        final again = await repo.ensureProfile('Other');
        expect(again.fullName, 'IT User');

        await repo.signOut();
        await waitFor((s) => s is SessionSignedOut);
      });
    },
  );
}
