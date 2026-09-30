enum UserRole {
  customer('customer'),
  courier('courier');

  const UserRole(this.wireName);

  /// Value stored in `rutta.profiles.role`.
  final String wireName;

  /// Throws [FormatException] for unknown values (mappers translate it to
  /// `UnknownError`).
  static UserRole fromWire(String value) {
    for (final role in values) {
      if (role.wireName == value) return role;
    }
    throw FormatException('Unknown user role: $value');
  }
}
