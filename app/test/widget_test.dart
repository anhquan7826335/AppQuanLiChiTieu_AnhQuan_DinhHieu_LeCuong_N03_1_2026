// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Relative import để không phụ thuộc name trong pubspec
import '../lib/app.dart';

void main() {
  testWidgets('App renders LoginScreen title', (WidgetTester tester) async {
    // Pump app (bọc bằng ProviderScope vì LoginScreen dùng Riverpod)
    await tester.pumpWidget(const ProviderScope(child: SpendingApp()));

    // Kiểm tra có text "Đăng nhập" trên màn hình đầu tiên
    expect(find.text('Đăng nhập'), findsOneWidget);
    // Không cần tương tác counter mặc định nữa
    expect(find.byIcon(Icons.add), findsNothing);
  });
}