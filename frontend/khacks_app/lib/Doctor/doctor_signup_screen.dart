import 'package:flutter/material.dart';
import '../core/input_field.dart';
import '../core/app_button.dart';
import './doctor_login_screen.dart'; // ✅ added

class DoctorSignupScreen extends StatelessWidget {
  const DoctorSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Signup")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              decoration: inputDecoration("Full Name", Icons.person),
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: inputDecoration("Email", Icons.email),
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: inputDecoration("Phone Number", Icons.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            TextField(
              obscureText: true,
              decoration: inputDecoration("Password", Icons.lock),
            ),
            const SizedBox(height: 16),

            TextField(
              obscureText: true,
              decoration: inputDecoration("Confirm Password", Icons.lock_outline),
            ),
            const SizedBox(height: 24),

            appButton("Create Account", () {
              // UI only for now
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Signup clicked (UI only)")),
              );
            }),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorLoginScreen(),
                  ),
                );
              },
              child: const Text("Already have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}
