import 'dart:async';

import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/auth/domain/auth_repository.dart';
import 'package:rutta/features/auth/domain/auth_validators.dart';
import 'package:rutta/features/auth/domain/demo_otp.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';

/// In-memory auth for tests. Accepts only [demoOtpCode].
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    this.existingProfile,
    this.existingProfileEmail,
    this.latency = Duration.zero,
  });

  /// Profile returned for [existingProfileEmail] (a returning user).
  final UserProfile? existingProfile;
  final String? existingProfileEmail;
  final Duration latency;

  SessionState _state = const SessionSignedOut();
  final _changes = StreamController<SessionState>.broadcast();

  void _emit(SessionState next) {
    _state = next;
    _changes.add(next);
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Stream<SessionState> watchSession() {
    late StreamController<SessionState> controller;
    StreamSubscription<SessionState>? sub;
    controller = StreamController<SessionState>(
      onListen: () {
        controller.add(_state);
        sub = _changes.stream.listen(controller.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> sendCode(String email) async {
    if (!isValidEmail(email)) {
      throw const AuthError(AuthErrorKind.invalidEmail);
    }
    await _wait();
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    await _wait();
    if (code != demoOtpCode) throw const AuthError(AuthErrorKind.invalidCode);
    final trimmed = email.trim();
    final profile = existingProfile;
    _emit(
      profile != null && trimmed == existingProfileEmail
          ? SessionSignedIn(profile, trimmed)
          : SessionNeedsProfile(trimmed),
    );
  }

  @override
  Future<UserProfile> ensureProfile(String fullName) async {
    final name = validateFullName(fullName);
    await _wait();
    final current = _state;
    final email = switch (current) {
      SessionNeedsProfile(:final email) => email,
      SessionSignedIn(:final email) => email,
      SessionSignedOut() => throw const UnauthorizedError(),
    };
    if (current is SessionSignedIn) return current.profile;
    final profile = UserProfile(
      id: 'mock-${email.hashCode}',
      fullName: name,
      role: UserRole.customer,
    );
    _emit(SessionSignedIn(profile, email));
    return profile;
  }

  @override
  Future<void> signOut() async {
    _emit(const SessionSignedOut());
  }
}
