import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';

part 'auth_controllers.g.dart';

/// Sends the login code. The error lives in the state and the UI shows it.
@riverpod
class SendCodeController extends _$SendCodeController {
  @override
  FutureOr<void> build() {}

  /// Returns true when the code was sent.
  Future<bool> send(String email) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendCode(email),
    );
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}

/// Verifies the code (and resends it). Navigation is NOT done here: once the
/// session changes, the router redirect moves the user.
@riverpod
class VerifyCodeController extends _$VerifyCodeController {
  @override
  FutureOr<void> build() {}

  Future<void> verify({required String email, required String code}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () =>
          ref.read(authRepositoryProvider).verifyCode(email: email, code: code),
    );
    if (ref.mounted) state = result;
  }

  /// Returns true when a new code was sent.
  Future<bool> resend(String email) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendCode(email),
    );
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  FutureOr<void> build() {}

  Future<void> submit(String fullName) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).ensureProfile(fullName),
    );
    if (ref.mounted) state = result;
  }
}
