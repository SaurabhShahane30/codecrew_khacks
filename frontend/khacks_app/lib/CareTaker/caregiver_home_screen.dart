import 'package:flutter/material.dart';
import './patient_screen.dart';
import '../core/app_card.dart';

import './alerts_screen.dart';

class CaregiverHomeScreen extends StatelessWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Caregiver Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Hello, Caregiver 👋",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: appCardDecoration(),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Your Referral Code",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Chip(label: Text("CARE-8X2FQ")),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Alerts",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
                child: const Text("See more"),
              ),
            ],
          ),

          alertTile("Riya missed morning dose"),
          alertTile("Rahul took medicine late"),

          const SizedBox(height: 32),
          const Text("Your Patients",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const PatientsScreen(),
        ],
      ),
    );
  }

  Widget alertTile(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: appCardDecoration(),
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: Colors.red),
        title: Text(text),
      ),
    );
  }
}