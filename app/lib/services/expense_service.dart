// lib/services/expense_service.dart
// ✅ Thay thế toàn bộ HTTP calls sang Firebase Firestore
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';

const _kExpenseBox = 'expenses_box';
const _kSessionBox = 'session_box';
const _kCurrentUserKey = 'current_user';
final _uuid = const Uuid();

class ExpenseService extends ChangeNotifier {
  Box? _box;
  Box<String>? _session;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===== Coalesce notify =====
  bool _scheduledNotify = false;
  @override
  void notifyListeners() {
    if (_scheduledNotify) return;
    _scheduledNotify = true;
    Future.microtask(() {
      _scheduledNotify = false;
      super.notifyListeners();
    });
  }

  Future<void> init() async {
    if (!Hive.isBoxOpen(_kExpenseBox)) {
      _box = await Hive.openBox(_kExpenseBox);
    } else {
      _box = Hive.box(_kExpenseBox);
    }

    if (!Hive.isBoxOpen(_kSessionBox)) {
      _session = await Hive.openBox<String>(_kSessionBox);
    } else {
      _session = Hive.box<String>(_kSessionBox);
    }

    await syncFromServer();
  }

  // ===== Safe getters =====
  Box get _expenseBox {
    final b = _box;
    if (b == null) throw StateError('ExpenseService not initialized.');
    return b;
  }

  // ===== Per-user helpers =====
  String? _currentUserId() => _auth.currentUser?.uid;
  String _uidOrLocal() => _currentUserId() ?? 'local';
  String _expKey(String id) => 'exp:${_uidOrLocal()}:$id';
  String _budgetKey() => 'budget:${_uidOrLocal()}';

  CollectionReference<Map<String, dynamic>> _expenseCollection(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses');
  }

  // ===== Budget (local, per-user) =====
  double get monthlyBudget {
    final raw = _expenseBox.get(_budgetKey());
    return (raw is num) ? raw.toDouble() : 0.0;
  }

  Future<void> setMonthlyBudget(double v) async {
    await _expenseBox.put(_budgetKey(), v);

    // ✅ Lưu budget lên Firestore
    final uid = _currentUserId();
    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).set(
          {'monthly_budget': v},
          SetOptions(merge: true),
        );
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<double> getMonthlyBudget() async => monthlyBudget;

  // ===== CRUD =====

