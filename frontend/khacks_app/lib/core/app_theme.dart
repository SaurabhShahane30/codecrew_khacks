import 'package:flutter/material.dart';

class AppTheme {
  static const Color lavender = Color(0xFFB39DDB);

  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    primaryColor: lavender,
    appBarTheme: const AppBarTheme(
      backgroundColor: lavender,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
  );
}