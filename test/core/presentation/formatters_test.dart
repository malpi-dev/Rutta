import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:rutta/core/presentation/formatters.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'en_US';
    await initializeDateFormatting('en_US');
  });

  test('formatMoneyCents', () {
    expect(formatMoneyCents(24500), r'MX$245.00');
    expect(formatMoneyCents(5), r'MX$0.05');
  });

  test('formatDistance', () {
    expect(formatDistance(850.4), '850 m');
    expect(formatDistance(999.6), '1.0 km');
    expect(formatDistance(2430), '2.4 km');
  });

  test('formatEta', () {
    expect(formatEta(const Duration(seconds: 30)), '< 1 min');
    expect(formatEta(const Duration(seconds: 125)), '3 min');
    expect(formatEta(const Duration(minutes: 65)), '1 h 5 min');
  });

  test('formatTime uses local h:mm a', () {
    final utc = DateTime.utc(2026, 9, 28, 20, 32);
    final local = utc.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    expect(formatTime(utc), '$hour12:$minute $period');
  });

  test('formatOrderDate: same day shows time only, other day adds date', () {
    final utc = DateTime.utc(2026, 9, 28, 20, 32);
    expect(formatOrderDate(utc, utc), formatTime(utc));
    final later = utc.add(const Duration(days: 3));
    final text = formatOrderDate(utc, later);
    expect(text, endsWith(formatTime(utc)));
    expect(text, contains(', '));
    expect(text, matches(RegExp(r'^[A-Z][a-z]{2} \d{1,2}, ')));
  });

  test('formatAgo', () {
    expect(formatAgo(const Duration(seconds: 45)), '45 s ago');
    expect(formatAgo(const Duration(seconds: 120)), '2 min ago');
    expect(formatAgo(const Duration(seconds: -5)), '0 s ago');
  });
}
