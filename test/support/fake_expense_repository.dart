import 'package:expense_pro/features/expenses/domain/entities/expense.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_filter.dart';
import 'package:expense_pro/features/expenses/domain/entities/expense_preferences.dart';
import 'package:expense_pro/features/expenses/domain/repositories/expense_repository.dart';

class FakeExpenseRepository implements ExpenseRepository {
  final expenses = <Expense>[];
  ExpensePreferences preferences = const ExpensePreferences.defaults();
  bool failReads = false;
  bool failWrites = false;
  int _nextId = 1;

  @override
  Future<List<Expense>> getExpenses(ExpenseFilter filter) async {
    if (failReads) throw StateError('Storage unavailable');
    final search = filter.search.toLowerCase();
    return expenses.where((expense) {
      return filter.range.contains(expense.occurredAt) &&
          (filter.category == null || expense.category == filter.category) &&
          (search.isEmpty ||
              expense.title.toLowerCase().contains(search) ||
              expense.note.toLowerCase().contains(search));
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<Expense> saveExpense(Expense expense) async {
    if (failWrites) throw StateError('Storage unavailable');
    if (expense.id == null) {
      final saved = expense.copyWith(id: _nextId++);
      expenses.add(saved);
      return saved;
    }
    final index = expenses.indexWhere((row) => row.id == expense.id);
    if (index < 0) throw StateError('This expense no longer exists.');
    expenses[index] = expense;
    return expense;
  }

  @override
  Future<void> deleteExpense(int id) async {
    if (failWrites) throw StateError('Storage unavailable');
    expenses.removeWhere((row) => row.id == id);
  }

  @override
  Future<ExpensePreferences> getPreferences() async {
    if (failReads) throw StateError('Storage unavailable');
    return preferences;
  }

  @override
  Future<void> savePreferences(ExpensePreferences preferences) async {
    if (failWrites) throw StateError('Storage unavailable');
    this.preferences = preferences;
  }
}
