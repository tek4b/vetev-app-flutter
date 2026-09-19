import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const VetevApp());
}

class VetevApp extends StatelessWidget {
  const VetevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vetev',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00399e),
      ),
      home: const SplashScreen(),
    );
  }
}
