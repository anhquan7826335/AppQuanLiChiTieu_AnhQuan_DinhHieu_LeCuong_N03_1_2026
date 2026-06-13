import 'package:flutter_test/flutter_test.dart';

// Mock cấu trúc Model Expense dựa trên cấu hình Appwrite Database
class Expense {
  final String userId;
  final double amount;
  final String category;
  final DateTime date;
  final String? description;

  Expense({
    required this.userId,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'description': description,
    };
  }
}

void main() {
  group('Expense Model Unit Tests', () {
    test('Tạo mới một Expense instance chính xác', () {
      final date = DateTime(2026, 6, 13);
      final expense = Expense(
        userId: 'user123',
        amount: 55000.0,
        category: 'Food',
        date: date,
      );

      expect(expense.userId, 'user123');
      expect(expense.amount, 55000.0);
      expect(expense.category, 'Food');
    });

    test('Chuyển đổi Expense sang dạng Map chuẩn JSON', () {
      final date = DateTime(2026, 6, 13);
      final expense = Expense(
        userId: 'user123',
        amount: 150000.0,
        category: 'Shopping',
        date: date,
        description: 'Mua đồ siêu thị',
      );

      final map = expense.toMap();
      expect(map['userId'], 'user123');
      expect(map['amount'], 150000.0);
      expect(map['category'], 'Shopping');
      expect(map['date'], date.toIso8601String());
      expect(map['description'], 'Mua đồ siêu thị');
    });
  });
}