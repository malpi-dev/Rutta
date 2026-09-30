import 'package:flutter/material.dart';
import 'package:rutta/core/presentation/formatters.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/theme/rutta_colors.dart';
import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/features/orders/domain/order_timeline.dart';
import 'package:rutta/features/orders/presentation/widgets/status_labels.dart';

/// Vertical timeline (no scroll of its own).
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({required this.steps, super.key});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final cancelled = step.status == OrderStatus.cancelled;
    final upcoming = step.state == TimelineStepState.upcoming;
    final current = step.state == TimelineStepState.current;
    final color = cancelled
        ? theme.colorScheme.error
        : current
        ? theme.colorScheme.primary
        : upcoming
        ? colors.neutral
        : colors.success;
    final dotSize = current ? 16.0 : 12.0;
    final at = step.at;
    return Opacity(
      key: Key('timeline-${step.status.wireName}'),
      opacity: upcoming ? 0.45 : 1,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: upcoming ? null : color,
                      border: upcoming
                          ? Border.all(color: color, width: 2)
                          : null,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: colors.neutral.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        statusLabel(step.status, context.l10n),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cancelled ? color : null,
                          fontWeight: current ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    if (at != null)
                      Text(
                        formatTime(at),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
