import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Tạo container & init services trước khi runApp
  final container = ProviderContainer();
  await Future.wait([
    container.read(authServiceProvider).init(),
    container.read(expenseServiceProvider).init(),
  ]);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SpendingApp(),
    ),
  );
}
