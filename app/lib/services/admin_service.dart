import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/constants.dart';
import 'auth_service.dart';
import '../providers.dart';

/// Provider cho AdminService
final adminServiceProvider = Provider<AdminService>((ref) {
  final auth = ref.watch(authServiceProvider);
  return AdminService(auth);
});

class AdminService {
  final AuthService _auth;
  AdminService(this._auth);

  String? get _adminId => _auth.currentUser?.id;

  /// Tạo URL: luôn đính kèm admin_id trên query
  Uri _u(String path, [Map<String, String>? qp]) {
    final base = '${AppConfig.baseUrl}/$path';
    final map = <String, String>{};
    if (qp != null) map.addAll(qp);
    final adminId = _adminId;
    if (adminId != null && adminId.isNotEmpty) {
      map['admin_id'] = adminId;
    }
    return Uri.parse(base).replace(queryParameters: map.isEmpty ? null : map);
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'error': 'Phản hồi không hợp lệ'};
    }
  }

  // ---------------- USERS ----------------

  Future<Map<String, dynamic>> listUsers({
    String q = '',
    int page = 1,
    int limit = 20,
  }) async {
    final r = await http.get(_u('admin_users_list.php', {
      if (q.trim().isNotEmpty) 'q': q.trim(),
      'page': '$page',
      'limit': '$limit',
    }));
    return _decode(r);
  }

  /// Đổi nhanh role / is_active
  Future<bool> updateUser({
    required String userId,
    String? role,      // 'user' | 'admin'
    bool? isActive,    // true/false
  }) async {
    final adminId = _adminId ?? '';
    final r = await http.post(
      _u('admin_user_update.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'admin_id': adminId,
        'target_user_id': userId,
        'user_id': userId,
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive ? 1 : 0,
      }),
    );
    final j = _decode(r);
    if (kDebugMode) debugPrint('updateUser(${r.statusCode}) -> $j');
    return j['ok'] == true;
  }

  /// Cập nhật chi tiết: tên, email, birthday(YYYY-MM-DD), gender(male|female|other)
  Future<bool> updateUserProfile({
    required String userId,
    String? name,
    String? email,
    String? role,         // optional
    bool? isActive,       // optional
    DateTime? birthday,   // YYYY-MM-DD
    String? gender,       // male | female | other
  }) async {
    String? ymd(DateTime? d) => d == null ? null : d.toIso8601String().split('T').first;

    final adminId = _adminId ?? '';
    final r = await http.post(
      _u('admin_user_update.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'admin_id': adminId,
        'target_user_id': userId,
        'user_id': userId,
        if (name != null)      'name': name,
        if (email != null)     'email': email,
        if (role != null)      'role': role,
        if (isActive != null)  'is_active': isActive ? 1 : 0,
        if (birthday != null)  'birthday': ymd(birthday),
        if (gender != null)    'gender': gender,
      }),
    );
    final j = _decode(r);
    if (kDebugMode) debugPrint('updateUserProfile(${r.statusCode}) -> $j');
    return j['ok'] == true;
  }

  Future<bool> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    final adminId = _adminId ?? '';
    final r = await http.post(
      _u('admin_user_reset_password.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'admin_id': adminId,
        'target_user_id': userId,
        'user_id': userId,
        'temp_password': newPassword,
      }),
    );
    final j = _decode(r);
    if (kDebugMode) debugPrint('resetPassword(${r.statusCode}) -> $j');
    return j['ok'] == true;
  }

  /// Xoá cứng user
  Future<bool> deleteUser({required String userId}) async {
    final adminId = _adminId ?? '';
    final r = await http.post(
      _u('admin_user_delete.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'admin_id': adminId,
        'target_user_id': userId,
        'user_id': userId,
        'hard': 1,
      }),
    );
    final j = _decode(r);
    if (kDebugMode) debugPrint('deleteUser(${r.statusCode}) -> $j');
    return j['ok'] == true;
  }

  // ---------------- EXPENSES ----------------

  Future<Map<String, dynamic>> listExpenses({
    String? userQ,
    DateTime? from,
    DateTime? to,
  }) async {
    String ymd(DateTime d) => d.toIso8601String().split('T').first;

    final r = await http.get(
      _u('admin_expenses_list.php', {
        if (userQ != null && userQ.trim().isNotEmpty) 'user_q': userQ.trim(),
        if (from != null) 'from': ymd(from),
        if (to != null) 'to': ymd(to),
      }),
    );
    return _decode(r);
  }
}
