import 'package:flutter/material.dart';
import '../core/input_field.dart';
import '../core/app_button.dart';

class CaregiverSignupScreen extends StatelessWidget {
  const CaregiverSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Caregiver Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(decoration: inputDecoration("Name", Icons.person)),
            const SizedBox(height: 16),
            TextField(decoration: inputDecoration("Email", Icons.email)),
            const SizedBox(height: 16),
            TextField(
                obscureText: true,
                decoration: inputDecoration("Password", Icons.lock)),
            const SizedBox(height: 24),
            appButton("Sign Up", () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}