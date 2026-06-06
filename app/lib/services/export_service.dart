// lib/services/export_service.dart
import 'dart:convert';
import 'dart:io' show File; // không được import trên web
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import '../models/expense.dart';

/// ===== Helpers chạy ở isolate (top-level) =====

/// Chuyển rows -> CSV ở background isolate để không block UI
String _csvFromRows(List<List<dynamic>> rows) {
  return const ListToCsvConverter().convert(rows);
}

/// Với saveRawCsv: không cần helper vì đã có csvText sẵn.

class ExportService {
  /// Xuất CSV từ danh sách Expense.
  /// Trả về:
  /// - Web: `null` (vì tải trực tiếp)
  /// - Mobile/Desktop: đường dẫn file vừa lưu
  Future<String?> exportCsv(List<Expense> items) async {
    // 1) Chuẩn bị dữ liệu
    final rows = <List<dynamic>>[
      ['ID', 'Title', 'Category', 'Amount', 'Date', 'Note'],
      ...items.map((e) => [
        e.id,
        e.title,
        e.category,
        e.amount,
        e.date.toIso8601String(),
        e.note,
      ]),
    ];

    // 2) Convert CSV ở background isolate nếu dữ liệu lớn để tránh đứng UI
    //    (ngưỡng có thể điều chỉnh; 1500 hàng là mức an toàn phổ biến)
    final String csv = rows.length > 1500
        ? await compute(_csvFromRows, rows)
        : const ListToCsvConverter().convert(rows);

    final bytes = utf8.encode(csv);

    // 3) Web: tải qua anchor (giữ nguyên tên file cũ: expenses.csv)
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement(href: url)
        ..setAttribute('download', 'expenses.csv')
        ..style.display = 'none';
      html.document.body?.append(a);
      a.click();
      a.remove();
      html.Url.revokeObjectUrl(url);
      return null;
    }

    // 4) Mobile/Desktop: lưu file
    final downloadsDir =
    await getDownloadsDirectory().catchError((_) => null); // iOS có thể null
    final baseDir = downloadsDir ?? await getApplicationDocumentsDirectory();

    final time = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('-', '');
    final filePath = p.join(baseDir.path, 'expenses_$time.csv');

    final f = File(filePath);
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  /// Lưu **chuỗi CSV đã dựng sẵn** (dùng ở admin_expenses_screen).
  /// Trả về giống `exportCsv`: web => null, còn lại => full path.
  Future<String?> saveRawCsv(
      String csvText, {
        String filenameHint = 'export',
      }) async {
    final bytes = utf8.encode(csvText);

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement(href: url)
        ..setAttribute('download', '$filenameHint.csv')
        ..style.display = 'none';
      html.document.body?.append(a);
      a.click();
      a.remove();
      html.Url.revokeObjectUrl(url);
      return null;
    }

    final downloadsDir =
    await getDownloadsDirectory().catchError((_) => null);
    final baseDir = downloadsDir ?? await getApplicationDocumentsDirectory();

    final time = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('-', '');
    final filePath = p.join(baseDir.path, '${filenameHint}_$time.csv');

    final f = File(filePath);
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }
}
