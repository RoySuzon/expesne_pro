import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_pro/core/app_theme.dart';
import 'package:expense_pro/core/formatters.dart';

import '../../domain/entities/expense.dart';
import '../providers/expense_providers.dart';
import 'expense_ui.dart';

Future<void> showExpenseEditor(BuildContext context, {Expense? expense}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.canvas,
      builder: (context) => ExpenseEditor(expense: expense),
    );

class ExpenseEditor extends ConsumerStatefulWidget {
  const ExpenseEditor({super.key, this.expense});
  final Expense? expense;

  @override
  ConsumerState<ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<ExpenseEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late ExpenseCategory _category;
  late PaymentMethod _payment;
  late DateTime _date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _title = TextEditingController(text: expense?.title ?? '');
    _amount = TextEditingController(
      text: expense == null
          ? ''
          : (expense.amountCents / 100).toStringAsFixed(2),
    );
    _note = TextEditingController(text: expense?.note ?? '');
    _category = expense?.category ?? ExpenseCategory.food;
    _payment = expense?.paymentMethod ?? PaymentMethod.cash;
    _date = expense?.occurredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final expense = Expense(
        id: widget.expense?.id,
        amountCents: parseAmountCents(_amount.text)!,
        title: _title.text.trim(),
        category: _category,
        occurredAt: _date,
        note: _note.text.trim(),
        paymentMethod: _payment,
      );
      await ref.read(expenseActionsProvider).save(expense);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null ? 'Expense added' : 'Expense updated',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t save this expense. Your changes are still here. Please try again.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: const Text(
          'This removes the entry from your device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep expense'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(expenseActionsProvider).delete(widget.expense!.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Expense deleted')));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t delete this expense. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferencesState = ref.watch(preferencesProvider);
    if (preferencesState.isLoading || preferencesState.hasError) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: PreferencesReadState(
          loading: preferencesState.isLoading,
          onRetry: () => ref.invalidate(preferencesProvider),
        ),
      );
    }
    final preferences = preferencesState.requireValue;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
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
                        widget.expense == null
                            ? 'Add an expense'
                            : 'Edit expense',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'A little entry. A clearer picture.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('expense-amount-field'),
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixText: '${preferences.currency.name.toUpperCase()}  ',
                  ),
                  validator: (value) => parseAmountCents(value ?? '') == null
                      ? 'Enter an amount greater than zero (up to 2 decimal places).'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('expense-title-field'),
                  controller: _title,
                  enabled: !_saving,
                  maxLength: Expense.maxTitleLength,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Expense title',
                    hintText: 'What did you spend on?',
                    counterText: '',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Give your expense a title.'
                      : null,
                ),
                const SizedBox(height: 22),
                const Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in ExpenseCategory.values)
                      ChoiceChip(
                        avatar: Icon(
                          categoryIcon(category),
                          size: 17,
                          color: _category == category
                              ? AppColors.ink
                              : categoryColor(category),
                        ),
                        label: Text(categoryLabel(category)),
                        selected: _category == category,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _category = category),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                    ),
                    title: const Text(
                      'Date',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    subtitle: Text(
                      formatExpenseDate(_date),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _saving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (picked != null && mounted) {
                              setState(
                                () => _date = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  _date.hour,
                                  _date.minute,
                                ),
                              );
                            }
                          },
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: _payment,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Paid with',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    for (final method in PaymentMethod.values)
                      DropdownMenuItem(
                        value: method,
                        child: Text(
                          paymentLabel(method),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _payment = value!),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _note,
                  enabled: !_saving,
                  maxLines: 2,
                  maxLength: Expense.maxNoteLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Anything you want to remember',
                    counterText: '',
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
                  child: FilledButton.icon(
                    key: const Key('save-expense-button'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Saving…' : 'Save expense'),
                  ),
                ),
                if (widget.expense != null)
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete expense'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
