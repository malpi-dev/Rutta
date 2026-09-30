import 'package:flutter/material.dart';

/// Shared layout of the auth screens: centered column of at most 420 dp that
/// scrolls when the keyboard covers part of it.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.children, this.appBar, super.key});

  final PreferredSizeWidget? appBar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
