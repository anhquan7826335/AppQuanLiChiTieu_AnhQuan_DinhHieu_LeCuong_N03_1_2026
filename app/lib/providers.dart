// lib/providers.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/auth_service.dart';
import 'services/expense_service.dart';
import 'services/export_service.dart';
import 'services/profile_service.dart';
import 'services/sync_service.dart';

/// AuthService: ChangeNotifierProvider + init() async
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  final s = AuthService();
  unawaited(s.init());
  return s;
});

/// ExpenseService: ChangeNotifierProvider + init()
/// Đồng thời lắng nghe Auth để xoá/sync dữ liệu khi đổi user.
final expenseServiceProvider = ChangeNotifierProvider<ExpenseService>((ref) {
  final s = ExpenseService();
  unawaited(s.init());

  // Khi Auth thay đổi (đăng nhập/đăng xuất) -> đổi userId
  ref.listen<AuthService>(authServiceProvider, (prev, next) {
    final dynamic dyn = next; // tránh phụ thuộc kiểu chi tiết của AuthService
    final uid = dyn.currentUser?.id?.toString();
    unawaited(s.handleAuthChange(uid));
  });

  return s;
});

/// ExportService: stateless (dùng compute bên trong để export CSV mượt)
final exportServiceProvider = Provider<ExportService>((ref) => ExportService());

/// ProfileService: ChangeNotifierProvider + init()
/// Khi Auth thay đổi, gọi ensureLoaded() để cập nhật hồ sơ (nếu có API).
final profileServiceProvider = ChangeNotifierProvider<ProfileService>((ref) {
  final p = ProfileService();
  unawaited(p.init());

  ref.listen<AuthService>(authServiceProvider, (_, __) {
    unawaited(p.ensureLoaded());
  });

  return p;
});

/// SyncService: bọc hàm sync của ExpenseService (kéo dữ liệu từ server về local)
final syncServiceProvider = Provider<SyncService>((ref) {
  final exp = ref.read(expenseServiceProvider);
  return SyncService(expenses: exp);
});

/// ==== UI state (Riverpod StateProvider) ====
final searchQueryProvider = StateProvider<String>((ref) => '');

final dateRangeProvider =
StateProvider<({DateTime? from, DateTime? to})>((ref) => (from: null, to: null));

final categoryFilterProvider = StateProvider<String?>((ref) => null);
