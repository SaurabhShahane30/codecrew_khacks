import 'package:flutter/material.dart';
import './app_theme.dart';

InputDecoration inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: AppTheme.lavender),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.lavender, width: 2),
    ),
  );
}