import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/auth/data/mock_auth_repository.dart';
import 'package:rutta/features/auth/domain/demo_otp.dart';
import 'package:rutta/features/auth/domain/session_state.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';

import '../../../helpers/demo.dart';

void main() {
  test(
    'full flow: signed out -> verify -> needs profile -> signed in -> out',
    () async {
      final repo = MockAuthRepository();
      final states = Collected<SessionState>(repo.watchSession());
      await pumpEventQueue();
      expect(states.values, [const SessionSignedOut()]);

      await repo.sendCode('ana@rutta.test');
      await repo.verifyCode(email: 'ana@rutta.test', code: demoOtpCode);
      await pumpEventQueue();
      expect(states.values.last, const SessionNeedsProfile('ana@rutta.test'));

      final profile = await repo.ensureProfile('  Ana  ');
      expect(profile.fullName, 'Ana');
      expect(profile.role, UserRole.customer);
      await pumpEventQueue();
      expect(states.values.last, SessionSignedIn(profile, 'ana@rutta.test'));

      await repo.signOut();
      await pumpEventQueue();
      expect(states.values.last, const SessionSignedOut());
      states.cancel();
    },
  );

  test('wrong code throws invalidCode and keeps the session out', () async {
    final repo = MockAuthRepository();
    await expectLater(
      repo.verifyCode(email: 'ana@rutta.test', code: '000000'),
      throwsA(
        isA<AuthError>().having(
          (e) => e.kind,
          'kind',
          AuthErrorKind.invalidCode,
        ),
      ),
    );
  });

  test('invalid email throws invalidEmail', () async {
    final repo = MockAuthRepository();
    await expectLater(
      repo.sendCode('nope'),
      throwsA(
        isA<AuthError>().having(
          (e) => e.kind,
          'kind',
          AuthErrorKind.invalidEmail,
        ),
      ),
    );
  });

  test('empty name is a ValidationError', () async {
    final repo = MockAuthRepository();
    await repo.verifyCode(email: 'ana@rutta.test', code: demoOtpCode);
    await expectLater(
      repo.ensureProfile('  '),
      throwsA(isA<ValidationError>()),
    );
  });

  test('a returning user goes straight to signed in', () async {
    const courier = UserProfile(
      id: 'c1',
      fullName: 'Carlos',
      role: UserRole.courier,
    );
    final repo = MockAuthRepository(
      existingProfile: courier,
      existingProfileEmail: 'courier1@rutta.test',
    );
    final states = Collected<SessionState>(repo.watchSession());
    await repo.verifyCode(email: 'courier1@rutta.test', code: demoOtpCode);
    await pumpEventQueue();
    expect(
      states.values.last,
      const SessionSignedIn(courier, 'courier1@rutta.test'),
    );
    states.cancel();
  });
}
