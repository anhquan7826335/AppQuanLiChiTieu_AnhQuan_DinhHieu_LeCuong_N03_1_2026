import 'BaseEntity.dart';

class Transaction extends BaseEntity {
  @override
  int id;
  String description;
  double amount;
  DateTime date;

  Transaction(this.id, this.description, this.amount, this.date);

  // Giữ lại các alias getter/setter cũ để tương thích với mã hiện tại
  int get transactionId => id;
  set transactionId(int value) => id = value;

  String get transactionDescription => description;
  set transactionDescription(String value) => description = value;

  double get transactionAmount => amount;
  set transactionAmount(double value) => amount = value;

  DateTime get transactionDate => date;
  set transactionDate(DateTime value) => date = value;

  void showInfo() {
    print("ID: $id, Mô tả: $description, Số tiền: $amount, Ngày: $date");
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      json['id'] as int,
      json['description'] as String,
      (json['amount'] as num).toDouble(),
      DateTime.parse(json['date'] as String),
    );
  }

  @override
  String toString() {
    return 'Transaction{id: $id, description: $description, amount: $amount, date: $date}';
  }
}

