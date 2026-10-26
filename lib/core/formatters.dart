import 'package:intl/intl.dart';

import '../features/expenses/domain/entities/expense_filter.dart';
import '../features/expenses/domain/entities/expense_preferences.dart';

String formatMoney(
  int cents,
  ExpenseCurrency currency, {
  bool compact = false,
}) {
  final symbol = switch (currency) {
    ExpenseCurrency.bdt => '৳',
    ExpenseCurrency.usd => r'$',
    ExpenseCurrency.eur => '€',
    ExpenseCurrency.gbp => '£',
    ExpenseCurrency.inr => '₹',
  };
  final amount = cents / 100;
  if (compact && amount.abs() >= 10000) {
    return '$symbol${NumberFormat.compact(locale: 'en').format(amount)}';
  }
  final absolute = cents.abs();
  final whole = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  return '${cents < 0 ? '-' : ''}$symbol$whole.$fraction';
}

/// Converts a typed decimal into exact minor units without floating point math.
/// No grouping separators or scientific notation are accepted.
int? parseAmountCents(String input, {bool allowZero = false}) {
  final normalized = input.trim();
  if (!RegExp(r'^\d{1,10}(?:\.\d{0,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.parse(parts[0]);
  final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  final amount = whole * 100 + fraction;
  return amount > 0 || (allowZero && amount == 0) ? amount : null;
}

String formatPeriodLabel(ExpensePeriod period, DateTime anchor) {
  final range = DateRange.forPeriod(period, anchor);
  return switch (period) {
    ExpensePeriod.day => DateFormat('EEE, d MMM yyyy').format(anchor),
    ExpensePeriod.week =>
      '${DateFormat('d MMM').format(range.start)} – '
          '${DateFormat('d MMM yyyy').format(DateTime(range.end.year, range.end.month, range.end.day - 1))}',
    ExpensePeriod.month => DateFormat('MMMM yyyy').format(anchor),
    ExpensePeriod.year => DateFormat('yyyy').format(anchor),
  };
}

String formatExpenseDate(DateTime date) {
  final now = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Today';
  if (day == DateTime(now.year, now.month, now.day - 1)) return 'Yesterday';
  return DateFormat(date.year == now.year ? 'd MMM' : 'd MMM yyyy')
      .format(date);
}
