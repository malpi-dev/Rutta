import 'package:rutta/core/errors/domain_error.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _otpPattern = RegExp(r'^\d{6}$');

bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

bool isValidOtpCode(String code) => _otpPattern.hasMatch(code);

/// Returns the trimmed name or throws
/// `ValidationError('fullName', required | tooLong)` (1..80 chars).
String validateFullName(String input) {
  final name = input.trim();
  if (name.isEmpty) {
    throw const ValidationError('fullName', ValidationReason.required);
  }
  if (name.length > 80) {
    throw const ValidationError('fullName', ValidationReason.tooLong);
  }
  return name;
}
