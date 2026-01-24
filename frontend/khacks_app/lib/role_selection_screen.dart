import 'package:flutter/material.dart';
import 'package:khacks_app/Patient/LoginPage.dart';
import 'package:khacks_app/core/app_card.dart';


class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("You are a?",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),


            roleCard(
                context, "Patient", Icons.person, LoginScreen()),
          ],
        ),
      ),
    );
  }

  Widget roleCard(
      BuildContext context, String title, IconData icon, Widget screen) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: appCardDecoration(),
        child: Row(
          children: [
            Icon(icon, size: 36, color: const Color(0xFFB39DDB)),
            const SizedBox(width: 16),
            Text(title,
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
