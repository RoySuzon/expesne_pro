import 'expense.dart';

enum ExpenseCurrency {
  bdt('BDT', '৳'),
  usd('USD', r'$'),
  eur('EUR', '€'),
  gbp('GBP', '£'),
  inr('INR', '₹');

  const ExpenseCurrency(this.code, this.symbol);

  final String code;
  final String symbol;
}

/// Currency is a display denomination, not a conversion service.
final class ExpensePreferences {
  ExpensePreferences({
    this.currency = ExpenseCurrency.bdt,
    this.monthlyBudgetCents = 0,
  }) {
    if (monthlyBudgetCents < 0 || monthlyBudgetCents > Expense.maxAmountCents) {
      throw ArgumentError.value(
        monthlyBudgetCents,
        'monthlyBudgetCents',
        'Use zero to disable, or a positive budget within the supported limit.',
      );
    }
  }

  const ExpensePreferences.defaults()
    : currency = ExpenseCurrency.bdt,
      monthlyBudgetCents = 0;

  final ExpenseCurrency currency;
  final int monthlyBudgetCents;

  ExpensePreferences copyWith({
    ExpenseCurrency? currency,
    int? monthlyBudgetCents,
  }) => ExpensePreferences(
    currency: currency ?? this.currency,
    monthlyBudgetCents: monthlyBudgetCents ?? this.monthlyBudgetCents,
  );
}
