import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/presentation/error_messages.dart';
import 'package:rutta/core/presentation/error_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/presentation/skeleton.dart';

/// Loading / empty / error / data states in one place (definition section 12.1).
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.loading,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (d) {
        if (empty != null && (isEmpty?.call(d) ?? false)) return empty!;
        return data(d);
      },
      loading: () => loading ?? const SkeletonList(),
      error: (error, _) => ErrorState(
        message: messageFor(error, context.l10n),
        onRetry: onRetry,
      ),
    );
  }
}
