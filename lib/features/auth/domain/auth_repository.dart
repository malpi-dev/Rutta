import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';

abstract interface class AuthRepository {
  /// Emits the current state first and then every change (sign in, profile
  /// created, sign out).
  Stream<SessionState> watchSession();

  /// Sends the 6-digit code. Throws `AuthError(invalidEmail | rateLimited)`,
  /// `NetworkError`...
  Future<void> sendCode(String email);

  /// Throws `AuthError(invalidCode | codeExpired)`, `NetworkError`...
  Future<void> verifyCode({required String email, required String code});

  /// Calls `rutta.ensure_profile`. Idempotent. Afterwards [watchSession] emits
  /// `SessionSignedIn`.
  Future<UserProfile> ensureProfile(String fullName);

  /// Never throws because of the network (local sign-out always succeeds).
  Future<void> signOut();
}
