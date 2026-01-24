import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:khacks_app/core/app_theme.dart';
import './doctor_overview_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  bool isLoading = true;
  String doctorName = "";
  List patients = [];
  List filteredPatients = [];

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDoctorData();
    searchController.addListener(_filterPatients);
  }

  Future<void> fetchDoctorData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("doctorToken");

      final response = await http.get(
        Uri.parse("http://10.21.9.41:5000/api/doctor"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        setState(() {
          doctorName = data["doctor"]["name"];
          patients = data["patients"];
          filteredPatients = patients;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load doctor data");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch data")),
      );
      setState(() => isLoading = false);
    }
  }

  void _filterPatients() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredPatients = patients.where((patient) {
        return patient["name"]
            .toString()
            .toLowerCase()
            .contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                Text(
                  "Hello $doctorName!",
                  style: const TextStyle(
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
                  controller: searchController,
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
                  Text("Showing ${filteredPatients.length} patients"),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredPatients.length,
                      itemBuilder: (context, index) {
                        final patient = filteredPatients[index];

                        return PatientCard(
                          name: patient["name"],
                          risk: "Low", // placeholder (logic later)
                          patientId: patient["_id"],
                        );
                      },
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
  final String patientId;

  const PatientCard({
    super.key,
    required this.name,
    required this.risk,
    required this.patientId,
  });

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