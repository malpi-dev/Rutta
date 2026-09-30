import 'package:intl/intl.dart';

/// Display-only formatting helpers.

/// `24500` -> `MX$245.00`.
String formatMoneyCents(int cents) => NumberFormat.currency(
  locale: 'en_US',
  name: 'MXN',
  symbol: r'MX$',
).format(cents / 100);

/// `850.4` -> `850 m`; `2430` -> `2.4 km`.
String formatDistance(double meters) {
  final rounded = meters.round();
  if (rounded < 1000) return '$rounded m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// `< 60 s` -> `< 1 min`; `125 s` -> `3 min`; `65 min` -> `1 h 5 min`.
String formatEta(Duration eta) {
  if (eta.inSeconds < 60) return '< 1 min';
  final minutes = (eta.inSeconds / 60).ceil();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// Local time, e.g. `2:32 PM`.
String formatTime(DateTime utc) => DateFormat.jm(
  'en_US',
).format(utc.toLocal()).replaceAll('\u202f', ' '); // ICU uses a narrow NBSP

/// Same local day as [nowUtc] -> `2:32 PM`; otherwise `Sep 28, 2:32 PM`.
String formatOrderDate(DateTime utc, DateTime nowUtc) {
  final local = utc.toLocal();
  final now = nowUtc.toLocal();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) return formatTime(utc);
  return '${DateFormat.MMMd('en_US').format(local)}, ${formatTime(utc)}';
}

/// `45 s ago`, `2 min ago` (minimum 0 s).
String formatAgo(Duration elapsed) {
  final seconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  if (seconds < 60) return '$seconds s ago';
  return '${seconds ~/ 60} min ago';
}
