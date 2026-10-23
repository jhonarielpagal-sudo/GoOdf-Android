import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const GoodfMobileApp());
}

class GoodfMobileApp extends StatelessWidget {
  const GoodfMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoOdf Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6D4C41),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6D4C41),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
