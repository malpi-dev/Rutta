/// Typed errors thrown by repositories and use cases. Presentation switches
/// over them exhaustively.
///
/// Portfolio-wide codes: NetworkError/BackendUnavailableError=network,
/// UnauthorizedError=unauthorized, NotFoundError=notFound,
/// ConflictError/InvalidTransitionError/NotAssignedToYouError/
/// CourierBusyError=conflict, ValidationError=validation, UnknownError=unknown.
sealed class DomainError implements Exception {
  const DomainError();
}

// ---- common

final class NetworkError extends DomainError {
  const NetworkError([this.cause]);

  final Object? cause;

  @override
  String toString() => 'NetworkError($cause)';
}

/// The backend answered 5xx or is paused (free-tier projects pause after 7
/// days).
final class BackendUnavailableError extends DomainError {
  const BackendUnavailableError([this.cause]);

  final Object? cause;

  @override
  String toString() => 'BackendUnavailableError($cause)';
}

final class UnauthorizedError extends DomainError {
  const UnauthorizedError();

  @override
  String toString() => 'UnauthorizedError()';
}

final class NotFoundError extends DomainError {
  const NotFoundError(this.entity, [this.id]);

  final String entity;
  final String? id;

  @override
  String toString() => 'NotFoundError($entity, $id)';
}

final class ConflictError extends DomainError {
  const ConflictError([this.detail]);

  final String? detail;

  @override
  String toString() => 'ConflictError($detail)';
}

enum ValidationReason { required, tooLong, invalidFormat }

final class ValidationError extends DomainError {
  const ValidationError(this.field, this.reason);

  final String field;
  final ValidationReason reason;

  @override
  String toString() => 'ValidationError($field, $reason)';
}

final class UnknownError extends DomainError {
  const UnknownError([this.cause]);

  final Object? cause;

  @override
  String toString() => 'UnknownError($cause)';
}

// ---- auth

enum AuthErrorKind { invalidEmail, invalidCode, codeExpired, rateLimited }

final class AuthError extends DomainError {
  const AuthError(this.kind);

  final AuthErrorKind kind;

  @override
  String toString() => 'AuthError($kind)';
}

// ---- orders

final class InvalidTransitionError extends DomainError {
  const InvalidTransitionError({this.from, this.to});

  /// Wire names (`picked_up`); null when unknown. Strings because `core/`
  /// cannot depend on `features/`.
  final String? from;
  final String? to;

  @override
  String toString() => 'InvalidTransitionError(from: $from, to: $to)';
}

final class NotAssignedToYouError extends DomainError {
  const NotAssignedToYouError();

  @override
  String toString() => 'NotAssignedToYouError()';
}

final class CourierBusyError extends DomainError {
  const CourierBusyError();

  @override
  String toString() => 'CourierBusyError()';
}

// ---- tracking

final class NoActiveOrderError extends DomainError {
  const NoActiveOrderError();

  @override
  String toString() => 'NoActiveOrderError()';
}

final class LocationPermissionDeniedError extends DomainError {
  const LocationPermissionDeniedError({required this.permanently});

  final bool permanently;

  @override
  String toString() =>
      'LocationPermissionDeniedError(permanently: $permanently)';
}

final class LocationServiceDisabledError extends DomainError {
  const LocationServiceDisabledError();

  @override
  String toString() => 'LocationServiceDisabledError()';
}
