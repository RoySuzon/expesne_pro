import 'dart:math' as math;

import 'expense.dart';

enum ExpensePeriod { day, week, month, year }

/// A half-open local calendar interval: [start] is included, [end] is excluded.
final class DateRange {
  DateRange({required this.start, required this.end}) {
    if (!end.isAfter(start)) {
      throw ArgumentError('The range end must be after its start.');
    }
  }

  factory DateRange.forPeriod(ExpensePeriod period, DateTime anchor) {
    final local = anchor.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return switch (period) {
      ExpensePeriod.day => DateRange(
        start: day,
        end: DateTime(day.year, day.month, day.day + 1),
      ),
      ExpensePeriod.week => DateRange(
        start: DateTime(day.year, day.month, day.day - (day.weekday - 1)),
        end: DateTime(day.year, day.month, day.day + (8 - day.weekday)),
      ),
      ExpensePeriod.month => DateRange(
        start: DateTime(day.year, day.month),
        end: DateTime(day.year, day.month + 1),
      ),
      ExpensePeriod.year => DateRange(
        start: DateTime(day.year),
        end: DateTime(day.year + 1),
      ),
    };
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}

DateTime shiftPeriod(DateTime anchor, ExpensePeriod period, int steps) {
  final local = anchor.toLocal();
  if (period == ExpensePeriod.day || period == ExpensePeriod.week) {
    final days = steps * (period == ExpensePeriod.week ? 7 : 1);
    return DateTime(
      local.year,
      local.month,
      local.day + days,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }
  final target = period == ExpensePeriod.month
      ? DateTime(local.year, local.month + steps)
      : DateTime(local.year + steps, local.month);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    math.min(local.day, lastDay),
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
    local.microsecond,
  );
}

final class ExpenseFilter {
  ExpenseFilter({required this.range, this.category, String search = ''})
    : search = search.trim();

  final DateRange range;
  final ExpenseCategory? category;
  final String search;
}
