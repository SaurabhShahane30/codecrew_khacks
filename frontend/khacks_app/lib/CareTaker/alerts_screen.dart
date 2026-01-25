import 'package:flutter/material.dart';
import '../core/app_card.dart';

class AlertsScreen extends StatelessWidget {
  final List<dynamic> alerts;

  const AlertsScreen({
    super.key,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Alerts")),
      body: alerts.isEmpty
          ? const Center(
        child: Text(
          "No alerts 🎉",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return alertTile(alert);
        },
      ),
    );
  }

  // 🧱 Dynamic Alert Tile
  Widget alertTile(dynamic alert) {
    final patient = alert["patientId"];
    final patientName = patient != null ? patient["name"] : "Patient";
    final medicineName = alert["name"];
    final missed = alert["missed"];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: appCardDecoration(),
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: Colors.red),
        title: Text("$patientName missed $medicineName"),
        subtitle: Text("Missed count: $missed"),
        trailing: alert["isCritical"] == true
            ? const Icon(Icons.priority_high, color: Colors.red)
            : null,
      ),
    );
  }
}