import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../core/app_card.dart';
import './alerts_screen.dart';
// import './add_medicine_screen.dart';       // create later
// import './patient_report_screen.dart';     // create later

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  // ===== STATE =====
  List<dynamic> alerts = [];
  List<dynamic> patients = [];

  bool loadingAlerts = true;
  bool loadingPatients = true;

  String caretakerName = "Caregiver";
  String referralCode = "CARE-8X2FQ"; // replace later from API if needed

  @override
  void initState() {
    super.initState();
    fetchAlerts();          // 🔔 alerts API
    fetchCaretakerInfo();   // 👨‍⚕️ caretaker + patients API
  }

  // ==============================
  // 🔔 FETCH ALERTS
  // ==============================
  Future<void> fetchAlerts() async {
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse("http://10.21.9.41:5000/api/caretaker/alerts"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = json.decode(res.body);

      if (res.statusCode == 200 && data["success"] == true) {
        setState(() {
          alerts = data["alerts"];
          loadingAlerts = false;
        });
      } else {
        setState(() {
          loadingAlerts = false;
        });
        debugPrint("Alert fetch failed: ${data["message"]}");
      }
    } catch (e) {
      setState(() {
        loadingAlerts = false;
      });
      debugPrint("Alert API error: $e");
    }
  }

  // ==============================
  // 👨‍⚕️ FETCH CARETAKER + PATIENTS
  // ==============================
  Future<void> fetchCaretakerInfo() async {
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse("http://10.21.9.41:5000/api/caretaker"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = json.decode(res.body);

      if (res.statusCode == 200 && data["success"] == true) {
        setState(() {
          caretakerName = data["caretaker"]["name"];
          referralCode  = data["caretaker"]["referralCode"];
          patients      = data["patients"];   // keep this if already using
          loadingPatients = false;
        });
      } else {
        setState(() {
          loadingPatients = false;
        });
        debugPrint("Caretaker fetch failed: ${data["message"]}");
      }

      if (res.statusCode == 200 && data["success"] == true) {
        setState(() {
          caretakerName = data["caretaker"]["name"];
          patients = data["patients"];
          loadingPatients = false;
        });
      } else {
        setState(() {
          loadingPatients = false;
        });
        debugPrint("Caretaker fetch failed: ${data["message"]}");
      }
    } catch (e) {
      setState(() {
        loadingPatients = false;
      });
      debugPrint("Caretaker API error: $e");
    }
  }

  // ==============================
  // 🧱 UI
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Caregiver Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== HEADER =====
          Text("Hello, $caretakerName 👋",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // ===== REFERRAL =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: appCardDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Your Referral Code",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Chip(label: Text(referralCode)),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ===== ALERTS HEADER =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Alerts",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlertsScreen(alerts: alerts),
                  ),
                ),
                child: const Text("See more"),
              ),
            ],
          ),

          // ===== ALERTS BODY =====
          if (loadingAlerts)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "No alerts 🎉",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...alerts.take(3).map((a) => alertTile(a)).toList(),

          const SizedBox(height: 32),

          // ===== PATIENTS HEADER =====
          const Text("Your Patients",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // ===== PATIENTS BODY =====
          if (loadingPatients)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (patients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "No patients linked yet",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...patients.map((p) => patientCard(p)).toList(),
        ],
      ),
    );
  }

  // ==============================
  // 🔔 ALERT TILE
  // ==============================
  Widget alertTile(dynamic alert) {
    final patient = alert["patientId"];
    final patientName = patient != null ? patient["name"] : "Patient";
    final medicineName = alert["name"];
    final missed = alert["missed"];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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

  // ==============================
  // 👤 PATIENT CARD (SAME FILE)
  // ==============================
  Widget patientCard(dynamic patient) {
    final name = patient["name"];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: appCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Name
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // Buttons
            Row(
              children: [
                // ➕ Add Medicine
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.medication),
                    label: const Text("Add"),
                    onPressed: () {
                      // TODO: navigate to Add Medicine screen
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (_) => AddMedicineScreen(
                      //       patientId: patient["_id"],
                      //     ),
                      //   ),
                      // );
                    },
                  ),
                ),

                const SizedBox(width: 12),

                // 📊 View Report
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.insert_chart_outlined),
                    label: const Text("View"),
                    onPressed: () {
                      // TODO: navigate to Patient Report screen
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (_) => PatientReportScreen(
                      //       patientId: patient["_id"],
                      //     ),
                      //   ),
                      // );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}