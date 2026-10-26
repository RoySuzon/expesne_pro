import 'package:expense_pro/core/formatters.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money entry uses exact minor units and rejects invalid precision', () {
    expect(parseAmountCents(' 12.01 '), 1201);
    expect(parseAmountCents('0.01'), 1);
    expect(parseAmountCents('12.'), 1200);
    expect(parseAmountCents('12'), 1200);
    expect(parseAmountCents('0'), isNull);
    expect(parseAmountCents('0', allowZero: true), 0);
    expect(parseAmountCents('9999999999.99'), 999999999999);
    expect(parseAmountCents('10000000000'), isNull);
    for (final input in ['-1', '.5', '1.001', 'NaN', '1e2', '1,000', '']) {
      expect(parseAmountCents(input), isNull, reason: input);
    }
  });

  test('formats the selected denomination and preserves cents', () {
    expect(formatMoney(120101, ExpenseCurrency.bdt), '৳1,201.01');
    expect(formatMoney(1, ExpenseCurrency.usd), r'$0.01');
    expect(
      formatMoney(9007199254740993, ExpenseCurrency.bdt),
      '৳90,071,992,547,409.93',
    );
  });
}
