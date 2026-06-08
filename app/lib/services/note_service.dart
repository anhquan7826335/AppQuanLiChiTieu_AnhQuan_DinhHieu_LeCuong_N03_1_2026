import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _kNotesBox = 'notes_box';
const _kSessionBox = 'session_box';
const _kCurrentUserKey = 'current_user';

class NoteService extends ChangeNotifier {
  Box? _box;
  Box<String>? _session;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox(_kNotesBox);
    _session = Hive.isBoxOpen(_kSessionBox)
        ? Hive.box<String>(_kSessionBox)
        : await Hive.openBox<String>(_kSessionBox);
    _initialized = true;
    notifyListeners();
  }

  Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }

  Box get _notesBox {
    final b = _box;
    if (b == null) throw StateError('NoteService not initialized. Call init() first.');
    return b;
  }

  Box<String> get _sessionBox {
    final s = _session;
    if (s == null) throw StateError('NoteService not initialized. Call init() first.');
    return s;
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

  String _uidOrLocal() => _currentUserId() ?? 'local';

  String _noteKey(String id) => 'note:${_uidOrLocal()}:$id';

  Future<void> saveNote(String id, Map<String, dynamic> note) async {
    await _ensureInit();
    await _notesBox.put(_noteKey(id), note);
    notifyListeners();
  }

  Map<String, dynamic>? getNote(String id) {
    final raw = _notesBox.get(_noteKey(id));
    if (raw is Map) {
      return Map<String, dynamic>.from(raw.cast<String, dynamic>());
    }
    return null;
  }

  List<Map<String, dynamic>> get allNotes {
    return _notesBox.keys
        .whereType<String>()
        .where((key) => key.startsWith('note:${_uidOrLocal()}:'))
        .map((key) {
          final raw = _notesBox.get(key);
          if (raw is Map) {
            return Map<String, dynamic>.from(raw.cast<String, dynamic>());
          }
          return <String, dynamic>{};
        })
        .where((note) => note.isNotEmpty)
        .toList();
  }

  Future<void> deleteNote(String id) async {
    await _ensureInit();
    await _notesBox.delete(_noteKey(id));
    notifyListeners();
  }

  Future<void> clearNotes() async {
    await _ensureInit();
    final prefix = 'note:${_uidOrLocal()}:';
    final keys = _notesBox.keys.whereType<String>().where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      await _notesBox.delete(key);
    }
    notifyListeners();
  }
}
