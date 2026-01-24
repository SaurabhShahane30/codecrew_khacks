import 'package:flutter/material.dart';
import 'package:khacks_app/Patient/AddMedicationPage.dart';

import 'patient_detail_screen.dart';
import '../core/app_card.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        patientCard(context, "Riya", "Female", 22, false),
        patientCard(context, "Rahul", "Male", 65, true),
      ],
    );
  }

  Widget patientCard(BuildContext context, String name, String gender, int age,
      bool hasMedicine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text("$gender • $age yrs", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  child: const Text("Add"),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AddMedicationScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  child: const Text("Edit"),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientDetailScreen(
                        name: name,
                        hasMedicine: hasMedicine,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}