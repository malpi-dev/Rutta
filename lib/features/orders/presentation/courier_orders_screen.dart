import 'package:flutter/material.dart';
import 'package:rutta/core/presentation/empty_state.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';

class CourierOrdersScreen extends StatelessWidget {
  const CourierOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: EmptyState(icon: Icons.construction, title: l10n.comingSoon),
    );
  }
}
