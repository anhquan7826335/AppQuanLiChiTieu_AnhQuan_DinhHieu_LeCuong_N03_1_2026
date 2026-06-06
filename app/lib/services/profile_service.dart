import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

const _kProfileBox = 'profile_box';
const _kSessionBox = 'session_box';
const _kCurrentUserKey = 'current_user';

// các FIELD (sẽ được ghép thêm :<userId>)
const _fAvatarPath    = 'avatar_path';
const _fAvatarUrl     = 'avatar_url';
const _fDisplayName   = 'display_name';
const _fMonthlyIncome = 'monthly_income';
const _fBirthDate     = 'birth_date';
const _fGender        = 'gender';

class ProfileService extends ChangeNotifier {
  late final Box _box;
  late final Box<String> _session;
  bool _inited = false;
  bool _loading = false;
  bool _avatarBusy = false;

  // ===== Gộp notify để tránh spam rebuild =====
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
    if (_inited) return;
    _box = await Hive.openBox(_kProfileBox);
    _session = Hive.isBoxOpen(_kSessionBox)
        ? Hive.box<String>(_kSessionBox)
        : await Hive.openBox<String>(_kSessionBox);
    _inited = true;
    notifyListeners();
  }

  String? _uid() {
    final raw = _session.get(_kCurrentUserKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final id = (m['id'] ?? '').toString();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  String _k(String field) => '$field:${_uid() ?? 'local'}';

  // Chỉ put + notify khi thay đổi
  Future<void> _putIfChanged(String fieldKey, dynamic value) async {
    final k = _k(fieldKey);
    final old = _box.get(k);
    if (old == value) return;
    await _box.put(k, value);
    notifyListeners();
  }

  // Chuẩn hoá giới tính
  String _normalizeGenderIn(String? raw) {
    if (raw == null) return '';
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    if (s == 'nam' || s == 'male' || s == 'm' || s == '1' || s == 'true') return 'Nam';
    if (s == 'nữ' || s == 'nu' || s == 'female' || s == 'f' || s == '0' || s == 'false') return 'Nữ';
    return raw.trim();
  }

  // Parse birthday linh hoạt
  DateTime? _parseBirthdayFlexible(dynamic val) {
    if (val == null) return null;

    if (val is int) {
      final isMs = val > 100000000000;
      return DateTime.fromMillisecondsSinceEpoch(isMs ? val : val * 1000);
    }
    if (val is double) {
      final v = val.toInt();
      final isMs = v > 100000000000;
      return DateTime.fromMillisecondsSinceEpoch(isMs ? v : v * 1000);
    }

    final s = val.toString().trim();
    if (s.isEmpty || s == 'null' || s == '-') return null;

    final iso = DateTime.tryParse(s.length > 10 ? s : '${s}T00:00:00');
    if (iso != null) return iso;

    final re = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
    final m = re.firstMatch(s);
    if (m != null) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final y = int.tryParse(m.group(3)!);
      if (d != null && mo != null && y != null) {
        return DateTime(y, mo, d);
      }
    }
    return null;
  }

  void _putBirthGenderFromMap(Map<String, dynamic> m) {
    final bday = m['birthday'] ?? m['birth_date'] ?? m['date_of_birth'] ?? m['dob'] ?? m['ngay_sinh'] ?? m['ngaysinh'];
    final bd = _parseBirthdayFlexible(bday);
    if (bd != null) {
      _box.put(_k(_fBirthDate), bd);
      notifyListeners();
    }

    final g = m['gender'] ?? m['sex'] ?? m['gioi_tinh'] ?? m['gioitinh'] ?? m['gioiTinh'];
    final normG = _normalizeGenderIn(g?.toString());
    if (normG.isNotEmpty) {
      _box.put(_k(_fGender), normG);
      notifyListeners();
    }
  }

  /// Kéo hồ sơ (có guard để không chạy chồng, tránh đứng UI)
  Future<void> ensureLoaded() async {
    if (!_inited) await init();
    if (_loading) return;
    final uid = _uid();
    if (uid == null) return;

    _loading = true;
    try {
      // user_get.php
      final u = await http.get(Uri.parse('${AppConfig.baseUrl}/user_get.php?user_id=$uid'));
      final j1 = _decodeRes(u);

      if (j1['ok'] == true) {
        Map<String, dynamic> userMap = const {};
        final dataNode = j1['data'];
        if (dataNode is Map && dataNode['user'] is Map) {
          userMap = Map<String, dynamic>.from(dataNode['user'] as Map);
        } else if (j1['user'] is Map) {
          userMap = Map<String, dynamic>.from(j1['user'] as Map);
        }

        if (userMap.isNotEmpty) {
          final nameSrv   = (userMap['name'] ?? userMap['displayName'] ?? userMap['display_name'] ?? '').toString();
          final avatarSrv = (userMap['avatar_url'] ?? userMap['avatar'] ?? '').toString();
          if (nameSrv.isNotEmpty)   await _putIfChanged(_fDisplayName, nameSrv);
          if (avatarSrv.isNotEmpty) await _putIfChanged(_fAvatarUrl, avatarSrv);

          _putBirthGenderFromMap(userMap);
        }
      }

      // settings_get.php
      final s = await http.get(Uri.parse('${AppConfig.baseUrl}/settings_get.php?user_id=$uid'));
      final j2 = _decodeRes(s);
      if (j2['ok'] == true) {
        Map<String, dynamic> settingsMap = const {};
        final data2 = j2['data'];
        if (data2 is Map) {
          settingsMap = data2['settings'] is Map
              ? Map<String, dynamic>.from(data2['settings'] as Map)
              : Map<String, dynamic>.from(data2);
        }
        if (settingsMap.isNotEmpty) {
          final incStr = (settingsMap['monthly_income'] ?? settingsMap['income'] ?? 0).toString();
          final v = double.tryParse(incStr);
          if (v != null) await _putIfChanged(_fMonthlyIncome, v);
          _putBirthGenderFromMap(settingsMap);
        }
      }
    } catch (_) {
      // offline: giữ local
    } finally {
      _loading = false;
    }
  }

  String _resolveServerPath(String raw) {
    if (raw.startsWith('http') || raw.startsWith('file:')) return raw;
    final base = AppConfig.baseUrl;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = raw.startsWith('/') ? raw.substring(1) : raw;
    return '$b/$p';
  }

  // ===== Getters / Setters =====
  String? get name {
    final v = _box.get(_k(_fDisplayName)) as String?;
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  set name(String? v) {
    if (v == null || v.trim().isEmpty) {
      _box.delete(_k(_fDisplayName));
      notifyListeners();
    } else {
      _putIfChanged(_fDisplayName, v.trim());
    }
  }

  double get monthlyIncome {
    final raw = _box.get(_k(_fMonthlyIncome));
    return (raw is num) ? raw.toDouble() : 0.0;
  }

  set monthlyIncome(double v) {
    _putIfChanged(_fMonthlyIncome, v);
  }

  String? get avatarUrl {
    final url = _box.get(_k(_fAvatarUrl)) as String?;
    if (url != null && url.trim().isNotEmpty) return url.trim();
    final path = _box.get(_k(_fAvatarPath)) as String?;
    if (path != null && path.trim().isNotEmpty) return 'file://$path';
    return null;
  }

  String? get avatarDisplayUrl {
    final raw = avatarUrl;
    if (raw == null) return null;
    if (raw.startsWith('file://')) return raw;
    return _resolveServerPath(raw);
  }

  Future<void> updateAvatar(String avatarRelativeOrAbsolute) async {
    final v = avatarRelativeOrAbsolute.trim();
    if (v.isEmpty) return;
    await _putIfChanged(_fAvatarUrl, v);
  }

  /// ===== FIXED: không dùng biến ngoài phạm vi trong catch =====
  Future<void> pickAndUploadAvatar() async {
    if (_avatarBusy) return;
    _avatarBusy = true;

    XFile? pickedFile;

    try {
      final picker = ImagePicker();
      pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile == null) return;

      final uid = _uid();
      if (uid == null) {
        await _saveAvatarLocal(pickedFile.path);
        return;
      }

      Future<String?> _tryUpload(String field) async {
        final uri = Uri.parse('${AppConfig.baseUrl}/user_update_avatar.php');
        final req = http.MultipartRequest('POST', uri)
          ..fields['user_id'] = uid
          ..files.add(await http.MultipartFile.fromPath(field, pickedFile!.path));
        final res = await req.send();
        final body = await res.stream.bytesToString();
        if (res.statusCode != 200) return null;
        try {
          final j = jsonDecode(body);
          if (j['ok'] == true) {
            final rel = (j['data']?['avatar'] ?? j['data']?['avatar_url'])?.toString();
            return (rel != null && rel.isNotEmpty) ? rel : null;
          }
        } catch (_) {}
        return null;
      }

      String? saved = await _tryUpload('avatar');
      saved ??= await _tryUpload('file');

      if (saved != null) {
        await _putIfChanged(_fAvatarUrl, saved);
        return;
      }

      // upload thất bại → lưu local
      await _saveAvatarLocal(pickedFile.path);
    } catch (_) {
      // fallback local nếu có ảnh
      if (pickedFile != null) {
        await _saveAvatarLocal(pickedFile.path);
      }
    } finally {
      _avatarBusy = false;
    }
  }

  Future<void> _saveAvatarLocal(String sourcePath) async {
    if (sourcePath.isEmpty) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final dest = File('${appDir.path}/$fileName');
      await File(sourcePath).copy(dest.path);
      await _putIfChanged(_fAvatarPath, dest.path);
    } catch (_) {}
  }

  Future<void> removeAvatar() async {
    final path = _box.get(_k(_fAvatarPath)) as String?;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
    await _box.delete(_k(_fAvatarPath));
    await _box.delete(_k(_fAvatarUrl));
    notifyListeners();
  }

  DateTime? get birthDate {
    final v = _box.get(_k(_fBirthDate));
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  set birthDate(DateTime? v) {
    if (v == null) {
      _box.delete(_k(_fBirthDate));
      notifyListeners();
    } else {
      _putIfChanged(_fBirthDate, v);
    }
  }

  String? get gender {
    final g = _box.get(_k(_fGender)) as String?;
    if (g == null) return null;
    final t = g.trim();
    return t.isEmpty ? null : t;
  }

  set gender(String? v) {
    if (v == null || v.trim().isEmpty) {
      _box.delete(_k(_fGender));
      notifyListeners();
    } else {
      _putIfChanged(_fGender, v.trim());
    }
  }

  Future<void> setProfile({
    String? name,
    double? monthlyIncome,
    DateTime? birthday,
    String? gender,
    String? avatarPath,
    String? avatarUrl,
  }) async {
    if (name != null) await _putIfChanged(_fDisplayName, name);
    if (monthlyIncome != null) await _putIfChanged(_fMonthlyIncome, monthlyIncome);
    if (birthday != null) await _putIfChanged(_fBirthDate, birthday);
    if (gender != null) await _putIfChanged(_fGender, gender);
    if (avatarPath != null) await _putIfChanged(_fAvatarPath, avatarPath);
    if (avatarUrl != null) await _putIfChanged(_fAvatarUrl, avatarUrl);
  }

  Future<void> updateGenderAndBirthday({String? gender, DateTime? birthday}) async {
    if (gender != null) await _putIfChanged(_fGender, gender);
    if (birthday != null) await _putIfChanged(_fBirthDate, birthday);

    try {
      final uid = _uid();
      if (uid == null || uid.isEmpty) return;

      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/user_update_profile.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'user_id': uid,
          if (gender != null) 'gender': gender,
          if (birthday != null) 'birthday': birthday.toIso8601String().substring(0, 10),
        }),
      );

      final j = _decodeRes(res);
      if (res.statusCode != 200 || j['ok'] != true) {
        throw (j['error'] ?? 'Cập nhật hồ sơ thất bại');
      }

      final d = j['data'];
      if (d is Map<String, dynamic>) {
        final srvGender = d['gender'] as String?;
        final srvBirthday = d['birthday']?.toString();
        if (srvGender != null) await _putIfChanged(_fGender, srvGender);
        if (srvBirthday != null) {
          final bd = DateTime.tryParse(
              srvBirthday.length > 10 ? srvBirthday : '${srvBirthday}T00:00:00');
          if (bd != null) await _putIfChanged(_fBirthDate, bd);
        }
      }
    } catch (_) {
      // giữ local
    }
  }

  Map<String, dynamic> _decodeRes(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false};
    }
  }
}