  Future<Expense> add(Expense e) async {
    final uid = _currentUserId();

    // Offline / chưa đăng nhập → lưu local
    if (uid == null) {
      final id = _uuid.v4();
      final saved = e.copyWith(id: id);
      await _expenseBox.put(_expKey(id), jsonEncode(saved.toJson()));
      notifyListeners();
      return saved;
    }

    // ✅ Lưu lên Firestore
    final ref = await _expenseCollection(uid).add({
      'title': e.title,
      'category': e.category,
      'amount': e.amount,
      'date': Timestamp.fromDate(e.date),
      'note': e.note ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final saved = e.copyWith(id: ref.id);
    await _expenseBox.put(_expKey(saved.id), jsonEncode(saved.toJson()));
    notifyListeners();
    return saved;
  }

  Future<void> update(Expense e) async {
    final uid = _currentUserId();
    if (uid == null || e.id.isEmpty) {
      await _expenseBox.put(_expKey(e.id), jsonEncode(e.toJson()));
      notifyListeners();
      return;
    }

    // ✅ Cập nhật Firestore
    await _expenseCollection(uid).doc(e.id).update({
      'title': e.title,
      'category': e.category,
      'amount': e.amount,
      'date': Timestamp.fromDate(e.date),
      'note': e.note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _expenseBox.put(_expKey(e.id), jsonEncode(e.toJson()));
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final uid = _currentUserId();
    if (uid != null) {
      // ✅ Xoá trên Firestore
      await _expenseCollection(uid).doc(id).delete();
    }
    await _expenseBox.delete(_expKey(id));
    notifyListeners();
  }

  List<Expense> all() {
    final prefix = 'exp:${_uidOrLocal()}:';
    return _expenseBox.keys
        .where((k) => (k is String) && k.startsWith(prefix))
        .map((k) {
          final raw = _expenseBox.get(k);
          if (raw is String) {
            return Expense.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          }
          return null;
        })
        .whereType<Expense>()
        .sortedBy((e) => e.date)
        .reversed
        .toList();
  }

  List<Expense> filter({
    String? q,
    DateTime? from,
    DateTime? to,
    String? category,
  }) {
    String normalize(String? input) {
      if (input == null) return '';
      var s = input.toLowerCase();
      final reps = <String, String>{
        'a': r'[àáạảãâầấậẩẫăằắặẳẵ]',
        'e': r'[èéẹẻẽêềếệểễ]',
        'i': r'[ìíịỉĩ]',
        'o': r'[òóọỏõôồốộổỗơờớợởỡ]',
        'u': r'[ùúụủũưừứựửữ]',
        'y': r'[ỳýỵỷỹ]',
        'd': r'[đ]',
      };
      for (final kv in reps.entries) {
        s = s.replaceAll(RegExp(kv.value), kv.key);
      }
      return s;
    }

    final list = all();
    final nq = normalize(q);

    return list.where((e) {
      final titleN = normalize(e.title);
      final noteN = normalize(e.note ?? '');
      final catN = normalize(e.category);

      final inQ = nq.isEmpty || titleN.contains(nq) || noteN.contains(nq) || catN.contains(nq);
      final inCat = category == null || category.isEmpty || e.category == category;
      final inFrom = from == null || !e.date.isBefore(from);
      final inTo = to == null || !e.date.isAfter(to);
      return inQ && inCat && inFrom && inTo;
    }).toList();
  }

  List<Expense> search({String? q, String? query, DateTime? from, DateTime? to, String? category}) {
    return filter(q: query ?? q, from: from, to: to, category: category);
  }

  List<Expense> searchByDateRange(DateTime? from, DateTime? to) {
    return filter(from: from, to: to);
  }

  // ===== Export CSV =====
  Future<String> exportCsv() async {
    final items = all();
    const header = 'id,title,category,amount,date,note';

    String esc(String? s) {
      final v = (s ?? '').replaceAll('"', '""');
      return '"$v"';
    }

    final lines = <String>[
      header,
      ...items.map((e) => [
            esc(e.id),
            esc(e.title),
            esc(e.category),
            e.amount.toStringAsFixed(0),
            esc(e.date.toIso8601String()),
            esc(e.note),
          ].join(','))
    ];

    final csv = lines.join('\n');

    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('-', '');
    final file = File(p.join(dir.path, 'expenses_$ts.csv'));
    await file.writeAsString(csv, encoding: utf8);
    return file.path;
  }

  // ===== User switching =====
  Future<void> clearLocalCache() async {
    final prefix = 'exp:${_uidOrLocal()}:';
    final keys = _expenseBox.keys
        .where((k) => (k is String) && (k.startsWith(prefix) || k == _budgetKey()))
        .toList();
    for (final k in keys) {
      await _expenseBox.delete(k);
    }
    notifyListeners();
  }

  Future<void> handleAuthChange(String? userId) async {
    await clearLocalCache();
    if (userId != null && userId.isNotEmpty) {
      await syncFromServer();
    }
    notifyListeners();
  }

  /// ✅ Sync từ Firestore về Hive (offline cache)
  Future<void> syncFromServer() async {
    final uid = _currentUserId();
    if (uid == null) return;
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      // Lấy danh sách expenses từ Firestore
      final snapshot = await _expenseCollection(uid)
          .orderBy('date', descending: true)
          .limit(200)
          .get();

      // Xoá cache cũ
      final prefix = 'exp:$uid:';
      final keys = _expenseBox.keys
          .where((k) => (k is String) && k.startsWith(prefix))
          .toList();
      for (final k in keys) {
        await _expenseBox.delete(k);
      }

      // Lưu cache mới từ Firestore
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['date'] is Timestamp)
            ? (data['date'] as Timestamp).toDate()
            : DateTime.tryParse('${data['date']}') ?? DateTime.now();

        final e = Expense(
          id: doc.id,
          title: (data['title'] ?? '').toString(),
          category: (data['category'] ?? 'Khác').toString(),
          amount: (data['amount'] is num)
              ? (data['amount'] as num).toDouble()
              : (double.tryParse('${data['amount']}') ?? 0),
          note: (data['note'] ?? '').toString(),
          date: date,
        );
        await _expenseBox.put(_expKey(e.id), jsonEncode(e.toJson()));
      }

      // Lấy budget từ Firestore
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final budget = userDoc.data()?['monthly_budget'];
          if (budget != null) {
            await _expenseBox.put(_budgetKey(), (budget as num).toDouble());
          }
        }
      } catch (_) {}
    } catch (e) {
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ===== Attachments (giữ lại, cần Firebase Storage nếu muốn dùng) =====
  Future<List<String>> uploadAttachments({
    required String expenseId,
    required List<XFile> files,
  }) async {
    // TODO: Implement với Firebase Storage nếu cần
    // import 'package:firebase_storage/firebase_storage.dart';
    print('⚠️ uploadAttachments: chưa implement Firebase Storage');
    return const [];
  }

  Future<List<String>> fetchAttachments(String expenseId) async {
    // TODO: Implement với Firebase Storage nếu cần
    return const [];
  }
}