import 'package:flutter/material.dart';
import 'package:app/front/about_page.dart';
import 'package:app/front/content_page.dart';
import 'package:app/front/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ứng dụng thu chi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
      ),
      initialRoute: '/home',
      routes: {
        '/home': (context) => const HomePage(),
        '/content': (context) => const ContentPage(),
        '/contact': (context) => const AboutPage(),
      },
    );
  }
}
