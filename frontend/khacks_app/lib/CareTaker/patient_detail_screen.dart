import 'package:flutter/material.dart';
import 'package:khacks_app/Patient/AddMedicationPage.dart';



class PatientDetailScreen extends StatelessWidget {
  final String name;
  final bool hasMedicine;

  const PatientDetailScreen(
      {super.key, required this.name, required this.hasMedicine});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: hasMedicine
            ? const Text("Medicine list will appear here")
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48),
            const SizedBox(height: 12),
            const Text("No medications added yet"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddMedicationScreen()),
              ),
              child: const Text("Add Medication"),
            )
          ],
        ),
      ),
    );
  }
}