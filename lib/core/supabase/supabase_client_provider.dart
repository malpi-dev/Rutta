import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_client_provider.g.dart';

/// Only valid when Env.isBackendConfigured (main() initializes Supabase). Demo
/// mode never reads it.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;

/// Overridable in tests (Env values are compile-time constants).
@Riverpod(keepAlive: true)
bool backendConfigured(Ref ref) => Env.isBackendConfigured;
