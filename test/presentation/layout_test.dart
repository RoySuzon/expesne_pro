import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_pro/app.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_preferences.dart';
import 'package:expense_pro/features/expenses/presentation/providers/expense_providers.dart';

import '../support/fake_expense_repository.dart';

void main() {
  testWidgets('navigation and editor fit a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = FakeExpenseRepository();
    final now = DateTime(2026, 10, 26, 12);
    repository.preferences = ExpensePreferences(monthlyBudgetCents: 500000);
    await repository.saveExpense(
      Expense(
        amountCents: 15000,
        title: 'A longer lunch title for a narrow screen',
        category: ExpenseCategory.food,
        occurredAt: now,
      ),
    );
    await repository.saveExpense(
      Expense(
        amountCents: 5000,
        title: 'Bus fare',
        category: ExpenseCategory.transport,
        occurredAt: now,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const ExpenseProApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['Activity', 'Insights', 'Overview']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const Key('add-expense-button')));
    await tester.pumpAndSettle();
    expect(find.text('Add an expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const Key('expense-amount-field')),
      '75.50',
    );
    await tester.enterText(
      find.byKey(const Key('expense-title-field')),
      'Coffee',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-expense-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('save-expense-button')));
    await tester.pumpAndSettle();
    expect(
      repository.expenses.any(
        (expense) => expense.title == 'Coffee' && expense.amountCents == 7550,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching tabs resets scrolling to the heading and period controls',
    (tester) async {
      final repository = FakeExpenseRepository();
      final now = DateTime(2026, 10, 26, 12);
      for (var index = 0; index < 30; index++) {
        await repository.saveExpense(
          Expense(
            amountCents: 10000 + index,
            title: 'Entry $index',
            category: ExpenseCategory.food,
            occurredAt: now,
          ),
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repository),
            clockProvider.overrideWithValue(() => now),
          ],
          child: const ExpenseProApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Expense Pro').hitTestable(), findsNothing);
      await tester.tap(find.text('Insights').last);
      await tester.pumpAndSettle();
      expect(find.text('Expense Pro').hitTestable(), findsOneWidget);
      expect(find.text('Month').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preference read failure never shows an assumed currency', (
    tester,
  ) async {
    final repository = FakeExpenseRepository();
    final now = DateTime(2026, 10, 26, 12);
    repository.preferences = ExpensePreferences(currency: ExpenseCurrency.usd);
    await repository.saveExpense(
      Expense(
        amountCents: 15000,
        title: 'Lunch',
        category: ExpenseCategory.food,
        occurredAt: now,
      ),
    );
    repository.failReads = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const ExpenseProApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load your preferences'), findsOneWidget);
    expect(find.textContaining('৳'), findsNothing);
    expect(find.byKey(const Key('add-expense-button')), findsNothing);
    repository.failReads = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text(r'$150.00'), findsWidgets);
    expect(find.textContaining('৳'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
