import 'package:expense_pro/app.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_preferences.dart';
import 'package:expense_pro/features/expenses/presentation/providers/expense_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_expense_repository.dart';

Future<void> openApp(
  WidgetTester tester,
  FakeExpenseRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: const ExpenseProApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'creates, edits and deletes an expense through the real screens',
    (tester) async {
      final repository = FakeExpenseRepository();
      await openApp(tester, repository);
      await tester.tap(find.text('Activity').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-expense-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('expense-amount-field')),
        '120.45',
      );
      await tester.enterText(
        find.byKey(const Key('expense-title-field')),
        'Lunch',
      );
      await reveal(tester, find.byKey(const Key('save-expense-button')));
      await tester.tap(find.byKey(const Key('save-expense-button')));
      await tester.pumpAndSettle();
      expect(repository.expenses.single.amountCents, 12045);

      await reveal(tester, find.text('Lunch'));
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      expect(find.text('Edit expense'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('expense-amount-field')),
        '99.99',
      );
      await reveal(tester, find.byKey(const Key('save-expense-button')));
      await tester.tap(find.byKey(const Key('save-expense-button')));
      await tester.pumpAndSettle();
      expect(repository.expenses.single.amountCents, 9999);
      await reveal(tester, find.text('Lunch'));
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Delete expense'));
      await tester.tap(find.text('Delete expense'));
      await tester.pumpAndSettle();
      expect(repository.expenses, hasLength(1));
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(repository.expenses, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validates input and keeps entered data after a storage failure',
    (tester) async {
      final repository = FakeExpenseRepository()..failWrites = true;
      await openApp(tester, repository);
      await tester.tap(find.byKey(const Key('add-expense-button')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('save-expense-button')));
      await tester.tap(find.byKey(const Key('save-expense-button')));
      await tester.pumpAndSettle();
      expect(repository.expenses, isEmpty);
      expect(find.text('Give your expense a title.'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('expense-amount-field')));
      await tester.enterText(
        find.byKey(const Key('expense-amount-field')),
        '15.50',
      );
      await tester.enterText(
        find.byKey(const Key('expense-title-field')),
        'Coffee',
      );
      await reveal(tester, find.byKey(const Key('save-expense-button')));
      await tester.tap(find.byKey(const Key('save-expense-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Couldn’t save this expense'), findsOneWidget);
      expect(repository.expenses, isEmpty);
      repository.failWrites = false;
      await reveal(tester, find.byKey(const Key('save-expense-button')));
      await tester.tap(find.byKey(const Key('save-expense-button')));
      await tester.pumpAndSettle();
      expect(repository.expenses.single.title, 'Coffee');
      expect(repository.expenses.single.amountCents, 1550);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('activity combines search with category and can clear both', (
    tester,
  ) async {
    final repository = FakeExpenseRepository();
    for (final (title, category) in [
      ('Lunch', ExpenseCategory.food),
      ('Bus fare', ExpenseCategory.transport),
    ]) {
      await repository.saveExpense(
        Expense(
          title: title,
          amountCents: 5000,
          category: category,
          occurredAt: DateTime.now(),
        ),
      );
    }
    await openApp(tester, repository);
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('search-expenses-field')),
      'Bus',
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Food & drinks'));
    await tester.tap(find.text('Food & drinks'));
    await tester.pumpAndSettle();
    expect(find.text('No matching expenses'), findsOneWidget);
    await reveal(tester, find.text('Clear filters'));
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('2 expenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a currency and monthly budget from settings', (
    tester,
  ) async {
    final repository = FakeExpenseRepository();
    await openApp(tester, repository);
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BDT · Bangladeshi taka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD · US dollar').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('monthly-budget-field')),
      '1000',
    );
    await reveal(tester, find.byKey(const Key('save-settings-button')));
    await tester.tap(find.byKey(const Key('save-settings-button')));
    await tester.pumpAndSettle();
    expect(repository.preferences.currency, ExpenseCurrency.usd);
    expect(repository.preferences.monthlyBudgetCents, 100000);
    expect(find.text('Make it yours'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
