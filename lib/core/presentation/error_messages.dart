import 'package:rutta/core/errors/domain_error.dart';
import 'package:rutta/l10n/app_localizations.dart';

/// Exhaustive on purpose (no `default`): adding a [DomainError] must break the
/// analyzer here.
String errorMessage(DomainError error, AppLocalizations l10n) {
  return switch (error) {
    NetworkError() => l10n.errorNetwork,
    BackendUnavailableError() => l10n.errorBackendUnavailable,
    UnauthorizedError() => l10n.errorUnauthorized,
    NotFoundError() => l10n.errorNotFound,
    ConflictError() => l10n.errorConflict,
    ValidationError() => l10n.errorValidation,
    UnknownError() => l10n.errorUnknown,
    AuthError(:final kind) => switch (kind) {
      AuthErrorKind.invalidEmail => l10n.errorAuthInvalidEmail,
      AuthErrorKind.invalidCode => l10n.errorAuthInvalidCode,
      AuthErrorKind.codeExpired => l10n.errorAuthCodeExpired,
      AuthErrorKind.rateLimited => l10n.errorAuthRateLimited,
    },
    InvalidTransitionError() => l10n.errorInvalidTransition,
    NotAssignedToYouError() => l10n.errorNotAssignedToYou,
    CourierBusyError() => l10n.errorCourierBusy,
    NoActiveOrderError() => l10n.errorNoActiveOrder,
    LocationPermissionDeniedError(:final permanently) =>
      permanently
          ? l10n.errorLocationPermissionDeniedForever
          : l10n.errorLocationPermissionDenied,
    LocationServiceDisabledError() => l10n.errorLocationServiceDisabled,
  };
}

String validationMessage(ValidationReason reason, AppLocalizations l10n) {
  return switch (reason) {
    ValidationReason.required => l10n.validationRequired,
    ValidationReason.tooLong => l10n.validationTooLong,
    ValidationReason.invalidFormat => l10n.validationInvalidFormat,
  };
}

String messageFor(Object error, AppLocalizations l10n) {
  return error is DomainError ? errorMessage(error, l10n) : l10n.errorUnknown;
}
