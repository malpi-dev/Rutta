import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rutta/core/domain/user_role.dart';

part 'user_profile.freezed.dart';

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String fullName,
    required UserRole role,
    String? phone,
  }) = _UserProfile;
}
