import 'package:flutter_test/flutter_test.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_filter.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_preferences.dart';

void main() {
  Expense expense({int amountCents = 125, String title = 'Coffee'}) => Expense(
    title: title,
    amountCents: amountCents,
    category: ExpenseCategory.food,
    occurredAt: DateTime(2026, 10, 26),
  );

  test('expense preserves integer money, trims input and validates edits', () {
    final value = expense(title: ' Coffee ');
    expect(value.title, 'Coffee');
    expect(value.amountCents, 125);
    expect(value.copyWith(id: 4, amountCents: 200).id, 4);
    expect(() => expense(amountCents: 0), throwsArgumentError);
    expect(() => expense(amountCents: -1), throwsArgumentError);
    expect(
      () => expense(amountCents: Expense.maxAmountCents + 1),
      throwsArgumentError,
    );
    expect(() => expense(title: '  '), throwsArgumentError);
    expect(() => expense(title: 'x' * 121), throwsArgumentError);
    expect(() => value.copyWith(note: 'x' * 1001), throwsArgumentError);
  });

  test(
    'preferences keep disabled budget as zero and reject negative budgets',
    () {
      expect(const ExpensePreferences.defaults().currency, ExpenseCurrency.bdt);
      expect(const ExpensePreferences.defaults().monthlyBudgetCents, 0);
      expect(
        () => ExpensePreferences(monthlyBudgetCents: -1),
        throwsArgumentError,
      );
      final settings = ExpensePreferences(
        currency: ExpenseCurrency.usd,
        monthlyBudgetCents: 350000,
      );
      expect(
        settings.copyWith(currency: ExpenseCurrency.eur).monthlyBudgetCents,
        350000,
      );
    },
  );

  group('calendar filters', () {
    test('day range includes midnight and excludes the next midnight', () {
      final range = DateRange.forPeriod(
        ExpensePeriod.day,
        DateTime(2026, 10, 26, 19),
      );
      expect(range.start, DateTime(2026, 10, 26));
      expect(range.end, DateTime(2026, 10, 27));
      expect(range.contains(range.start), isTrue);
      expect(range.contains(DateTime(2026, 10, 26, 23, 59, 59, 999)), isTrue);
      expect(range.contains(range.end), isFalse);
    });

    test('week begins on Monday across month and year boundaries', () {
      final range = DateRange.forPeriod(
        ExpensePeriod.week,
        DateTime(2027, 1, 3),
      );
      expect(range.start, DateTime(2026, 12, 28));
      expect(range.end, DateTime(2027, 1, 4));
      final monday = DateRange.forPeriod(
        ExpensePeriod.week,
        DateTime(2027, 1, 4),
      );
      expect(monday.start, DateTime(2027, 1, 4));
    });

    test('month and year use calendar boundaries including leap years', () {
      final february = DateRange.forPeriod(
        ExpensePeriod.month,
        DateTime(2024, 2, 29),
      );
      expect(february.start, DateTime(2024, 2));
      expect(february.end, DateTime(2024, 3));
      final year = DateRange.forPeriod(
        ExpensePeriod.year,
        DateTime(2024, 9, 7),
      );
      expect(year.start, DateTime(2024));
      expect(year.end, DateTime(2025));
    });

    test(
      'navigation clamps month ends and leap day without skipping periods',
      () {
        expect(
          shiftPeriod(DateTime(2024, 1, 31), ExpensePeriod.month, 1),
          DateTime(2024, 2, 29),
        );
        expect(
          shiftPeriod(DateTime(2024, 2, 29), ExpensePeriod.year, 1),
          DateTime(2025, 2, 28),
        );
        expect(
          shiftPeriod(DateTime(2026, 1, 1), ExpensePeriod.week, -1),
          DateTime(2025, 12, 25),
        );
        expect(
          shiftPeriod(DateTime(2026, 12, 31), ExpensePeriod.day, 1),
          DateTime(2027, 1, 1),
        );
        expect(
          () => DateRange(start: DateTime(2026), end: DateTime(2026)),
          throwsArgumentError,
        );
      },
    );
  });
}
