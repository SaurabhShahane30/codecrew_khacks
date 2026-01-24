import 'package:flutter/material.dart';
import 'package:khacks_app/CareTaker/caregiver_home_screen.dart';
import '../core/input_field.dart';
import '../core/app_button.dart';


class CaregiverLoginScreen extends StatelessWidget {
  const CaregiverLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Caregiver Login")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(decoration: inputDecoration("Email", Icons.email)),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: inputDecoration("Password", Icons.lock),
            ),
            const SizedBox(height: 24),
            appButton("Login", () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const CaregiverHomeScreen()),
              );
            }),
          ],
        ),
      ),
    );
  }
}
