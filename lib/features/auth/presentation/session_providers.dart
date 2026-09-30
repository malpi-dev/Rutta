import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/features/auth/domain/session_state.dart';

part 'session_providers.g.dart';

/// Provisional: phase 10 connects it to the auth repository.
@Riverpod(keepAlive: true)
Stream<SessionState> sessionState(Ref ref) =>
    Stream.value(const SessionSignedOut());
