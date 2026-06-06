// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiClient {
  static Future<Map<String, dynamic>> getJson(String path, [Map<String, String>? q]) async {
    final uri = Uri.parse('$kApiBaseUrl/$path').replace(queryParameters: q);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> postForm(String path, Map<String, String> body) async {
    final uri = Uri.parse('$kApiBaseUrl/$path');
    final res = await http.post(uri, body: body);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
