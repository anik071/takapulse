enum ModuleType { income, expense }

class ExpenseModule {
  final int? id;
  final String name;
  final String subtitle;
  final ModuleType type;
  final bool isFixed;
  final double? defaultAmount;
  final String badgeText;
  final String iconKey;
  final int accentColorValue;

  const ExpenseModule({
    this.id,
    required this.name,
    required this.subtitle,
    required this.type,
    required this.isFixed,
    this.defaultAmount,
    required this.badgeText,
    required this.iconKey,
    required this.accentColorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'subtitle': subtitle,
      'type': type == ModuleType.income ? 'INCOME' : 'EXPENSE',
      'is_fixed': isFixed ? 1 : 0,
      'default_amount': defaultAmount,
      'badge_text': badgeText,
      'icon_key': iconKey,
      'accent_color': accentColorValue,
    };
  }

  factory ExpenseModule.fromMap(Map<String, dynamic> map) {
    return ExpenseModule(
      id: map['id'] as int?,
      name: map['name'] as String,
      subtitle: (map['subtitle'] as String?) ?? '',
      type: map['type'] == 'INCOME' ? ModuleType.income : ModuleType.expense,
      isFixed: (map['is_fixed'] as int) == 1,
      defaultAmount: (map['default_amount'] as num?)?.toDouble(),
      badgeText: (map['badge_text'] as String?) ?? 'Variable',
      iconKey: (map['icon_key'] as String?) ?? 'category',
      accentColorValue: (map['accent_color'] as int?) ?? 0xFF47F3BB,
    );
  }
}

class ExpenseTransaction {
  final int? id;
  final int moduleId;
  final String title;
  final String channelOrNote;
  final String categoryLabel;
  final ModuleType type;
  final double amount;
  final bool isFixedEntry;
  final String iconKey;
  final int accentColorValue;
  final DateTime timestamp;
  final String billingMonth; // Format: YYYY-MM

  const ExpenseTransaction({
    this.id,
    required this.moduleId,
    required this.title,
    required this.channelOrNote,
    required this.categoryLabel,
    required this.type,
    required this.amount,
    this.isFixedEntry = false,
    required this.iconKey,
    required this.accentColorValue,
    required this.timestamp,
    required this.billingMonth,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'module_id': moduleId,
      'title': title,
      'channel_or_note': channelOrNote,
      'category_label': categoryLabel,
      'type': type == ModuleType.income ? 'INCOME' : 'EXPENSE',
      'amount': amount,
      'is_fixed_entry': isFixedEntry ? 1 : 0,
      'icon_key': iconKey,
      'accent_color': accentColorValue,
      'timestamp': timestamp.toIso8601String(),
      'billing_month': billingMonth,
    };
  }

  factory ExpenseTransaction.fromMap(Map<String, dynamic> map) {
    return ExpenseTransaction(
      id: map['id'] as int?,
      moduleId: map['module_id'] as int,
      title: map['title'] as String,
      channelOrNote: (map['channel_or_note'] as String?) ?? 'Cash / Direct',
      categoryLabel: (map['category_label'] as String?) ?? 'General',
      type: map['type'] == 'INCOME' ? ModuleType.income : ModuleType.expense,
      amount: (map['amount'] as num).toDouble(),
      isFixedEntry: (map['is_fixed_entry'] as int? ?? 0) == 1,
      iconKey: (map['icon_key'] as String?) ?? 'category',
      accentColorValue: (map['accent_color'] as int?) ?? 0xFF47F3BB,
      timestamp: DateTime.parse(map['timestamp'] as String),
      billingMonth: map['billing_month'] as String,
    );
  }
}

class MonthlySummary {
  final double totalInflow;
  final double totalOutflow;

  const MonthlySummary({
    required this.totalInflow,
    required this.totalOutflow,
  });

  double get netBalance => totalInflow - totalOutflow;

  double get burnRatioPercent {
    if (totalInflow <= 0) return totalOutflow > 0 ? 100.0 : 0.0;
    return ((totalOutflow / totalInflow) * 100).clamp(0.0, 100.0);
  }
}