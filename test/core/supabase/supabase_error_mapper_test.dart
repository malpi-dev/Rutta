import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/supabase/supabase_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  PostgrestException pg(String message, [String? code]) =>
      PostgrestException(message: message, code: code);

  group('mapSupabaseError', () {
    test('DomainError passes through', () {
      const error = CourierBusyError();
      expect(mapSupabaseError(error), same(error));
    });

    test('network-like exceptions become NetworkError', () {
      expect(
        mapSupabaseError(const SocketException('x')),
        isA<NetworkError>(),
      );
      expect(mapSupabaseError(TimeoutException('x')), isA<NetworkError>());
      expect(mapSupabaseError(http.ClientException('x')), isA<NetworkError>());
      expect(
        mapSupabaseError(AuthRetryableFetchException(message: 'x')),
        isA<NetworkError>(),
      );
    });

    test('RUTTA_INVALID_TRANSITION extracts from and to', () {
      final error = mapSupabaseError(
        pg('RUTTA_INVALID_TRANSITION from=created to=delivered', 'P0001'),
      );
      expect(error, isA<InvalidTransitionError>());
      final t = error as InvalidTransitionError;
      expect(t.from, 'created');
      expect(t.to, 'delivered');
    });

    test('RUTTA_INVALID_TRANSITION without details has null from/to', () {
      final t =
          mapSupabaseError(pg('RUTTA_INVALID_TRANSITION'))
              as InvalidTransitionError;
      expect(t.from, isNull);
      expect(t.to, isNull);
    });

    test('RUTTA_* prefixes map to typed errors', () {
      expect(
        mapSupabaseError(pg('RUTTA_COURIER_BUSY')),
        isA<CourierBusyError>(),
      );
      expect(
        mapSupabaseError(pg('RUTTA_NOT_ASSIGNED')),
        isA<NotAssignedToYouError>(),
      );
      expect(
        mapSupabaseError(pg('RUTTA_NOT_COURIER')),
        isA<NotAssignedToYouError>(),
      );
      expect(
        mapSupabaseError(pg('RUTTA_NOT_FOUND')),
        isA<NotFoundError>().having((e) => e.entity, 'entity', 'order'),
      );
      expect(
        mapSupabaseError(pg('RUTTA_UNAUTHORIZED', '28000')),
        isA<UnauthorizedError>(),
      );
      expect(
        mapSupabaseError(pg('RUTTA_INVALID_NAME', '22023')),
        isA<ValidationError>()
            .having((e) => e.field, 'field', 'fullName')
            .having((e) => e.reason, 'reason', ValidationReason.invalidFormat),
      );
    });

    test('prefix wins over a 5xx-looking code', () {
      expect(
        mapSupabaseError(pg('RUTTA_COURIER_BUSY', '500')),
        isA<CourierBusyError>(),
      );
    });

    test('3-digit numeric code >= 500 is backend unavailable', () {
      expect(
        mapSupabaseError(pg('down', '540')),
        isA<BackendUnavailableError>(),
      );
      expect(
        mapSupabaseError(pg('down', '503')),
        isA<BackendUnavailableError>(),
      );
    });

    test('23505 (5 chars) is a conflict, not HTTP', () {
      expect(mapSupabaseError(pg('dup', '23505')), isA<ConflictError>());
    });

    test('auth/permission codes', () {
      expect(mapSupabaseError(pg('x', 'PGRST301')), isA<UnauthorizedError>());
      expect(mapSupabaseError(pg('x', 'PGRST302')), isA<UnauthorizedError>());
      expect(
        mapSupabaseError(pg('JWT expired', 'PGRST303')),
        isA<UnauthorizedError>(),
      );
      expect(mapSupabaseError(pg('x', '42501')), isA<UnauthorizedError>());
    });

    test('PGRST116 is not found', () {
      expect(mapSupabaseError(pg('no rows', 'PGRST116')), isA<NotFoundError>());
    });

    test('unknown postgrest error', () {
      expect(mapSupabaseError(pg('boom', 'XX000')), isA<UnknownError>());
      expect(mapSupabaseError(pg('boom')), isA<UnknownError>());
    });

    AuthError authErr(Object e) => mapSupabaseError(e) as AuthError;

    test('AuthException rate limits', () {
      expect(
        authErr(const AuthException('x', statusCode: '429')).kind,
        AuthErrorKind.rateLimited,
      );
      expect(
        authErr(
          const AuthException('x', code: 'over_email_send_rate_limit'),
        ).kind,
        AuthErrorKind.rateLimited,
      );
      expect(
        authErr(const AuthException('x', code: 'over_request_rate_limit')).kind,
        AuthErrorKind.rateLimited,
      );
    });

    test('AuthException 5xx is backend unavailable', () {
      expect(
        mapSupabaseError(const AuthException('x', statusCode: '503')),
        isA<BackendUnavailableError>(),
      );
    });

    test('otp_expired is an invalid code', () {
      expect(
        authErr(const AuthException('x', code: 'otp_expired')).kind,
        AuthErrorKind.invalidCode,
      );
    });

    test('invalid email codes', () {
      expect(
        authErr(const AuthException('x', code: 'email_address_invalid')).kind,
        AuthErrorKind.invalidEmail,
      );
      expect(
        authErr(const AuthException('x', code: 'validation_failed')).kind,
        AuthErrorKind.invalidEmail,
      );
    });

    test('AuthException 401 is unauthorized; the rest unknown', () {
      expect(
        mapSupabaseError(const AuthException('x', statusCode: '401')),
        isA<UnauthorizedError>(),
      );
      expect(
        mapSupabaseError(const AuthException('x', statusCode: '400')),
        isA<UnknownError>(),
      );
    });

    test('anything else is UnknownError', () {
      expect(mapSupabaseError(StateError('x')), isA<UnknownError>());
    });
  });

  group('guardSupabase', () {
    test('returns the value', () async {
      expect(await guardSupabase(() async => 42), 42);
    });

    test('maps thrown SDK errors', () async {
      await expectLater(
        guardSupabase<void>(() async => throw pg('RUTTA_COURIER_BUSY')),
        throwsA(isA<CourierBusyError>()),
      );
    });

    test('a timeout becomes NetworkError', () async {
      await expectLater(
        guardSupabase<void>(
          () => Completer<void>().future,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<NetworkError>()),
      );
    });
  });
}
