import '../entities/expense.dart';

/// A denomination-independent report. All money remains in integer minor units.
final class ExpenseSummary {
  const ExpenseSummary._({
    required this.totalCents,
    required this.count,
    required this.averageCents,
    required this.categoryTotals,
    required this.largest,
  });

  final int totalCents;
  final int count;
  final int averageCents;
  final Map<ExpenseCategory, int> categoryTotals;
  final Expense? largest;
}

ExpenseSummary buildExpenseSummary(List<Expense> expenses) {
  var total = 0;
  Expense? largest;
  final categoryTotals = <ExpenseCategory, int>{};
  for (final expense in expenses) {
    total += expense.amountCents;
    categoryTotals.update(
      expense.category,
      (amount) => amount + expense.amountCents,
      ifAbsent: () => expense.amountCents,
    );
    if (largest == null || expense.amountCents > largest.amountCents) {
      largest = expense;
    }
  }
  final count = expenses.length;
  return ExpenseSummary._(
    totalCents: total,
    count: count,
    // Round to the nearest cent without converting money to floating point.
    averageCents: count == 0 ? 0 : (total + count ~/ 2) ~/ count,
    categoryTotals: Map.unmodifiable(categoryTotals),
    largest: largest,
  );
}
