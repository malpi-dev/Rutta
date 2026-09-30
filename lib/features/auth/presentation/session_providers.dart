import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/supabase/supabase_client_provider.dart';
import 'package:rutta/features/auth/domain/session_state.dart';

part 'session_providers.g.dart';

/// Without a configured backend there is never a session (demo only).
@Riverpod(keepAlive: true)
Stream<SessionState> sessionState(Ref ref) {
  if (!ref.watch(backendConfiguredProvider)) {
    return Stream.value(const SessionSignedOut());
  }
  return ref.watch(authRepositoryProvider).watchSession();
}
