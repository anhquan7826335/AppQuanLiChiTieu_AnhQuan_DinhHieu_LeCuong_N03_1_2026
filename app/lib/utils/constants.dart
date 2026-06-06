// lib/utils/constants.dart
import 'dart:io';

/// AppConfig: cấu hình URL backend theo môi trường chạy.
/// - Android emulator: 10.0.2.2 -> trỏ về host.
/// - iOS simulator/desktop: localhost.
/// - Máy thật: nên đổi sang IP LAN của PC chạy XAMPP.
class AppConfig {
  static String get baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2/chitieucanhan_api';
    return 'http://localhost/chitieucanhan_api';
  }
}

/// (Tuỳ chọn) Hằng cũ nếu nơi khác còn đang dùng.
/// Khuyến nghị: dùng AppConfig.baseUrl, nhưng giữ lại để tương thích.
const String kApiBaseUrl = 'http://10.0.2.2/chitieucanhan_api';
// Nếu chạy trên máy thật qua Wi-Fi, đổi 10.0.2.2 thành IP LAN của máy XAMPP:
// const String kApiBaseUrl = 'http://192.168.1.10/chitieucanhan_api';

/// Danh mục chi tiêu dùng chung cho filter/export
class ExpenseCategory {
  static const labelAll = 'Tất cả';

  /// Nhãn hiển thị (thêm “Bảo dưỡng xe”)
  static const labels = <String>[
    labelAll,
    'Ăn uống',
    'Di chuyển',
    'Điện',
    'Nước',
    'Điện thoại',
    'Bảo dưỡng xe', // ✅ đã thêm
    'Khác',
  ];

  /// Nếu backend dùng slug, map nhãn -> slug (không bắt buộc).
  static const apiValues = <String, String>{
    'Ăn uống'      : 'an_uong',
    'Di chuyển'    : 'di_chuyen',
    'Điện'         : 'dien',
    'Nước'         : 'nuoc',
    'Điện thoại'   : 'dien_thoai',
    'Bảo dưỡng xe' : 'bao_duong_xe',
    'Khác'         : 'khac',
  };
}
