import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../utils/constants.dart';

const _kSessionBox = 'session_box';
const _kCurrentUserKey = 'current_user';

class AuthService extends ChangeNotifier {
  Box<String>? _session;
  bool _initialized = false;

  // ===== lifecycle =====
  Future<void> init() async {
    if (_initialized) return;
    if (!Hive.isBoxOpen(_kSessionBox)) {
      _session = await Hive.openBox<String>(_kSessionBox);
    } else {
      _session = Hive.box<String>(_kSessionBox);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }

  // ===== state =====
  bool get isReady => _initialized;

  AppUser? get currentUser {
    final box = _session;
    if (box == null) return null;
    final raw = box.get(_kCurrentUserKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn => currentUser != null;

  // ===== session =====
  Future<void> logout() async {
    await _ensureInit();
    final box = _session;
    if (box == null) return;
    await box.delete(_kCurrentUserKey);
    notifyListeners();
  }

  Future<void> nukeSession() async {
    await _ensureInit();
    final box = _session;
    if (box != null) await box.clear();
    notifyListeners();
  }

  // ===== helpers =====
  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'error': 'Phản hồi không hợp lệ từ server'};
    }
  }

  String _ymd(DateTime d) => d.toIso8601String().split('T').first;

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    try {
      // chấp nhận 'YYYY-MM-DD' hoặc full ISO
      return DateTime.parse(s.length > 10 ? s : '${s}T00:00:00');
    } catch (_) {
      return null;
    }
  }

  // ===== API =====
  Future<void> register({
    required String email,
    required String password,
    required String name,
    String? gender,
    DateTime? birthday,
  }) async {
    await _ensureInit();

    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
      if (gender != null) 'gender': gender,
      if (birthday != null) 'birthday': _ymd(birthday),
    };

    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth_register.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(body),
    );

    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Đăng ký thất bại');
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _ensureInit();

    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth_login.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Sai email hoặc mật khẩu');
    }

    final u = (data['data']?['user'] ?? {}) as Map<String, dynamic>;
    final appUser = AppUser(
      id: (u['id'] ?? '').toString(),
      email: (u['email'] ?? email).toString(),
      displayName: (u['name'] ?? u['displayName'] ?? '').toString(),
      passwordHash: '', // không lưu hash ở client
      gender: u['gender'] as String?,
      birthday: _parseDate(u['birthday']),
      // chú ý: chỉ set các field có trong AppUser hiện tại.
      // nếu AppUser của bạn đã có 'role', hãy đảm bảo model có field đó.
      role: (u['role'] ?? 'user').toString(),
    );

    final box = _session;
    if (box != null) {
      await box.put(_kCurrentUserKey, jsonEncode(appUser.toJson()));
    }
    notifyListeners();
  }

  Future<void> changePassword({
    required String oldPwd,
    required String newPwd,
  }) async {
    await _ensureInit();

    final uid = currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('Chưa đăng nhập');
    }

    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth_change_password.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'user_id': uid,
        'old_password': oldPwd,
        'new_password': newPwd,
      }),
    );

    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Đổi mật khẩu thất bại');
    }
  }
}
