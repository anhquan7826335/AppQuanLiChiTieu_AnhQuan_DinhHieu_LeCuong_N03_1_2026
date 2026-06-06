// lib/services/settings_api.dart
import 'api_client.dart';

class UserSettingsDto {
  final double monthlyBudget;
  final String currency;
  UserSettingsDto({required this.monthlyBudget, required this.currency});
}

class SettingsApi {
  static Future<UserSettingsDto> getSettings(int userId) async {
    final m = await ApiClient.getJson('settings_get.php', {'user_id': '$userId'});
    if (m['success'] != true) throw Exception(m['message'] ?? 'settings_get failed');
    final s = (m['settings'] as Map<String, dynamic>);
    final budget = double.tryParse((s['monthly_budget'] ?? '0').toString()) ?? 0.0;
    final ccy = (s['currency'] ?? 'VND').toString();
    return UserSettingsDto(monthlyBudget: budget, currency: ccy);
  }

  static Future<void> setBudget(int userId, double budget, {String currency = 'VND'}) async {
    final m = await ApiClient.postForm('settings_set.php', {
      'user_id': '$userId',
      'monthly_budget': budget.toString(),
      'currency': currency,
    });
    if (m['success'] != true) throw Exception(m['message'] ?? 'settings_set failed');
  }
}
