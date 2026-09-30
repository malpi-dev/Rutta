import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/auth/data/profile_mapper.dart';

void main() {
  test('maps a row to a UserProfile', () {
    final profile = userProfileFromRow({
      'id': 'u1',
      'full_name': 'Carlos Méndez',
      'role': 'courier',
      'phone': '+52 55 1234 5678',
    });
    expect(profile.id, 'u1');
    expect(profile.fullName, 'Carlos Méndez');
    expect(profile.role, UserRole.courier);
    expect(profile.phone, '+52 55 1234 5678');
  });

  test('phone is optional', () {
    final profile = userProfileFromRow({
      'id': 'u1',
      'full_name': 'Ana',
      'role': 'customer',
      'phone': null,
    });
    expect(profile.phone, isNull);
  });

  test('an unknown role is an UnknownError', () {
    expect(
      () => userProfileFromRow({
        'id': 'u1',
        'full_name': 'Ana',
        'role': 'admin',
      }),
      throwsA(isA<UnknownError>()),
    );
  });
}
