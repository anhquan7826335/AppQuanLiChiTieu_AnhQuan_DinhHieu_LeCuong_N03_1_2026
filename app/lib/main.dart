import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'providers.dart';
import 'firebase_options.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  await Hive.initFlutter();


  final container = ProviderContainer();
  try {
    await Future.wait([
      container.read(authServiceProvider).init(),
      container.read(expenseServiceProvider).init(),
      container.read(noteServiceProvider).init(),
    ]);
  } catch (e) {
    print('Error initializing services: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SpendingApp(),
    ),
  );
}