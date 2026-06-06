import 'package:intl/intl.dart';

class Expense {
  final String id;
  final String title;
  final String category; // Ví dụ: Ăn uống, Di chuyển, ...
  final double amount;
  final DateTime date;
  final String note;

  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Expense copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    String? note,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    title: j['title'] as String,
    category: j['category'] as String,
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date'] as String),
    note: (j['note'] ?? '') as String,
  );

  String get ymd => DateFormat('yyyy-MM-dd').format(date);
}
