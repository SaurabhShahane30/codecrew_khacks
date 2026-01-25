import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../core/app_card.dart';
import './doctor_overview_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  // ===== STATE =====
  bool loading = true;

  String doctorName = "Doctor";
  List<dynamic> patients = [];
  List<dynamic> filteredPatients = [];

  final TextEditingController searchController = TextEditingController();

  final String baseUrl = "http://10.21.9.41:5000";

  @override
  void initState() {
    super.initState();
    fetchDoctorInfo();
    searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ==============================
  // 👨‍⚕️ FETCH DOCTOR + PATIENTS
  // ==============================
  Future<void> fetchDoctorInfo() async {
    try {
      final token = await AuthService.getToken();

      final res = await http.get(
        Uri.parse("$baseUrl/api/doctor"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = json.decode(res.body);

      if (res.statusCode == 200 && data["success"] == true) {
        setState(() {
          doctorName = data["doctor"]["name"];
          patients = data["patients"];
          filteredPatients = patients;
          loading = false;
        });
      } else {
        loading = false;
        debugPrint("Doctor fetch failed: ${data["message"]}");
      }
    } catch (e) {
      loading = false;
      debugPrint("Doctor API error: $e");
    }

    setState(() {});
  }

  // ==============================
  // 🔍 FILTER PATIENTS
  // ==============================
  void _filterPatients() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredPatients = patients.where((p) {
        return p["name"].toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  // ==============================
  // 🧱 UI
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Dashboard")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== HEADER =====
          Text(
            "Hello, Dr. $doctorName 👋",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Monitor patient compliance",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 24),

          // ===== SEARCH =====
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: "Search patients...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ===== PATIENTS HEADER =====
          Text(
            "Patients (${filteredPatients.length})",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          // ===== PATIENT LIST =====
          if (filteredPatients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "No patients found",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...filteredPatients.map((p) => patientCard(p)).toList(),
        ],
      ),
    );
  }

  // ==============================
  // 👤 PATIENT CARD
  // ==============================
  Widget patientCard(dynamic patient) {
    final name = patient["name"];
    final patientId = patient["_id"];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: appCardDecoration(),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0E7FF),
          child: Icon(Icons.person, color: Color(0xFF2563EB)),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientOverviewScreen(
                  patientId: patientId,
                  patientName: name,
                ),
              ),
            );
          },
          child: const Text("View Report ›"),
        ),
      ),
    );
  }
}
