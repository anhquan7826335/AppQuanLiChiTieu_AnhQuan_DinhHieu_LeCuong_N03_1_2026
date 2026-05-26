import 'dart:convert';
import '../entities/BaseEntity.dart';

class EntityRepository<T extends BaseEntity> {
  final List<T> _items = [];

  EntityRepository([List<T>? initial]) {
    if (initial != null) {
      _items.addAll(initial);
    }
  }

  List<T> get items => List<T>.from(_items);

  bool create(T entity) {
    if (_items.any((item) => item.id == entity.id)) return false;
    _items.add(entity);
    return true;
  }

  List<T> readAll() => List<T>.from(_items);

  T? readById(int id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  bool deleteById(int id) {
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    return _items.length < before;
  }

  int count() => _items.length;

  void clear() => _items.clear();

  String toJsonString() {
    return jsonEncode(_items.map((item) => item.toJson()).toList());
  }

  void loadFromJson(String jsonString, T Function(Map<String, dynamic>) fromJson) {
    final data = jsonDecode(jsonString) as List<dynamic>;
    _items
      ..clear()
      ..addAll(data.map((item) => fromJson(item as Map<String, dynamic>)));
  }
}
