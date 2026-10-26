import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/expense_database.dart';
import '../../data/sqlite_expense_repository.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_filter.dart';
import '../../domain/entities/expense_preferences.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/usecases/build_expense_summary.dart';

final databaseProvider = Provider<ExpenseDatabase>((ref) {
  final database = ExpenseDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final repositoryProvider = Provider<ExpenseRepository>(
  (ref) => SqliteExpenseRepository(ref.watch(databaseProvider)),
);

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final class ExpenseViewState {
  const ExpenseViewState({
    required this.anchor,
    this.period = ExpensePeriod.month,
    this.category,
    this.search = '',
  });

  final DateTime anchor;
  final ExpensePeriod period;
  final ExpenseCategory? category;
  final String search;

  DateRange get range => DateRange.forPeriod(period, anchor);
  ExpenseFilter get filter =>
      ExpenseFilter(range: range, category: category, search: search);

  ExpenseViewState copyWith({
    DateTime? anchor,
    ExpensePeriod? period,
    ExpenseCategory? category,
    bool clearCategory = false,
    String? search,
  }) => ExpenseViewState(
    anchor: anchor ?? this.anchor,
    period: period ?? this.period,
    category: clearCategory ? null : category ?? this.category,
    search: search ?? this.search,
  );
}

final viewStateProvider =
    NotifierProvider<ExpenseViewController, ExpenseViewState>(
      ExpenseViewController.new,
    );

class ExpenseViewController extends Notifier<ExpenseViewState> {
  @override
  ExpenseViewState build() =>
      ExpenseViewState(anchor: ref.read(clockProvider)());

  void setPeriod(ExpensePeriod period) =>
      state = state.copyWith(period: period);

  void move(int steps) => state = state.copyWith(
    anchor: shiftPeriod(state.anchor, state.period, steps),
  );

  void today() => state = state.copyWith(anchor: ref.read(clockProvider)());

  void setCategory(ExpenseCategory? category) => state = state.copyWith(
    category: category,
    clearCategory: category == null,
  );

  void setSearch(String search) => state = state.copyWith(search: search);
}

final expensesProvider = FutureProvider<List<Expense>>((ref) {
  final filter = ref.watch(viewStateProvider).filter;
  return ref.watch(repositoryProvider).getExpenses(filter);
});

/// Totals and insights always describe the entire selected period.
final periodExpensesProvider = FutureProvider<List<Expense>>((ref) {
  final selection = ref.watch(
    viewStateProvider.select((state) => (state.period, state.anchor)),
  );
  final range = DateRange.forPeriod(selection.$1, selection.$2);
  return ref.watch(repositoryProvider).getExpenses(ExpenseFilter(range: range));
});

/// Budget progress remains monthly even when the list is filtered to a day/year.
final monthlyExpensesProvider = FutureProvider<List<Expense>>((ref) {
  final anchor = ref.watch(viewStateProvider.select((state) => state.anchor));
  final range = DateRange.forPeriod(ExpensePeriod.month, anchor);
  return ref.watch(repositoryProvider).getExpenses(ExpenseFilter(range: range));
});

final expenseSummaryProvider = Provider<AsyncValue<ExpenseSummary>>((ref) {
  return ref.watch(periodExpensesProvider).whenData(buildExpenseSummary);
});

final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, ExpensePreferences>(
      PreferencesController.new,
    );

class PreferencesController extends AsyncNotifier<ExpensePreferences> {
  @override
  Future<ExpensePreferences> build() =>
      ref.watch(repositoryProvider).getPreferences();

  Future<void> save(ExpensePreferences preferences) async {
    await ref.read(repositoryProvider).savePreferences(preferences);
    state = AsyncData(preferences);
  }
}

final expenseActionsProvider = Provider<ExpenseActions>(ExpenseActions.new);

class ExpenseActions {
  ExpenseActions(this.ref);

  final Ref ref;

  Future<Expense> save(Expense expense) async {
    final saved = await ref.read(repositoryProvider).saveExpense(expense);
    _refreshExpenses();
    return saved;
  }

  Future<void> delete(int id) async {
    await ref.read(repositoryProvider).deleteExpense(id);
    _refreshExpenses();
  }

  void refresh() {
    _refreshExpenses();
    ref.invalidate(preferencesProvider);
  }

  void _refreshExpenses() {
    ref.invalidate(expensesProvider);
    ref.invalidate(periodExpensesProvider);
    ref.invalidate(monthlyExpensesProvider);
  }
}
