import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:expense_pro/features/expenses/data/expense_database.dart';
import 'package:expense_pro/features/expenses/data/sqlite_expense_repository.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_filter.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_preferences.dart';

void main() {
  late Directory directory;
  late ExpenseDatabase database;
  late SqliteExpenseRepository repository;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('expense_repository_');
    database = ExpenseDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/expenses.sqlite',
    );
    repository = SqliteExpenseRepository(database);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Expense value({
    String title = 'Lunch',
    int amountCents = 32550,
    ExpenseCategory category = ExpenseCategory.food,
    DateTime? occurredAt,
    String note = '',
  }) => Expense(
    title: title,
    amountCents: amountCents,
    category: category,
    occurredAt: occurredAt ?? DateTime(2026, 10, 26, 12),
    note: note,
    paymentMethod: PaymentMethod.mobileBanking,
  );

  ExpenseFilter filter({ExpenseCategory? category, String search = ''}) =>
      ExpenseFilter(
        range: DateRange.forPeriod(ExpensePeriod.month, DateTime(2026, 10, 26)),
        category: category,
        search: search,
      );

  test(
    'SQLite creates, persists across reopen, updates and deletes expenses',
    () async {
      final saved = await repository.saveExpense(value(note: 'At the market'));
      expect(saved.id, isPositive);
      await database.close();
      final reopened = await repository.getExpenses(filter());
      expect(reopened, hasLength(1));
      expect(reopened.single.id, saved.id);
      expect(reopened.single.amountCents, 32550);
      expect(reopened.single.note, 'At the market');
      expect(reopened.single.paymentMethod, PaymentMethod.mobileBanking);
      expect(reopened.single.occurredAt, saved.occurredAt);
      await repository.saveExpense(
        saved.copyWith(title: 'Dinner', amountCents: 20000),
      );
      expect((await repository.getExpenses(filter())).single.title, 'Dinner');
      await repository.deleteExpense(saved.id!);
      expect(await repository.getExpenses(filter()), isEmpty);
      await expectLater(
        repository.saveExpense(saved.copyWith(title: 'Missing')),
        throwsStateError,
      );
    },
  );

  test('range is half-open, category composes with search and results are newest first', () async {
    await repository.saveExpense(
      value(
        title: 'Before range',
        occurredAt: DateTime(2026, 9, 30, 23, 59, 59),
      ),
    );
    final start = await repository.saveExpense(
      value(title: 'Lunch early', occurredAt: DateTime(2026, 10)),
    );
    final late = await repository.saveExpense(
      value(
        title: 'Lunch late',
        occurredAt: DateTime(2026, 10, 31, 23, 59, 59),
      ),
    );
    await repository.saveExpense(
      value(title: 'Lunch outside', occurredAt: DateTime(2026, 11)),
    );
    await repository.saveExpense(
      value(title: 'Lunch transport', category: ExpenseCategory.transport),
    );
    final items = await repository.getExpenses(
      filter(category: ExpenseCategory.food, search: 'LUNCH'),
    );
    expect(items.map((expense) => expense.id), [late.id, start.id]);
    expect(await repository.getExpenses(filter()), hasLength(3));
  });

  test(
    'search treats SQL wildcard characters and quotes as literal user text',
    () async {
      await repository.saveExpense(
        value(title: r'50%_\ discount', note: "O'Brien"),
      );
      await repository.saveExpense(value(title: 'Ordinary purchase'));
      expect(await repository.getExpenses(filter(search: '%_')), hasLength(1));
      expect(await repository.getExpenses(filter(search: r'\')), hasLength(1));
      expect(
        await repository.getExpenses(filter(search: "O'Brien")),
        hasLength(1),
      );
      expect(
        await repository.getExpenses(filter(search: "' OR 1=1 --")),
        isEmpty,
      );
    },
  );

  test(
    'settings defaults and budget/currency changes survive reopening',
    () async {
      final defaults = await repository.getPreferences();
      expect(defaults.currency, ExpenseCurrency.bdt);
      expect(defaults.monthlyBudgetCents, 0);
      await repository.savePreferences(
        ExpensePreferences(
          currency: ExpenseCurrency.eur,
          monthlyBudgetCents: 120000,
        ),
      );
      await database.close();
      final preferences = await repository.getPreferences();
      expect(preferences.currency, ExpenseCurrency.eur);
      expect(preferences.monthlyBudgetCents, 120000);
      await repository.savePreferences(
        preferences.copyWith(monthlyBudgetCents: 0),
      );
      expect((await repository.getPreferences()).monthlyBudgetCents, 0);
    },
  );

  test('database schema rejects invalid amounts even below the repository boundary', () async {
    final connection = await database.database;
    await expectLater(
      connection.insert('expenses', {
        'title': 'Invalid',
        'amount_cents': 0,
        'category': 'food',
        'occurred_at': DateTime(2026).millisecondsSinceEpoch,
        'note': '',
        'payment_method': 'cash',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
