import 'dart:async';

import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/supabase/supabase_error_mapper.dart';
import 'package:rutta/features/auth/data/profile_mapper.dart';
import 'package:rutta/features/auth/domain/auth_repository.dart';
import 'package:rutta/features/auth/domain/auth_validators.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// Fired after the profile is created so [watchSession] recomputes.
  final _profileChanged = StreamController<void>.broadcast();

  @override
  Stream<SessionState> watchSession() {
    late StreamController<SessionState> controller;
    StreamSubscription<AuthState>? authSub;
    StreamSubscription<void>? profileSub;
    var sequence = 0;
    SessionState? last;

    Future<void> recompute(Session? session) async {
      final mine = ++sequence;
      try {
        final SessionState next;
        if (session == null) {
          next = const SessionSignedOut();
        } else {
          final user = session.user;
          final email = user.email ?? '';
          final row = await guardSupabase(
            () => _client
                .schema('rutta')
                .from('profiles')
                .select('id, full_name, role, phone')
                .eq('id', user.id)
                .maybeSingle(),
          );
          next = row == null
              ? SessionNeedsProfile(email)
              : SessionSignedIn(userProfileFromRow(row), email);
        }
        // A newer event arrived while querying: drop this result.
        if (mine != sequence || controller.isClosed) return;
        if (next == last) return;
        last = next;
        controller.add(next);
      } on Object catch (error) {
        if (mine != sequence || controller.isClosed) return;
        controller.addError(mapSupabaseError(error));
      }
    }

    controller = StreamController<SessionState>(
      onListen: () {
        authSub = _client.auth.onAuthStateChange.listen(
          (state) {
            if (state.event == AuthChangeEvent.tokenRefreshed) return;
            unawaited(recompute(state.session));
          },
          // Without a handler, network errors would crash the zone.
          onError: (Object error) {
            if (controller.isClosed) return;
            controller.addError(mapSupabaseError(error));
          },
        );
        profileSub = _profileChanged.stream.listen(
          (_) => unawaited(recompute(_client.auth.currentSession)),
        );
      },
      onCancel: () async {
        await authSub?.cancel();
        await profileSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> sendCode(String email) async {
    if (!isValidEmail(email)) {
      throw const AuthError(AuthErrorKind.invalidEmail);
    }
    await guardSupabase(
      () => _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
      ),
    );
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    if (!isValidOtpCode(code)) {
      throw const AuthError(AuthErrorKind.invalidCode);
    }
    await guardSupabase(
      () => _client.auth.verifyOTP(
        type: OtpType.email,
        email: email.trim(),
        token: code,
      ),
    );
  }

  @override
  Future<UserProfile> ensureProfile(String fullName) async {
    final name = validateFullName(fullName);
    final row = await guardSupabase(
      () => _client
          .schema('rutta')
          .rpc<Map<String, dynamic>>(
            'ensure_profile',
            params: {'p_full_name': name},
          ),
    );
    final profile = userProfileFromRow(row);
    _profileChanged.add(null);
    return profile;
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on Object catch (_) {
      // Local sign-out always succeeds; a network failure must not trap the
      // user in the app.
    }
  }
}
