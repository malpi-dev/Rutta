import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/auth/domain/auth_validators.dart';

void main() {
  test('isValidEmail', () {
    expect(isValidEmail('a@b.co'), isTrue);
    expect(isValidEmail('  a@b.co '), isTrue);
    for (final bad in ['a@b', 'a b@c.com', '', 'ab.com', '@b.co']) {
      expect(isValidEmail(bad), isFalse, reason: bad);
    }
  });

  test('isValidOtpCode', () {
    expect(isValidOtpCode('123456'), isTrue);
    for (final bad in ['12345', '1234567', '12a456', '']) {
      expect(isValidOtpCode(bad), isFalse, reason: bad);
    }
  });

  group('validateFullName', () {
    ValidationReason? reasonOf(String input) {
      try {
        validateFullName(input);
      } on ValidationError catch (e) {
        expect(e.field, 'fullName');
        return e.reason;
      }
      return null;
    }

    test('trims', () => expect(validateFullName('  Ana '), 'Ana'));
    test('empty is required', () {
      expect(reasonOf(''), ValidationReason.required);
      expect(reasonOf('   '), ValidationReason.required);
    });
    test('81 chars is too long, 80 is fine', () {
      expect(reasonOf('a' * 81), ValidationReason.tooLong);
      expect(reasonOf('a' * 80), isNull);
    });
  });
}
