import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/domain/user_role.dart';

void main() {
  test('AppModeLive instances are equal', () {
    expect(const AppModeLive(), const AppModeLive());
    expect(const AppModeLive().hashCode, const AppModeLive().hashCode);
  });

  test('AppModeDemo compares by role', () {
    expect(
      const AppModeDemo(UserRole.courier),
      const AppModeDemo(UserRole.courier),
    );
    expect(
      const AppModeDemo(UserRole.courier),
      isNot(const AppModeDemo(UserRole.customer)),
    );
    expect(const AppModeDemo(UserRole.courier), isNot(const AppModeLive()));
  });
}
