import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/user_role.dart';

void main() {
  test('fromWire parses both roles', () {
    expect(UserRole.fromWire('customer'), UserRole.customer);
    expect(UserRole.fromWire('courier'), UserRole.courier);
  });

  test('fromWire throws FormatException for unknown values', () {
    expect(() => UserRole.fromWire('admin'), throwsFormatException);
  });
}
