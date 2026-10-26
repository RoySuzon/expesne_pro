import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:expense_pro/core/app_theme.dart';
import 'package:expense_pro/core/formatters.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_filter.dart';
import '../../domain/entities/expense_preferences.dart';
import '../../domain/usecases/build_expense_summary.dart';
import '../providers/expense_providers.dart';
import '../widgets/expense_editor.dart';
import '../widgets/expense_ui.dart';
import '../widgets/preferences_editor.dart';

class ExpenseHomeScreen extends ConsumerStatefulWidget {
  const ExpenseHomeScreen({super.key});

  @override
  ConsumerState<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends ConsumerState<ExpenseHomeScreen> {
  int _tab = 0;
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _add() => showExpenseEditor(context);

  void _selectTab(int value) {
    // Each destination starts with its own heading and period controls in view.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _tab = value);
  }

  void _clearFilters() {
    _search.clear();
    ref.read(viewStateProvider.notifier).setCategory(null);
    ref.read(viewStateProvider.notifier).setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(viewStateProvider);
    final preferencesState = ref.watch(preferencesProvider);
    if (preferencesState.isLoading || preferencesState.hasError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PreferencesReadState(
                loading: preferencesState.isLoading,
                onRetry: () => ref.invalidate(preferencesProvider),
              ),
            ),
          ),
        ),
      );
    }
    final preferences = preferencesState.requireValue;
    final periodExpenses = ref.watch(periodExpensesProvider);
    final filteredExpenses = ref.watch(expensesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-expense-button'),
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add expense',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.lime,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_small_outlined),
            selectedIcon: Icon(Icons.donut_small_rounded),
            label: 'Insights',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(expenseActionsProvider).refresh();
            try {
              await ref.read(periodExpensesProvider.future);
            } catch (_) {
              /* The page displays its retry state. */
            }
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 104),
                children: [
                  _Header(onSettings: () => showPreferencesEditor(context)),
                  const SizedBox(height: 28),
                  Text(
                    switch (_tab) {
                      0 => 'A little more clarity.',
                      1 => 'Your spending story.',
                      _ => 'See the bigger picture.',
                    },
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    switch (_tab) {
                      0 => 'Small entries. Better everyday decisions.',
                      1 => 'Every entry, right where you need it.',
                      _ => 'Find the patterns behind your everyday.',
                    },
                    style: const TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  _PeriodPicker(state: state),
                  const SizedBox(height: 20),
                  if (_tab == 1) ...[
                    TextField(
                      key: const Key('search-expenses-field'),
                      controller: _search,
                      onChanged: ref.read(viewStateProvider.notifier).setSearch,
                      decoration: InputDecoration(
                        hintText: 'Search expenses or notes',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: state.search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  ref
                                      .read(viewStateProvider.notifier)
                                      .setSearch('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text('All categories'),
                              selected: state.category == null,
                              onSelected: (_) => ref
                                  .read(viewStateProvider.notifier)
                                  .setCategory(null),
                              showCheckmark: false,
                            ),
                          ),
                          for (final category in ExpenseCategory.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(categoryLabel(category)),
                                selected: state.category == category,
                                avatar: Icon(categoryIcon(category), size: 16),
                                showCheckmark: false,
                                onSelected: (_) => ref
                                    .read(viewStateProvider.notifier)
                                    .setCategory(category),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    filteredExpenses.when(
                      loading: () => const _LoadingCard(),
                      error: (error, stack) => LoadError(
                        onRetry: () => ref.invalidate(expensesProvider),
                      ),
                      data: (expenses) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ActivitySummary(
                            expenses: expenses,
                            currency: preferences.currency,
                          ),
                          const SizedBox(height: 22),
                          if (expenses.isEmpty)
                            EmptyExpenses(
                              filtered:
                                  state.category != null ||
                                  state.search.isNotEmpty,
                              onAdd: _add,
                              onReset: _clearFilters,
                            )
                          else
                            _ExpenseList(
                              expenses: expenses,
                              currency: preferences.currency,
                              grouped: true,
                            ),
                        ],
                      ),
                    ),
                  ] else
                    periodExpenses.when(
                      loading: () => const _LoadingCard(),
                      error: (error, stack) => LoadError(
                        onRetry: () => ref.invalidate(periodExpensesProvider),
                      ),
                      data: (expenses) => _tab == 0
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SpendingCard(
                                  expenses: expenses,
                                  currency: preferences.currency,
                                  state: state,
                                ),
                                const SizedBox(height: 16),
                                _BudgetCard(
                                  preferences: preferences,
                                  monthExpenses: ref.watch(
                                    monthlyExpensesProvider,
                                  ),
                                  anchor: state.anchor,
                                  onEdit: () => showPreferencesEditor(context),
                                ),
                                const SizedBox(height: 24),
                                SectionHeading(
                                  'Recent expenses',
                                  action: 'View all',
                                  onAction: () => _selectTab(1),
                                ),
                                const SizedBox(height: 12),
                                if (expenses.isEmpty)
                                  EmptyExpenses(onAdd: _add)
                                else
                                  _ExpenseList(
                                    expenses: expenses.take(5).toList(),
                                    currency: preferences.currency,
                                  ),
                                if (expenses.isNotEmpty) ...[
                                  const SizedBox(height: 26),
                                  SectionHeading(
                                    'Where it went',
                                    action: 'Insights',
                                    onAction: () => _selectTab(2),
                                  ),
                                  const SizedBox(height: 12),
                                  _CategoryBreakdown(
                                    expenses: expenses,
                                    currency: preferences.currency,
                                    limit: 3,
                                  ),
                                ],
                              ],
                            )
                          : _Insights(
                              expenses: expenses,
                              currency: preferences.currency,
                              state: state,
                              onAdd: _add,
                            ),
                    ),
                  const SizedBox(height: 28),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: AppColors.muted,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'On your device. Always yours.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: AppColors.lime,
          size: 23,
        ),
      ),
      const SizedBox(width: 11),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Pro',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            Text(
              'EVERYDAY, IN BALANCE',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        key: const Key('settings-button'),
        onPressed: onSettings,
        tooltip: 'Settings',
        icon: const Icon(Icons.tune_rounded, size: 21),
      ),
    ],
  );
}

