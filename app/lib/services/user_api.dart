// lib/services/user_api.dart
import 'api_client.dart';

class UserApi {
  /// Trả về URL ảnh đại diện. Back-end có thể là 'avatar' hoặc 'avatar_url'
  static Future<String?> getAvatarUrl(int userId) async {
    final m = await ApiClient.getJson('user_get.php', {'user_id': '$userId'});
    if (m['success'] != true) throw Exception(m['message'] ?? 'user_get failed');
    final u = (m['user'] as Map<String, dynamic>);
    final raw = u['avatar_url'] ?? u['avatar'];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

  static Future<String?> getDisplayName(int userId) async {
    final m = await ApiClient.getJson('user_get.php', {'user_id': '$userId'});
    if (m['success'] != true) throw Exception(m['message'] ?? 'user_get failed');
    final u = (m['user'] as Map<String, dynamic>);
    final name = (u['name'] ?? '').toString();
    return name.isEmpty ? null : name;
  }
}
