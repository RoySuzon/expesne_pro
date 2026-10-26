enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  health,
  entertainment,
  education,
  other,
}

enum PaymentMethod { cash, card, mobileBanking }

/// Money is stored as integer minor units to avoid floating-point rounding.
final class Expense {
  Expense({
    this.id,
    required String title,
    required this.amountCents,
    required this.category,
    required DateTime occurredAt,
    String note = '',
    this.paymentMethod = PaymentMethod.cash,
  }) : title = title.trim(),
       note = note.trim(),
       occurredAt = occurredAt.toLocal() {
    if (id != null && id! <= 0) {
      throw ArgumentError.value(id, 'id', 'Must be positive.');
    }
    if (this.title.isEmpty || this.title.length > maxTitleLength) {
      throw ArgumentError.value(title, 'title', 'Enter 1–120 characters.');
    }
    if (amountCents <= 0 || amountCents > maxAmountCents) {
      throw ArgumentError.value(
        amountCents,
        'amountCents',
        'Enter a positive amount within the supported limit.',
      );
    }
    if (this.note.length > maxNoteLength) {
      throw ArgumentError.value(note, 'note', 'Use at most 1,000 characters.');
    }
  }

  static const maxAmountCents = 999999999999;
  static const maxTitleLength = 120;
  static const maxNoteLength = 1000;

  final int? id;
  final String title;
  final int amountCents;
  final ExpenseCategory category;
  final DateTime occurredAt;
  final String note;
  final PaymentMethod paymentMethod;

  Expense copyWith({
    int? id,
    String? title,
    int? amountCents,
    ExpenseCategory? category,
    DateTime? occurredAt,
    String? note,
    PaymentMethod? paymentMethod,
  }) => Expense(
    id: id ?? this.id,
    title: title ?? this.title,
    amountCents: amountCents ?? this.amountCents,
    category: category ?? this.category,
    occurredAt: occurredAt ?? this.occurredAt,
    note: note ?? this.note,
    paymentMethod: paymentMethod ?? this.paymentMethod,
  );
}
