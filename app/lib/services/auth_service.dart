// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user.dart';

const _kSessionBox = 'session_box';
const _kCurrentUserKey = 'current_user';

class AuthService extends ChangeNotifier {
  Box<String>? _session;
  bool _initialized = false;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // ===== lifecycle =====
  Future<void> init() async {
    if (_initialized) return;
    if (!Hive.isBoxOpen(_kSessionBox)) {
      _session = await Hive.openBox<String>(_kSessionBox);
    } else {
      _session = Hive.box<String>(_kSessionBox);
    }

    // ✅ Nếu Firebase đã có session (user đã đăng nhập trước đó),
    //    tự động cập nhật Hive cache.
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      await _saveFirebaseUserToHive(firebaseUser);
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

  // ===== helpers =====
  Future<void> _saveFirebaseUserToHive(User firebaseUser) async {
    final appUser = AppUser(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      passwordHash: '', // không lưu hash ở client
      role: 'user',
    );
    final box = _session;
    if (box != null) {
      await box.put(_kCurrentUserKey, jsonEncode(appUser.toJson()));
    }
  }

  // ===== API =====

  /// ✅ Đăng ký bằng Firebase Auth
  Future<void> register({
    required String email,
    required String password,
    required String name,
    String? gender,
    DateTime? birthday,
  }) async {
    await _ensureInit();

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Cập nhật displayName
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();

      final updatedUser = _firebaseAuth.currentUser;
      if (updatedUser != null) {
        await _saveFirebaseUserToHive(updatedUser);
      }

      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  /// ✅ Đăng nhập bằng Firebase Auth
  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _ensureInit();

    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        await _saveFirebaseUserToHive(firebaseUser);
      }

      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  /// ✅ Đổi mật khẩu
  Future<void> changePassword({
    required String oldPwd,
    required String newPwd,
  }) async {
    await _ensureInit();

    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) throw Exception('Chưa đăng nhập');

    try {
      // Re-authenticate trước khi đổi mật khẩu
      final credential = EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: oldPwd,
      );
      await firebaseUser.reauthenticateWithCredential(credential);
      await firebaseUser.updatePassword(newPwd);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  // ===== session =====
  Future<void> logout() async {
    await _ensureInit();
    await _firebaseAuth.signOut(); // ✅ sign out Firebase
    final box = _session;
    if (box != null) {
      await box.delete(_kCurrentUserKey);
    }
    notifyListeners();
  }

  Future<void> nukeSession() async {
    await _ensureInit();
    await _firebaseAuth.signOut();
    final box = _session;
    if (box != null) await box.clear();
    notifyListeners();
  }

  // ===== Error mapping =====
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email này đã được sử dụng';
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản';
      case 'wrong-password':
        return 'Sai mật khẩu';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng thử lại sau';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng';
      default:
        return e.message ?? 'Đã xảy ra lỗi';
    }
  }
}