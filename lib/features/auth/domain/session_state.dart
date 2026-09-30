import 'package:meta/meta.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';

@immutable
sealed class SessionState {
  const SessionState();
}

@immutable
final class SessionSignedOut extends SessionState {
  const SessionSignedOut();

  @override
  bool operator ==(Object other) => other is SessionSignedOut;

  @override
  int get hashCode => (SessionSignedOut).hashCode;

  @override
  String toString() => 'SessionSignedOut()';
}

/// Signed in to Supabase but without a Rutta profile yet (new user or coming
/// from another portfolio app).
@immutable
final class SessionNeedsProfile extends SessionState {
  const SessionNeedsProfile(this.email);

  final String email;

  @override
  bool operator ==(Object other) =>
      other is SessionNeedsProfile && other.email == email;

  @override
  int get hashCode => Object.hash(SessionNeedsProfile, email);

  @override
  String toString() => 'SessionNeedsProfile($email)';
}

@immutable
final class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.profile, this.email);

  final UserProfile profile;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is SessionSignedIn &&
      other.profile == profile &&
      other.email == email;

  @override
  int get hashCode => Object.hash(SessionSignedIn, profile, email);

  @override
  String toString() => 'SessionSignedIn($profile, $email)';
}
