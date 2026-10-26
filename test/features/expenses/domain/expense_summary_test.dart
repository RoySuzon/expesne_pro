import 'package:expense_pro/features/expenses/domain/entities/expense.dart';
import 'package:expense_pro/features/expenses/domain/usecases/build_expense_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense value(int cents, ExpenseCategory category) => Expense(
    title: 'Purchase',
    amountCents: cents,
    category: category,
    occurredAt: DateTime(2026, 10, 26),
  );

  test(
    'summary reports real integer totals, rounded average and largest expense',
    () {
      final largest = value(1001, ExpenseCategory.transport);
      final summary = buildExpenseSummary([
        value(100, ExpenseCategory.food),
        value(100, ExpenseCategory.food),
        largest,
        value(1, ExpenseCategory.other),
      ]);
      expect(summary.totalCents, 1202);
      expect(summary.count, 4);
      expect(summary.averageCents, 301);
      expect(summary.largest, same(largest));
      expect(summary.categoryTotals, {
        ExpenseCategory.food: 200,
        ExpenseCategory.transport: 1001,
        ExpenseCategory.other: 1,
      });
      expect(() => summary.categoryTotals.clear(), throwsUnsupportedError);
    },
  );

  test('empty data produces a usable zero report without an invented largest expense', () {
    final summary = buildExpenseSummary([]);
    expect(summary.totalCents, 0);
    expect(summary.averageCents, 0);
    expect(summary.count, 0);
    expect(summary.categoryTotals, isEmpty);
    expect(summary.largest, isNull);
  });
}
