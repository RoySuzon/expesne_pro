import 'package:sqflite/sqflite.dart';

import '../domain/entities/expense.dart';
import '../domain/entities/expense_filter.dart';
import '../domain/entities/expense_preferences.dart';
import '../domain/repositories/expense_repository.dart';
import 'expense_database.dart';

final class SqliteExpenseRepository implements ExpenseRepository {
  SqliteExpenseRepository(this._database);

  final ExpenseDatabase _database;

  @override
  Future<List<Expense>> getExpenses(ExpenseFilter filter) async {
    final database = await _database.database;
    final conditions = ['occurred_at >= ?', 'occurred_at < ?'];
    final arguments = <Object>[
      filter.range.start.millisecondsSinceEpoch,
      filter.range.end.millisecondsSinceEpoch,
    ];
    if (filter.category != null) {
      conditions.add('category = ?');
      arguments.add(filter.category!.name);
    }
    if (filter.search.isNotEmpty) {
      conditions.add(r"(title LIKE ? ESCAPE '\' OR note LIKE ? ESCAPE '\')");
      final pattern = '%${_escapeLike(filter.search)}%';
      arguments.addAll([pattern, pattern]);
    }
    final rows = await database.query(
      'expenses',
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'occurred_at DESC, id DESC',
    );
    return List.unmodifiable(rows.map(_fromRow));
  }

  @override
  Future<Expense> saveExpense(Expense expense) async {
    final database = await _database.database;
    final row = <String, Object?>{
      'title': expense.title,
      'amount_cents': expense.amountCents,
      'category': expense.category.name,
      'occurred_at': expense.occurredAt.millisecondsSinceEpoch,
      'note': expense.note,
      'payment_method': expense.paymentMethod.name,
    };
    if (expense.id == null) {
      final id = await database.insert('expenses', row);
      return expense.copyWith(id: id);
    }
    final count = await database.update(
      'expenses',
      row,
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    if (count != 1) throw StateError('This expense no longer exists.');
    return expense;
  }

  @override
  Future<void> deleteExpense(int id) async {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'Must be positive.');
    final database = await _database.database;
    await database.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<ExpensePreferences> getPreferences() async {
    final database = await _database.database;
    final rows = await database.query('settings');
    final settings = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    final currency =
        ExpenseCurrency.values
            .where((value) => value.name == settings['currency'])
            .firstOrNull ??
        ExpenseCurrency.bdt;
    final budget = int.tryParse(settings['monthly_budget_cents'] ?? '') ?? 0;
    return ExpensePreferences(
      currency: currency,
      monthlyBudgetCents: budget >= 0 && budget <= Expense.maxAmountCents
          ? budget
          : 0,
    );
  }

  @override
  Future<void> savePreferences(ExpensePreferences preferences) async {
    final database = await _database.database;
    await database.transaction((transaction) async {
      for (final entry in {
        'currency': preferences.currency.name,
        'monthly_budget_cents': preferences.monthlyBudgetCents.toString(),
      }.entries) {
        await transaction.insert('settings', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  static Expense _fromRow(Map<String, Object?> row) => Expense(
    id: row['id'] as int,
    title: row['title'] as String,
    amountCents: row['amount_cents'] as int,
    category: ExpenseCategory.values.byName(row['category'] as String),
    occurredAt: DateTime.fromMillisecondsSinceEpoch(row['occurred_at'] as int),
    note: row['note'] as String,
    paymentMethod: PaymentMethod.values.byName(row['payment_method'] as String),
  );
}
