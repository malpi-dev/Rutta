import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/core/presentation/error_messages.dart';
import 'package:rutta/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  final errors = <DomainError>[
    const NetworkError(),
    const BackendUnavailableError(),
    const UnauthorizedError(),
    const NotFoundError('order', 'x'),
    const ConflictError(),
    const ValidationError('name', ValidationReason.required),
    for (final kind in AuthErrorKind.values) AuthError(kind),
    const InvalidTransitionError(from: 'picked_up', to: 'created'),
    const NotAssignedToYouError(),
    const CourierBusyError(),
    const NoActiveOrderError(),
    const LocationPermissionDeniedError(permanently: false),
    const LocationPermissionDeniedError(permanently: true),
    const LocationServiceDisabledError(),
  ];

  test('every DomainError has its own non-empty message', () {
    final seen = <String>{};
    for (final error in errors) {
      final message = errorMessage(error, l10n);
      expect(message, isNotEmpty, reason: '$error');
      expect(message, isNot(l10n.errorUnknown), reason: '$error');
      seen.add(message);
    }
    expect(errorMessage(const UnknownError(), l10n), l10n.errorUnknown);
  });

  test('messageFor falls back to errorUnknown for non-domain errors', () {
    expect(messageFor(StateError('x'), l10n), l10n.errorUnknown);
    expect(messageFor(const NetworkError(), l10n), l10n.errorNetwork);
  });

  test('validationMessage covers every reason', () {
    for (final reason in ValidationReason.values) {
      expect(validationMessage(reason, l10n), isNotEmpty);
    }
  });
}
