import 'package:flutter/material.dart';

BoxDecoration appCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}