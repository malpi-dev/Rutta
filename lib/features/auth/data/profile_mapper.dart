import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/features/auth/domain/user_profile.dart';

/// `rutta.profiles` row -> [UserProfile]. An unknown role is an
/// [UnknownError] (never trust a value we cannot route).
UserProfile userProfileFromRow(Map<String, dynamic> row) {
  final UserRole role;
  try {
    role = UserRole.fromWire(row['role'] as String);
  } on Object catch (error) {
    throw UnknownError(error);
  }
  return UserProfile(
    id: row['id'] as String,
    fullName: row['full_name'] as String,
    role: role,
    phone: row['phone'] as String?,
  );
}
