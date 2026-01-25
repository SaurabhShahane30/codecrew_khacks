import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:khacks_app/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  TimeOfDay breakfastTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay lunchTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay dinnerTime = const TimeOfDay(hour: 21, minute: 0);

  final TextEditingController _doctorCodeController = TextEditingController();

  bool isLoading = false;
  bool isDoctorLinking = false;

  @override
  void initState() {
    super.initState();
    breakfastTime = _parse12h("09:00 AM");
    lunchTime = _parse12h("02:00 PM");
    dinnerTime = _parse12h("09:00 PM");
  }

  @override
  void dispose() {
    _doctorCodeController.dispose();
    super.dispose();
  }

  /// ---------------------------
  /// "09:00 PM" → TimeOfDay
  /// ---------------------------
  TimeOfDay _parse12h(String time) {
    final parts = time.split(RegExp(r'[: ]'));
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    final isPM = time.contains("PM");

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// ---------------------------
  /// FORCE AM/PM PICKER
  /// ---------------------------
  Future<void> _pickTime(
      TimeOfDay currentTime,
      Function(TimeOfDay) onSelected,
      ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  /// ---------------------------
  /// FORMAT → hh:mm AM/PM
  /// ---------------------------
  String _formatStrict12h(TimeOfDay time) {
    int hour = time.hour;
    int minute = time.minute;

    final isPM = hour >= 12;
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return "${hour.toString().padLeft(2, '0')}:"
        "${minute.toString().padLeft(2, '0')} "
        "${isPM ? "PM" : "AM"}";
  }

  /// ---------------------------
  /// UPDATE MEAL TIMES API
  /// ---------------------------
  Future<void> updateMealTimes() async {
    setState(() => isLoading = true);

    final mealTimes = [
      {"meal": "breakfast", "time": _formatStrict12h(breakfastTime)},
      {"meal": "lunch", "time": _formatStrict12h(lunchTime)},
      {"meal": "dinner", "time": _formatStrict12h(dinnerTime)},
    ];

    try {
      final token = await AuthService.getToken();

      final response = await http.put(
        Uri.parse("http://10.21.9.41:5000/api/patient/updateTimes"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"mealTimes": mealTimes}),
      );

      if (response.statusCode == 200) {
        _showSnack("Meal times updated", Colors.green);
      } else {
        throw Exception();
      }
    } catch (_) {
      _showSnack("Server error", Colors.red);
    }

    setState(() => isLoading = false);
  }

  /// ---------------------------
  /// ADD DOCTOR REFERRAL API
  /// ---------------------------
  Future<void> addDoctorReferral() async {
    final code = _doctorCodeController.text.trim();

    if (code.isEmpty) {
      _showSnack("Enter referral code", Colors.orange);
      return;
    }

    setState(() => isDoctorLinking = true);

    try {
      final token = await AuthService.getToken();

      final response = await http.put(
        Uri.parse("http://10.21.9.41:5000/api/patient/addDoctor"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"referralCode": code}),
      );

      if (response.statusCode == 200) {
        _doctorCodeController.clear();
        _showSnack("Doctor linked successfully", Colors.green);
      } else {
        throw Exception();
      }
    } catch (_) {
      _showSnack("Invalid referral code", Colors.red);
    }

    setState(() => isDoctorLinking = false);
  }

  /// ---------------------------
  /// SIGN OUT
  /// ---------------------------
  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/role-selection',
              (route) => false,
        );
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  /// ---------------------------
  /// UI
  /// ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Meal Timings",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _tile(
              "Breakfast Time",
              breakfastTime,
                  () => _pickTime(breakfastTime, (t) => breakfastTime = t),
            ),
            _tile(
              "Lunch Time",
              lunchTime,
                  () => _pickTime(lunchTime, (t) => lunchTime = t),
            ),
            _tile(
              "Dinner Time",
              dinnerTime,
                  () => _pickTime(dinnerTime, (t) => dinnerTime = t),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : updateMealTimes,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Meal Times"),
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              "Doctor Referral",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _doctorCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: "Enter doctor referral code",
                prefixIcon: const Icon(Icons.medical_services),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isDoctorLinking ? null : addDoctorReferral,
                child: isDoctorLinking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Add Doctor"),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  "Sign Out",
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: _handleSignOut,
              ),
            ),
          ],
        ),

    ),
    );
  }

  Widget _tile(String title, TimeOfDay time, VoidCallback onTap) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          _formatStrict12h(time),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: onTap,
      ),
    );
  }
}
