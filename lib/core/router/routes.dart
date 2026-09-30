import 'package:rutta/core/domain/user_role.dart';

abstract final class Routes {
  static const startup = '/';
  static const login = '/login';

  /// `?email=<email>`
  static const verify = '/verify';
  static const onboarding = '/onboarding';
  static const customerOrders = '/customer/orders';
  static String customerOrder(String id) => '/customer/orders/$id';
  static const courierOrders = '/courier/orders';
  static String courierOrder(String id) => '/courier/orders/$id';
  static const settings = '/settings';

  /// Debug-only map preview (removed in phase 06).
  static const devMap = '/dev/map';

  static String homeFor(UserRole role) => switch (role) {
    UserRole.customer => customerOrders,
    UserRole.courier => courierOrders,
  };
}
