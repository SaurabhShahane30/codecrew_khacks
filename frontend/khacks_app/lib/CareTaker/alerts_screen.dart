import 'package:flutter/material.dart';
import '../core/app_card.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Alerts")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          alert("Riya missed Paracetamol"),
          alert("Rahul took insulin late"),
        ],
      ),
    );
  }

  Widget alert(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: appCardDecoration(),
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: Colors.red),
        title: Text(text),
      ),
    );
  }
}