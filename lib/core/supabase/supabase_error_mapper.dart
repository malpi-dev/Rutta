import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rutta/core/errors/domain_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _transitionPattern = RegExp(r'from=(\w+) to=(\w+)');

/// Translates SDK exceptions into [DomainError]s. Nothing from Supabase may
/// reach the UI.
DomainError mapSupabaseError(Object error) {
  if (error is DomainError) return error;
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is AuthRetryableFetchException) {
    return NetworkError(error);
  }
  if (error is PostgrestException) return _mapPostgrest(error);
  if (error is AuthException) return _mapAuth(error);
  return UnknownError(error);
}

DomainError _mapPostgrest(PostgrestException error) {
  // RPC errors carry a fixed prefix (phase 09): they win over the code.
  final message = error.message;
  if (message.startsWith('RUTTA_INVALID_TRANSITION')) {
    final match = _transitionPattern.firstMatch(message);
    return InvalidTransitionError(from: match?.group(1), to: match?.group(2));
  }
  if (message.startsWith('RUTTA_COURIER_BUSY')) return const CourierBusyError();
  if (message.startsWith('RUTTA_NOT_ASSIGNED') ||
      message.startsWith('RUTTA_NOT_COURIER')) {
    return const NotAssignedToYouError();
  }
  if (message.startsWith('RUTTA_NOT_FOUND')) {
    return const NotFoundError('order');
  }
  if (message.startsWith('RUTTA_UNAUTHORIZED')) {
    return const UnauthorizedError();
  }
  if (message.startsWith('RUTTA_INVALID_NAME')) {
    return const ValidationError('fullName', ValidationReason.invalidFormat);
  }

  final code = error.code ?? '';
  // Three digits = HTTP status (540 = paused project). SQLSTATE codes such as
  // 23505 are five characters and must not match.
  final numeric = code.length == 3 ? int.tryParse(code) : null;
  if (numeric != null && numeric >= 500) return BackendUnavailableError(error);
  if (code == 'PGRST301' ||
      code == 'PGRST302' ||
      message.toLowerCase().contains('jwt')) {
    return const UnauthorizedError();
  }
  if (code == 'PGRST116') return const NotFoundError('order');
  if (code == '42501') return const UnauthorizedError();
  if (code == '23505') return ConflictError(message);
  return UnknownError(error);
}

DomainError _mapAuth(AuthException error) {
  final status = int.tryParse(error.statusCode ?? '');
  final code = error.code;
  if (status == 429 ||
      code == 'over_email_send_rate_limit' ||
      code == 'over_request_rate_limit') {
    return const AuthError(AuthErrorKind.rateLimited);
  }
  if (status != null && status >= 500) return BackendUnavailableError(error);
  // GoTrue uses the same code for wrong and expired codes.
  if (code == 'otp_expired') return const AuthError(AuthErrorKind.invalidCode);
  if (code == 'email_address_invalid' || code == 'validation_failed') {
    return const AuthError(AuthErrorKind.invalidEmail);
  }
  if (status == 401) return const UnauthorizedError();
  return UnknownError(error);
}

/// Runs [body] and rethrows any failure as a [DomainError].
Future<T> guardSupabase<T>(
  Future<T> Function() body, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  try {
    return await body().timeout(timeout);
  } on Object catch (error) {
    throw mapSupabaseError(error);
  }
}
