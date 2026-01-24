import 'package:flutter/material.dart';
import 'package:khacks_app/core/app_theme.dart';
import './doctor_overview_screen.dart';

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      body: Column(
        children: [
          // 🔵 Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.lavender,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Hello Doctor!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Monitor patient compliance",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search patients...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📋 List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Showing 6 patients"),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView(
                      children: const [
                        PatientCard(name: "Patient P1", risk: "Low"),
                        PatientCard(name: "Patient P2", risk: "Medium"),
                        PatientCard(name: "Patient P3", risk: "High"),
                        PatientCard(name: "Patient P4", risk: "Low"),
                        PatientCard(name: "Patient P5", risk: "Medium"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientCard extends StatelessWidget {
  final String name;
  final String risk;

  const PatientCard({super.key, required this.name, required this.risk});

  Color get riskColor {
    switch (risk) {
      case "High":
        return Colors.red;
      case "Medium":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0E7FF),
          child: Icon(Icons.person, color: Color(0xFF2563EB)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: riskColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$risk Risk",
            style: TextStyle(color: riskColor, fontSize: 12),
          ),
        ),
        trailing: TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PatientOverviewScreen(),
              ),
            );
          },
          child: const Text("View Report ›"),
        ),
      ),
    );
  }
}
