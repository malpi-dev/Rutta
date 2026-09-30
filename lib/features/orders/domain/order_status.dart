enum OrderStatus {
  created('created'),
  assigned('assigned'),
  pickedUp('picked_up'),
  inTransit('in_transit'),
  delivered('delivered'),
  cancelled('cancelled');

  const OrderStatus(this.wireName);

  /// Value stored in the database.
  final String wireName;

  /// Throws [FormatException] for unknown values.
  static OrderStatus fromWire(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    throw FormatException('Unknown order status: $value');
  }

  /// Same table as `rutta.is_valid_transition` in SQL (the source of truth).
  /// Tests keep them identical.
  static const Map<OrderStatus, Set<OrderStatus>> transitions = {
    created: {assigned, cancelled},
    assigned: {pickedUp, cancelled},
    pickedUp: {inTransit},
    inTransit: {delivered},
    delivered: {},
    cancelled: {},
  };

  bool canTransitionTo(OrderStatus next) => transitions[this]!.contains(next);

  bool get isActive =>
      this == created ||
      this == assigned ||
      this == pickedUp ||
      this == inTransit;

  /// The courier location is visible to the customer.
  bool get isInProgress => this == pickedUp || this == inTransit;

  bool get isTerminal => this == delivered || this == cancelled;
}
