import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';

/// Bottom sheet to choose the demo role. The router redirects on selection.
Future<void> showDemoRolePicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      void pick(UserRole role) {
        Navigator.of(sheetContext).pop();
        ref.read(appModeControllerProvider.notifier).enterDemo(role);
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.demoPickerTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(l10n.demoPickerSubtitle),
              const SizedBox(height: 16),
              _RoleCard(
                id: 'demo-as-customer',
                icon: Icons.person_pin_circle_outlined,
                title: l10n.demoAsCustomer,
                description: l10n.demoAsCustomerHint,
                onTap: () => pick(UserRole.customer),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                id: 'demo-as-courier',
                icon: Icons.delivery_dining_outlined,
                title: l10n.demoAsCourier,
                description: l10n.demoAsCourierHint,
                onTap: () => pick(UserRole.courier),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: id,
      child: Card(
        key: Key(id),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 36, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(description, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
