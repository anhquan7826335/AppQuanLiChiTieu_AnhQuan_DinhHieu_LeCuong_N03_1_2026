import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';
import '../utils/constants.dart';

const _kExpenseBox = 'expenses_box';
const _kSessionBox = 'session_box';
const _kCurrentUserKey = 'current_user';
final _uuid = const Uuid();

class ExpenseService extends ChangeNotifier {
  Box? _box;                 // cache local (expenses + budget)
  Box<String>? _session;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // ===== Coalesce notify (gộp thông báo trong 1 microtask) =====
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

    // Không gọi syncFromServer nhiều lần song song
    await syncFromServer();
  }

  // ===== Safe getters =====
  Box get _expenseBox {
    final b = _box;
    if (b == null) throw StateError('ExpenseService not initialized. Call init() first.');
    return b;
  }

  Box<String> get _sessionBox {
    final s = _session;
    if (s == null) throw StateError('ExpenseService session not initialized. Call init() first.');
    return s;
  }

  // ===== Per-user keys =====
  String _uidOrLocal() => _currentUserId() ?? 'local';
  String _expKey(String id) => 'exp:${_uidOrLocal()}:$id';
  String _budgetKey() => 'budget:${_uidOrLocal()}';

  // ===== Helpers =====
  String _absUrl(String raw) {
    if (raw.startsWith('http') || raw.startsWith('file:')) return raw;
    final base = AppConfig.baseUrl;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final pth = raw.startsWith('/') ? raw.substring(1) : raw;
    return '$b/$pth';
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'error': 'Phản hồi không hợp lệ từ server'};
    }
  }

  String? _currentUserId() {
    final raw = _sessionBox.get(_kCurrentUserKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final id = (m['id'] ?? '').toString();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  // ===== Budget (local, per-user) =====
  double get monthlyBudget {
    final raw = _expenseBox.get(_budgetKey());
    return (raw is num) ? raw.toDouble() : 0.0;
  }

  Future<void> setMonthlyBudget(double v) async {
    await _expenseBox.put(_budgetKey(), v);
    notifyListeners();

    // optional push to server
    final uid = _currentUserId();
    if (uid != null) {
      try {
        final res = await http.post(
          Uri.parse('${AppConfig.baseUrl}/settings_set.php'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'user_id': int.parse(uid), 'monthly_budget': v}),
        );
        _decode(res); // ignore error
      } catch (_) {}
    }
  }

  Future<double> getMonthlyBudget() async => monthlyBudget;

  // ===== CRUD =====
  Future<Expense> add(Expense e) async {
    final uid = _currentUserId();
    if (uid == null) {
      final id = _uuid.v4();
      final saved = e.copyWith(id: id);
      await _expenseBox.put(_expKey(id), jsonEncode(saved.toJson()));
      notifyListeners();
      return saved;
    }

    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/expenses_create.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'user_id': int.parse(uid),
        'title': e.title,
        'category': e.category,
        'amount': e.amount.round(),
        'spent_at': e.date.toIso8601String().replaceFirst('T', ' ').split('.').first,
        'note': e.note ?? '',
      }),
    );
    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Thêm chi tiêu thất bại');
    }
    final serverId = (data['data']?['id'] ?? '').toString();
    final saved = e.copyWith(id: serverId);
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

    final res = await http.put(
      Uri.parse('${AppConfig.baseUrl}/expenses_update.php'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'id': int.parse(e.id),
        'user_id': int.parse(uid),
        'title': e.title,
        'category': e.category,
        'amount': e.amount.round(),
        'spent_at': e.date.toIso8601String().replaceFirst('T', ' ').split('.').first,
        'note': e.note ?? '',
      }),
    );
    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Cập nhật thất bại');
    }
    await _expenseBox.put(_expKey(e.id), jsonEncode(e.toJson()));
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final uid = _currentUserId();
    if (uid != null) {
      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/expenses_delete.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'id': int.parse(id), 'user_id': int.parse(uid)}),
      );
      final data = _decode(res);
      if (res.statusCode != 200 || data['ok'] != true) {
        throw Exception(data['error'] ?? 'Xoá thất bại');
      }
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
    String _normalize(String? input) {
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

    final L = all();
    final nq = _normalize(q);

    return L.where((e) {
      final titleN = _normalize(e.title);
      final noteN  = _normalize(e.note ?? '');
      final catN   = _normalize(e.category);

      final inQ = nq.isEmpty || titleN.contains(nq) || noteN.contains(nq) || catN.contains(nq);
      final inCat = category == null || category.isEmpty || e.category == category;
      final inFrom = from == null || !e.date.isBefore(from);
      final inTo   = to == null   || !e.date.isAfter(to);
      return inQ && inCat && inFrom && inTo;
    }).toList();
  }

  List<Expense> search({String? q, String? query, DateTime? from, DateTime? to, String? category}) {
    return filter(q: query ?? q, from: from, to: to, category: category);
  }

  List<Expense> searchByDateRange(DateTime? from, DateTime? to) {
    return filter(from: from, to: to);
  }

  // ===== EXPORT CSV =====
  Future<String> exportCsv() async {
    final items = all();
    const header = 'id,title,category,amount,date,note';

    String esc(String? s) {
      final v = (s ?? '').replaceAll('"', '""');
      return '"$v"';
    }

    final lines = <String>[header, ...items.map((e) {
      return [
        esc(e.id),
        esc(e.title),
        esc(e.category),
        e.amount.toStringAsFixed(0),
        esc(e.date.toIso8601String()),
        esc(e.note),
      ].join(',');
    })];

    final csv = lines.join('\n');

    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();

    final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '').replaceAll('-', '');
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

  Future<void> syncFromServer() async {
    final uid = _currentUserId();
    if (uid == null) return;
    if (_isSyncing) return; // chặn chồng

    _isSyncing = true;
    notifyListeners();

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/expenses_list.php')
          .replace(queryParameters: {'user_id': uid});
      final res = await http.get(uri);
      final data = _decode(res);
      if (res.statusCode != 200 || data['ok'] != true) {
        return;
      }

      final items = (data['data']?['items'] as List? ?? []).cast<Map<String, dynamic>>();

      // clear cache hiện tại của user này
      final prefix = 'exp:$uid:';
      final keys = _expenseBox.keys.where((k) => (k is String) && k.startsWith(prefix)).toList();
      for (final k in keys) {
        await _expenseBox.delete(k);
      }

      for (final m in items) {
        final e = Expense(
          id: (m['id'] ?? '').toString(),
          title: (m['title'] ?? m['note'] ?? '').toString(),
          category: (m['category'] ?? 'Khác').toString(),
          amount: (m['amount'] is num)
              ? (m['amount'] as num).toDouble()
              : (double.tryParse('${m['amount']}') ?? 0),
          note: (m['note'] ?? '').toString(),
          date: DateTime.tryParse((m['spent_at'] ?? m['date'] ?? '') as String) ?? DateTime.now(),
        );
        await _expenseBox.put(_expKey(e.id), jsonEncode(e.toJson()));
      }

      // budget
      try {
        final s = await http.get(Uri.parse('${AppConfig.baseUrl}/settings_get.php?user_id=$uid'));
        final j = _decode(s);
        if (j['ok'] == true) {
          final data = (j['data'] ?? {}) as Map<String, dynamic>;
          final b = (data['monthly_budget'] ?? data['budget'] ?? 0).toString();
          final v = double.tryParse(b);
          if (v != null) await _expenseBox.put(_budgetKey(), v);
        }
      } catch (_) {}
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ===== Attachments =====
  Future<List<String>> uploadAttachments({
    required String expenseId,
    required List<XFile> files,
  }) async {
    final uid = _currentUserId();
    if (uid == null || expenseId.isEmpty || files.isEmpty) return const [];

    final urls = <String>[];
    for (final f in files) {
      final uri = Uri.parse('${AppConfig.baseUrl}/attachments_upload.php');
      final req = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = uid
        ..fields['expense_id'] = expenseId
        ..files.add(await http.MultipartFile.fromPath('file', f.path));
      final res = await req.send();
      final body = await res.stream.bytesToString();

      try {
        final j = jsonDecode(body) as Map<String, dynamic>;
        if (res.statusCode == 200 && j['ok'] == true) {
          final rel = (j['data']?['url'] ?? j['data']?['file_path'] ?? '').toString();
          if (rel.isNotEmpty) urls.add(_absUrl(rel));
        }
      } catch (_) {}
    }
    return urls;
  }

  Future<List<String>> fetchAttachments(String expenseId) async {
    if (expenseId.isEmpty) return const [];
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/attachments_list.php')
          .replace(queryParameters: {'expense_id': expenseId});
      final res = await http.get(uri);
      final j = _decode(res);
      if (res.statusCode != 200 || j['ok'] != true) return const [];

      final items = (j['data']?['items'] as List? ?? []);
      final urls = <String>[];
      for (final it in items) {
        final m = it as Map<String, dynamic>;
        final raw = (m['url'] ?? m['file_path'] ?? '').toString();
        if (raw.isNotEmpty) urls.add(_absUrl(raw));
      }
      return urls;
    } catch (_) {
      return const [];
    }
  }
}
