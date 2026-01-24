import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:khacks_app/Patient/AddMedicationPage.dart';
import 'package:khacks_app/Patient/BuyMedication.dart' hide AddMedicationScreen;
import 'package:khacks_app/Patient/ProfilePage.dart';
import 'package:khacks_app/Patient/multiple_medicines.dart';
import 'package:table_calendar/table_calendar.dart';



class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color lavender = Color(0xFFB39DDB);

  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  int _selectedIndex = 0;

  Future<List<Map<String, dynamic>>>? _medicineFuture;

  String alarmKeyToLabel(int key) {
    switch (key) {
      case 1:
        return "Before Breakfast";
      case 2:
        return "After Breakfast";
      case 3:
        return "Before Lunch";
      case 4:
        return "After Lunch";
      case 5:
        return "Before Dinner";
      case 6:
        return "After Dinner";
      default:
        return key >= 1000 ? "Custom Time" : "Unknown";
    }
  }

  @override
  void initState() {
    super.initState();
    _medicineFuture = _fetchMedications();
  }

  /// ===========================
  /// FETCH MEDICINES (FINAL FIX)
  /// ===========================
  Future<List<Map<String, dynamic>>> _fetchMedications() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final response = await http.get(
        Uri.parse("http://10.21.9.41:5000/api/medicine/fetch"),
        headers: {"Authorization": "Bearer $token"},
      );

      final decoded = jsonDecode(response.body);
      final List medicines = decoded["medicines"] ?? [];

      final selectedDate = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
      );

      final selectedWeekday = [
        "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
      ][_selectedDay.weekday - 1];

      return medicines.where((medicine) {
        /// ---- CREATED AT FIX (Mongo $date safe) ----
        final createdAtRaw = medicine["createdAt"];
        DateTime rawCreatedAt;

        if (createdAtRaw is String) {
          rawCreatedAt = DateTime.parse(createdAtRaw).toLocal();
        } else if (createdAtRaw is Map && createdAtRaw.containsKey("\$date")) {
          rawCreatedAt =
              DateTime.parse(createdAtRaw["\$date"]).toLocal();
        } else {
          return false;
        }


        final createdAt = DateTime(
          rawCreatedAt.year,
          rawCreatedAt.month,
          rawCreatedAt.day,
        );

        final durationDays = medicine["durationDays"] ?? 1;
        final endDate =
        createdAt.add(Duration(days: durationDays - 1));

        final isWithinRange =
            !selectedDate.isBefore(createdAt) &&
                !selectedDate.isAfter(endDate);

        final List days = medicine["days"] ?? [];
        final isValidDay = days.contains(selectedWeekday);

        /// ---- FINAL RULE ----
        if (medicine["frequency"] == "Specific Days") {
          return isWithinRange && isValidDay;
        } else {
          return isWithinRange;
        }
      }).map<Map<String, dynamic>>((medicine) {
        final List<int> alarmKeys =
            (medicine["alarmKeys"] as List?)?.cast<int>() ?? [];

        return {
          "name": medicine["name"] ?? "Unknown",
          "alarms": alarmKeys.map(alarmKeyToLabel).toList(),
        };
      }).toList();
    } catch (e) {
      debugPrint("❌ Error fetching medicines: $e");
      return [];
    }
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _getPageContent() {
    if (_selectedIndex == 0) return _buildHomeContent();
    if (_selectedIndex == 1) return AddMedicationScreen();
    return ProfilePage();
  }

  Widget _buildMedicineCard(String name, List<String> alarms) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: lavender.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.medication_outlined,
              color: lavender),
        ),
        title: Text(
          name,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3142)),
        ),
        subtitle: Text(
          alarms.isEmpty ? "No time specified" : alarms.join(", "),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text(
                  //   Text.getString(context),
                  //   style: const TextStyle(
                  //     fontSize: 28,
                  //     fontWeight: FontWeight.w700,
                  //     color: Color(0xFF2D3142),
                  //   ),
                  // ),
                  const SizedBox(height: 4),
                  Text(
                    "Let’s take care of your health 💊",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),

              /// 👉 Right-side icons
              Row(
                children: [
                  /// Prescription PDF Button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MultipleMedicinesScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lavender.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: lavender,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                ],
              ),
            ],
          ),


          const SizedBox(height: 20),

          /// Calendar
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _selectedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) =>
                isSameDay(_selectedDay, day),
            onDaySelected: (day, _) {
              setState(() {
                _selectedDay = day;
                _medicineFuture = _fetchMedications();
              });
            },
          ),

          const SizedBox(height: 20),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _medicineFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("No medicines scheduled"));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (_, i) => _buildMedicineCard(
                    snapshot.data![i]["name"],
                    List<String>.from(
                        snapshot.data![i]["alarms"]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPageContent(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: lavender,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddMedicationScreen()),
          );
          setState(() {
            _medicineFuture = _fetchMedications();
          });
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: lavender,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_pharmacy),
              label: "Your Medicine"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}