// lib/services/sync_service.dart
import 'expense_service.dart';

class SyncService {
  final ExpenseService expenses;

  SyncService({required this.expenses});

  Future<void> syncNow() async {
    await expenses.syncFromServer();
  }
}
