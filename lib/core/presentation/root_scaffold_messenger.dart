import 'package:flutter/material.dart';
import 'package:rutta/core/presentation/error_messages.dart';
import 'package:rutta/l10n/app_localizations.dart';

/// Messenger of the root `MaterialApp`. All SnackBars go through it so they
/// outlive the screen that raised them.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showErrorSnackBar(Object error, AppLocalizations l10n) {
  rootScaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(messageFor(error, l10n)), persist: false),
    );
}
