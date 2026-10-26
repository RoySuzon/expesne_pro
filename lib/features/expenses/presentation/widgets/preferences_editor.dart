import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_pro/core/app_theme.dart';
import 'package:expense_pro/core/formatters.dart';

import '../../domain/entities/expense_preferences.dart';
import '../providers/expense_providers.dart';
import 'expense_ui.dart';

Future<void> showPreferencesEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      builder: (context) => Consumer(
        builder: (context, ref, child) => ref
            .watch(preferencesProvider)
            .when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.all(24),
                child: LoadError(
                  onRetry: () => ref.invalidate(preferencesProvider),
                ),
              ),
              data: (preferences) =>
                  PreferencesEditor(preferences: preferences),
            ),
      ),
    );

class PreferencesEditor extends ConsumerStatefulWidget {
  const PreferencesEditor({required this.preferences, super.key});
  final ExpensePreferences preferences;

  @override
  ConsumerState<PreferencesEditor> createState() => _PreferencesEditorState();
}

class _PreferencesEditorState extends ConsumerState<PreferencesEditor> {
  final _form = GlobalKey<FormState>();
  late ExpenseCurrency _currency;
  late final TextEditingController _budget;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currency = widget.preferences.currency;
    _budget = TextEditingController(
      text: widget.preferences.monthlyBudgetCents == 0
          ? ''
          : (widget.preferences.monthlyBudgetCents / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(preferencesProvider.notifier)
          .save(
            ExpensePreferences(
              currency: _currency,
              monthlyBudgetCents: _budget.text.trim().isEmpty
                  ? 0
                  : parseAmountCents(_budget.text, allowZero: true)!,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t save your preferences. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Make it yours',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close settings',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Text(
                'A few preferences for your everyday.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<ExpenseCurrency>(
                initialValue: _currency,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                items: [
                  for (final currency in ExpenseCurrency.values)
                    DropdownMenuItem(
                      value: currency,
                      child: Text(
                        currencyLabel(currency),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (currency) => setState(() => _currency = currency!),
              ),
              const SizedBox(height: 10),
              const Text(
                'Changes the currency label for all entries. Existing amounts are not converted.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('monthly-budget-field'),
                controller: _budget,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Monthly budget (optional)',
                  hintText: 'Set a gentle spending limit',
                  prefixText: '${_currency.name.toUpperCase()}  ',
                ),
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        parseAmountCents(value, allowZero: true) != null
                    ? null
                    : 'Enter a valid budget with up to 2 decimal places.',
              ),
              const SizedBox(height: 10),
              const Text(
                'Leave blank or enter zero to turn the budget off.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              const SurfaceCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Private by default',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your expenses are stored on this device. No account, no connection required.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-settings-button'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save preferences'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
