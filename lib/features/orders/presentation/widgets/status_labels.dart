import 'package:rutta/features/orders/domain/order_status.dart';
import 'package:rutta/l10n/app_localizations.dart';

String statusLabel(OrderStatus status, AppLocalizations l10n) {
  return switch (status) {
    OrderStatus.created => l10n.statusCreated,
    OrderStatus.assigned => l10n.statusAssigned,
    OrderStatus.pickedUp => l10n.statusPickedUp,
    OrderStatus.inTransit => l10n.statusInTransit,
    OrderStatus.delivered => l10n.statusDelivered,
    OrderStatus.cancelled => l10n.statusCancelled,
  };
}
