import 'package:expense_pro/features/expenses/domain/entities/expense.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_filter.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_preferences.dart';
import 'package:expense_pro/features/expenses/presentation/providers/expense_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_expense_repository.dart';

void main() {
  late FakeExpenseRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeExpenseRepository();
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 26)),
      ],
    );
  });

  tearDown(() => container.dispose());

  Expense expense(
    String title,
    int cents,
    DateTime day, [
    ExpenseCategory category = ExpenseCategory.food,
  ]) => Expense(
    title: title,
    amountCents: cents,
    category: category,
    occurredAt: day,
  );

  test(
    'filters activity while keeping period and budget totals complete',
    () async {
      await repository.saveExpense(
        expense('Lunch', 1234, DateTime(2026, 10, 26)),
      );
      await repository.saveExpense(
        expense('Bus', 500, DateTime(2026, 10, 1), ExpenseCategory.transport),
      );
      await repository.saveExpense(expense('Old', 900, DateTime(2026, 9, 30)));

      final view = container.read(viewStateProvider.notifier);
      view.setCategory(ExpenseCategory.food);
      view.setSearch('lunch');
      expect(
        (await container.read(expensesProvider.future)).single.title,
        'Lunch',
      );
      expect(await container.read(periodExpensesProvider.future), hasLength(2));
      expect(
        await container.read(monthlyExpensesProvider.future),
        hasLength(2),
      );

      view.setPeriod(ExpensePeriod.day);
      expect(await container.read(periodExpensesProvider.future), hasLength(1));
      expect(
        await container.read(monthlyExpensesProvider.future),
        hasLength(2),
      );
      view.move(-1);
      expect(await container.read(expensesProvider.future), isEmpty);
      view.today();
      view.setCategory(null);
      view.setSearch('');
      expect(await container.read(expensesProvider.future), hasLength(1));
    },
  );

  test(
    'save, edit and delete refresh all consumers without restarting',
    () async {
      expect(await container.read(expensesProvider.future), isEmpty);
      final actions = container.read(expenseActionsProvider);
      final saved = await actions.save(
        expense('Lunch', 100, DateTime(2026, 10, 26)),
      );
      expect(
        (await container.read(expensesProvider.future)).single.id,
        saved.id,
      );
      await actions.save(saved.copyWith(amountCents: 250));
      await container.read(periodExpensesProvider.future);
      expect(
        container.read(expenseSummaryProvider).requireValue.totalCents,
        250,
      );
      await actions.delete(saved.id!);
      expect(await container.read(expensesProvider.future), isEmpty);
      expect(await container.read(monthlyExpensesProvider.future), isEmpty);
    },
  );

  test(
    'failed writes keep existing preferences and records available',
    () async {
      final initial = await container.read(preferencesProvider.future);
      repository.failWrites = true;
      await expectLater(
        container
            .read(preferencesProvider.notifier)
            .save(
              ExpensePreferences(
                currency: ExpenseCurrency.usd,
                monthlyBudgetCents: 100,
              ),
            ),
        throwsStateError,
      );
      expect(
        container.read(preferencesProvider).requireValue.currency,
        initial.currency,
      );
      expect(repository.expenses, isEmpty);
    },
  );

  test('refresh recovers from a storage read error', () async {
    repository.failReads = true;
    await expectLater(
      container.read(expensesProvider.future),
      throwsStateError,
    );
    repository.failReads = false;
    container.read(expenseActionsProvider).refresh();
    expect(await container.read(expensesProvider.future), isEmpty);
  });
}
