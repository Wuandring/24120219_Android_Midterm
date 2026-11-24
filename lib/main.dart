import 'package:flutter/material.dart';

import 'ui/screens/concert_map_screen.dart';

void main() => runApp(const ConcertApp());

class ConcertApp extends StatelessWidget {
  const ConcertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sơ đồ chỗ concert',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF06B6D4),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
      ),
      home: const ConcertMapScreen(),
    );
  }
}
