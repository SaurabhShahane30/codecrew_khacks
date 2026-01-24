import 'package:flutter/material.dart';

class CaregiverHomeScreen extends StatelessWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Dashboard")),
      body: const Center(
        child: Text("Caretaker dashboard coming soon"),
      ),
    );
  }
}