class _PeriodPicker extends ConsumerWidget {
  const _PeriodPicker({required this.state});
  final ExpenseViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(viewStateProvider.notifier);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFE8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (final period in ExpensePeriod.values)
                Expanded(
                  child: Material(
                    color: state.period == period
                        ? AppColors.ink
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => controller.setPeriod(period),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          switch (period) {
                            ExpensePeriod.day => 'Day',
                            ExpensePeriod.week => 'Week',
                            ExpensePeriod.month => 'Month',
                            ExpensePeriod.year => 'Year',
                          },
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: state.period == period
                                ? Colors.white
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous period',
              onPressed: () => controller.move(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                formatPeriodLabel(state.period, state.anchor),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next period',
              onPressed: () => controller.move(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            TextButton(
              onPressed: controller.today,
              child: const Text('Today', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.expenses,
    required this.currency,
    required this.state,
  });
  final List<Expense> expenses;
  final ExpenseCurrency currency;
  final ExpenseViewState state;

  @override
  Widget build(BuildContext context) {
    final total = buildExpenseSummary(expenses).totalCents;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TOTAL SPENT',
                  style: TextStyle(
                    color: Color(0xFFC1D2C6),
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.south_west_rounded,
                      size: 13,
                      color: AppColors.lime,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${expenses.length} ${expenses.length == 1 ? 'entry' : 'entries'}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(total, currency),
                style: const TextStyle(
                  fontSize: 43,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.8,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Your ${state.period.name} at a glance',
            style: const TextStyle(color: Color(0xFFB7CBBE), fontSize: 12),
          ),
          const SizedBox(height: 26),
          Container(height: 1, color: Colors.white.withValues(alpha: .12)),
          const SizedBox(height: 21),
          _SpendingChart(expenses: expenses, state: state, dark: true),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.preferences,
    required this.monthExpenses,
    required this.anchor,
    required this.onEdit,
  });
  final ExpensePreferences preferences;
  final AsyncValue<List<Expense>> monthExpenses;
  final DateTime anchor;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final budget = preferences.monthlyBudgetCents;
    final monthly = monthExpenses.value;
    final spent = monthly == null ? 0 : buildExpenseSummary(monthly).totalCents;
    final remaining = budget - spent;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.track_changes_rounded,
                size: 19,
                color: AppColors.ink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${DateFormat.MMMM().format(anchor)} budget',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    budget == 0 ? 'Set budget' : 'Edit',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (budget == 0)
            const Text(
              'Give your month a little direction. Set a budget that works for you.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.5,
              ),
            )
          else
            monthExpenses.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => const Text(
                'Budget spending is temporarily unavailable.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              data: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatMoney(
                            math.max(0, remaining),
                            preferences.currency,
                          ),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                      ),
                      Text(
                        'of ${formatMoney(budget, preferences.currency, compact: true)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    remaining >= 0
                        ? 'left to spend this month'
                        : '${formatMoney(-remaining, preferences.currency)} over your monthly budget',
                    style: TextStyle(
                      fontSize: 11,
                      color: remaining < 0 ? AppColors.danger : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 13),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (spent / budget).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: AppColors.border,
                      color: remaining < 0
                          ? AppColors.danger
                          : const Color(0xFF83AA63),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.expenses, required this.currency});
  final List<Expense> expenses;
  final ExpenseCurrency currency;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          '${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'}',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ),
      Flexible(
        child: Text(
          formatMoney(buildExpenseSummary(expenses).totalCents, currency),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({
    required this.expenses,
    required this.currency,
    this.grouped = false,
  });
  final List<Expense> expenses;
  final ExpenseCurrency currency;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    DateTime? lastDate;
    for (final expense in expenses) {
      final date = DateUtils.dateOnly(expense.occurredAt);
      if (grouped && date != lastDate) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 20, 2, 12),
            child: Text(
              formatExpenseDate(date),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
        );
        lastDate = date;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(19),
              side: const BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () => showExpenseEditor(context, expense: expense),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CategoryBadge(expense.category),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            categoryLabel(expense.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '−${formatMoney(expense.amountCents, currency)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            grouped
                                ? paymentLabel(expense.paymentMethod)
                                : DateFormat.MMMd().format(expense.occurredAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({
    required this.expenses,
    required this.currency,
    required this.state,
    required this.onAdd,
  });
  final List<Expense> expenses;
  final ExpenseCurrency currency;
  final ExpenseViewState state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return EmptyExpenses(onAdd: onAdd);
    final summary = buildExpenseSummary(expenses);
    final largest = summary.largest!.amountCents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SpendingCard(expenses: expenses, currency: currency, state: state),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Average expense',
                value: formatMoney(
                  summary.averageCents,
                  currency,
                  compact: true,
                ),
                icon: Icons.calendar_today_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Largest expense',
                value: formatMoney(largest, currency, compact: true),
                icon: Icons.north_east_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const SectionHeading('Spending by category'),
        const SizedBox(height: 13),
        _CategoryBreakdown(expenses: expenses, currency: currency),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.muted, size: 19),
        const SizedBox(height: 12),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.expenses,
    required this.currency,
    this.limit,
  });
  final List<Expense> expenses;
  final ExpenseCurrency currency;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final totals = buildExpenseSummary(expenses).categoryTotals;
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = buildExpenseSummary(expenses).totalCents;
    return SurfaceCard(
      child: Column(
        children: [
          for (final (index, entry)
              in entries.take(limit ?? entries.length).indexed) ...[
            if (index != 0) const SizedBox(height: 22),
            Row(
              children: [
                CategoryBadge(entry.key, size: 36),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    categoryLabel(entry.key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatMoney(entry.value, currency, compact: true),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: entry.value / total,
                      backgroundColor: AppColors.border,
                      color: categoryColor(entry.key),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${(entry.value * 100 / total).round()}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SpendingChart extends StatelessWidget {
  const _SpendingChart({
    required this.expenses,
    required this.state,
    this.dark = false,
  });
  final List<Expense> expenses;
  final ExpenseViewState state;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets();
    for (final expense in expenses) {
      for (final bucket in buckets) {
        if (!expense.occurredAt.isBefore(bucket.start) &&
            expense.occurredAt.isBefore(bucket.end)) {
          bucket.total += expense.amountCents;
          break;
        }
      }
    }
    final maximum = buckets.map((bucket) => bucket.total).fold(0, math.max);
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, bucket) in buckets.indexed)
            Expanded(
              child: Semantics(
                label:
                    '${bucket.label}: ${(bucket.total / 100).toStringAsFixed(2)}',
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: buckets.length > 7 ? 3 : 6,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            height: maximum == 0 || bucket.total == 0
                                ? 3
                                : math.max(7.0, 80 * bucket.total / maximum),
                            decoration: BoxDecoration(
                              color: bucket.total == maximum && maximum > 0
                                  ? AppColors.lime
                                  : dark
                                  ? Colors.white.withValues(
                                      alpha: bucket.total == 0 ? .12 : .29,
                                    )
                                  : AppColors.primary.withValues(alpha: .3),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        buckets.length == 12 && index.isOdd ? '' : bucket.label,
                        style: TextStyle(
                          fontSize: 8,
                          color: dark
                              ? const Color(0xFFB7CBBE)
                              : AppColors.muted,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_ChartBucket> _buckets() {
    final start = state.range.start;
    return switch (state.period) {
      ExpensePeriod.day => [
        for (var hour = 0; hour < 24; hour += 4)
          _ChartBucket(
            DateTime(start.year, start.month, start.day, hour),
            DateTime(start.year, start.month, start.day, hour + 4),
            hour == 0
                ? '12a'
                : hour < 12
                ? '${hour}a'
                : hour == 12
                ? '12p'
                : '${hour - 12}p',
          ),
      ],
      ExpensePeriod.week => [
        for (var day = 0; day < 7; day++)
          _ChartBucket(
            DateTime(start.year, start.month, start.day + day),
            DateTime(start.year, start.month, start.day + day + 1),
            DateFormat.E().format(
              DateTime(start.year, start.month, start.day + day),
            ),
          ),
      ],
      ExpensePeriod.month => [
        for (
          var day = 1;
          day <= DateTime(start.year, start.month + 1, 0).day;
          day += 7
        )
          _ChartBucket(
            DateTime(start.year, start.month, day),
            day + 7 > DateTime(start.year, start.month + 1, 0).day
                ? state.range.end
                : DateTime(start.year, start.month, day + 7),
            '$day',
          ),
      ],
      ExpensePeriod.year => [
        for (var month = 1; month <= 12; month++)
          _ChartBucket(
            DateTime(start.year, month),
            DateTime(start.year, month + 1),
            DateFormat.MMM().format(DateTime(start.year, month)),
          ),
      ],
    };
  }
}

class _ChartBucket {
  _ChartBucket(this.start, this.end, this.label);
  final DateTime start;
  final DateTime end;
  final String label;
  int total = 0;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const SurfaceCard(
    child: SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}
