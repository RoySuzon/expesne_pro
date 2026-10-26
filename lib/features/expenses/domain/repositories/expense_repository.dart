import '../entities/expense.dart';
import '../entities/expense_filter.dart';
import '../entities/expense_preferences.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getExpenses(ExpenseFilter filter);
  Future<Expense> saveExpense(Expense expense);
  Future<void> deleteExpense(int id);
  Future<ExpensePreferences> getPreferences();
  Future<void> savePreferences(ExpensePreferences preferences);
}
