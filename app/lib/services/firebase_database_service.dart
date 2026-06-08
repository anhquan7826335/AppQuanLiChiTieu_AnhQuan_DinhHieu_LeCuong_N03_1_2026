// lib/services/firebase_database_service.dart
// ✅ Thay thế appwrite_database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Collection paths trong Firestore
class Collections {
  static const String users = 'users';
  static const String expenses = 'expenses';
  static const String categories = 'categories';
  static const String notes = 'notes';
}

class FirebaseDatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============= USERS =============

  /// Tạo hoặc cập nhật thông tin user (dùng merge để không ghi đè)
  Future<void> setUser({
    required String userId,
    required String name,
    required String email,
    String? avatar,
    String currency = 'VND',
  }) async {
    await _db.collection(Collections.users).doc(userId).set({
      'name': name,
      'email': email,
      'avatar': avatar ?? '',
      'currency': currency,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    print('✅ User set: $userId');
  }

  /// Lấy thông tin user
  Future<Map<String, dynamic>?> getUser(String userId) async {
    final doc = await _db.collection(Collections.users).doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  // ============= EXPENSES =============

  /// Thêm chi tiêu mới — trả về docId
  Future<String> addExpense({
    required String userId,
    required double amount,
    required String category,
    required DateTime date,
    String? description,
    String? notes,
  }) async {
    final ref = await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.expenses)
        .add({
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'description': description ?? '',
      'notes': notes ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('✅ Expense added: ${ref.id}');
    return ref.id;
  }

  /// Cập nhật chi tiêu
  Future<void> updateExpense({
    required String userId,
    required String expenseId,
    double? amount,
    String? category,
    DateTime? date,
    String? description,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (amount != null) data['amount'] = amount;
    if (category != null) data['category'] = category;
    if (date != null) data['date'] = Timestamp.fromDate(date);
    if (description != null) data['description'] = description;
    if (notes != null) data['notes'] = notes;

    await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.expenses)
        .doc(expenseId)
        .update(data);
    print('✅ Expense updated: $expenseId');
  }

  /// Xoá chi tiêu
  Future<void> deleteExpense({
    required String userId,
    required String expenseId,
  }) async {
    await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.expenses)
        .doc(expenseId)
        .delete();
    print('✅ Expense deleted: $expenseId');
  }

  /// Lấy tất cả chi tiêu (realtime stream)
  Stream<QuerySnapshot> getExpensesStream(String userId) {
    return _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.expenses)
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// Lấy tất cả chi tiêu (one-time fetch)
  Future<List<Map<String, dynamic>>> getExpenses({
    required String userId,
    int limit = 100,
  }) async {
    final snapshot = await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.expenses)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Lấy chi tiêu theo khoảng ngày
  Future<List<Map<String, dynamic>>> getExpensesByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    final snapshot = await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.expenses)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Lấy chi tiêu theo category
  Future<List<Map<String, dynamic>>> getExpensesByCategory({
    required String userId,
    required String category,
    int limit = 100,
  }) async {
    final snapshot = await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.expenses)
        .where('category', isEqualTo: category)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Tổng chi tiêu theo tháng
  Future<double> getTotalExpensesByMonth({
    required String userId,
    required int month,
    required int year,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

    final items = await getExpensesByDateRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      limit: 1000,
    );

    return items.fold<double>(0.0, (double sum, doc) {
      final amount = (doc['amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });
  }

  // ============= CATEGORIES =============

  /// Thêm / update category
  Future<void> setCategory({
    required String categoryId,
    required String name,
    String? icon,
    String? color,
  }) async {
    await _db.collection(Collections.categories).doc(categoryId).set({
      'name': name,
      'icon': icon ?? '📁',
      'color': color ?? '#000000',
    }, SetOptions(merge: true));
    print('✅ Category set: $categoryId');
  }

  /// Lấy tất cả categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final snapshot = await _db.collection(Collections.categories).get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // ============= NOTES =============

  /// Thêm ghi chú — trả về docId
  Future<String> addNote({
    required String userId,
    required String title,
    String? content,
  }) async {
    final ref = await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.notes)
        .add({
      'title': title,
      'content': content ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('✅ Note added: ${ref.id}');
    return ref.id;
  }

  /// Cập nhật ghi chú
  Future<void> updateNote({
    required String userId,
    required String noteId,
    String? title,
    String? content,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;

    await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.notes)
        .doc(noteId)
        .update(data);
    print('✅ Note updated: $noteId');
  }

  /// Xoá ghi chú
  Future<void> deleteNote({
    required String userId,
    required String noteId,
  }) async {
    await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.notes)
        .doc(noteId)
        .delete();
    print('✅ Note deleted: $noteId');
  }

  /// Lấy tất cả ghi chú
  Future<List<Map<String, dynamic>>> getNotes({
    required String userId,
    int limit = 100,
  }) async {
    final snapshot = await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.notes)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // ============= BATCH =============

  /// Xoá tất cả expenses của user
  Future<void> deleteAllExpensesByUser(String userId) async {
    final snapshot = await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.expenses)
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    print('✅ All expenses deleted for: $userId');
  }

  /// Xoá tất cả notes của user
  Future<void> deleteAllNotesByUser(String userId) async {
    final snapshot = await _db
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.notes)
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    print('All notes deleted for: $userId');
  }
}