import 'package:flutter/material.dart';

import 'package:expense_pro/core/app_theme.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_preferences.dart';

String categoryLabel(ExpenseCategory category) => switch (category) {
  ExpenseCategory.food => 'Food & drinks',
  ExpenseCategory.transport => 'Transport',
  ExpenseCategory.shopping => 'Shopping',
  ExpenseCategory.bills => 'Bills & utilities',
  ExpenseCategory.health => 'Health',
  ExpenseCategory.entertainment => 'Entertainment',
  ExpenseCategory.education => 'Education',
  ExpenseCategory.other => 'Other',
};

IconData categoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.food => Icons.restaurant_rounded,
  ExpenseCategory.transport => Icons.directions_bus_rounded,
  ExpenseCategory.shopping => Icons.shopping_bag_rounded,
  ExpenseCategory.bills => Icons.receipt_long_rounded,
  ExpenseCategory.health => Icons.favorite_rounded,
  ExpenseCategory.entertainment => Icons.movie_rounded,
  ExpenseCategory.education => Icons.auto_stories_rounded,
  ExpenseCategory.other => Icons.more_horiz_rounded,
};

Color categoryColor(ExpenseCategory category) => switch (category) {
  ExpenseCategory.food => const Color(0xFFBC733C),
  ExpenseCategory.transport => const Color(0xFF447E89),
  ExpenseCategory.shopping => const Color(0xFF9165A3),
  ExpenseCategory.bills => const Color(0xFF6E8062),
  ExpenseCategory.health => const Color(0xFFC46777),
  ExpenseCategory.entertainment => const Color(0xFF7376B7),
  ExpenseCategory.education => const Color(0xFF518467),
  ExpenseCategory.other => const Color(0xFF7A817B),
};

String paymentLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Cash',
  PaymentMethod.card => 'Card',
  PaymentMethod.mobileBanking => 'Mobile banking',
};

String currencyLabel(ExpenseCurrency currency) => switch (currency) {
  ExpenseCurrency.bdt => 'BDT · Bangladeshi taka',
  ExpenseCurrency.usd => 'USD · US dollar',
  ExpenseCurrency.eur => 'EUR · Euro',
  ExpenseCurrency.gbp => 'GBP · British pound',
  ExpenseCurrency.inr => 'INR · Indian rupee',
};

class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key, this.size = 46});
  final ExpenseCategory category;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: categoryColor(category).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(
      categoryIcon(category),
      color: categoryColor(category),
      size: size * .48,
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class EmptyExpenses extends StatelessWidget {
  const EmptyExpenses({
    super.key,
    this.filtered = false,
    this.onAdd,
    this.onReset,
  });
  final bool filtered;
  final VoidCallback? onAdd;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: Color(0xFFEDF3E7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            filtered ? Icons.search_off_rounded : Icons.savings_outlined,
            size: 36,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          filtered ? 'No matching expenses' : 'A fresh start for your spending',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          filtered ? 'Try another search or clear your category filter.' : 'Add your first expense. Every little entry helps you see the bigger picture.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: filtered ? onReset : onAdd,
          icon: Icon(
            filtered ? Icons.filter_alt_off_outlined : Icons.add_rounded,
          ),
          label: Text(filtered ? 'Clear filters' : 'Add your first expense'),
        ),
      ],
    ),
  );
}

class LoadError extends StatelessWidget {
  const LoadError({required this.onRetry, super.key});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.muted),
        const SizedBox(height: 12),
        const Text(
          'Couldn’t load your expenses',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your entries stay on this device. Please try again.',
          textAlign: TextAlign.center,
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class PreferencesReadState extends StatelessWidget {
  const PreferencesReadState({
    required this.loading,
    required this.onRetry,
    super.key,
  });
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: loading
        ? const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.muted),
              const SizedBox(height: 14),
              const Text(
                'Couldn’t load your preferences',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please try again to show your expenses in the correct currency.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
  );
}
