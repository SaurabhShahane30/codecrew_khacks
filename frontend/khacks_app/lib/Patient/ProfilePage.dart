import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  TimeOfDay breakfastTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay lunchTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay dinnerTime = const TimeOfDay(hour: 21, minute: 0);

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    breakfastTime = _parse12h("09:00 AM");
    lunchTime = _parse12h("02:00 PM");
    dinnerTime = _parse12h("09:00 PM");
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
  /// STRICT FORMAT → hh:mm AM/PM
  /// ---------------------------
  String _formatStrict12h(TimeOfDay time) {
    int hour = time.hour;
    int minute = time.minute;

    final isPM = hour >= 12;
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final hh = hour.toString().padLeft(2, '0');   // 👈 leading zero
    final mm = minute.toString().padLeft(2, '0');
    final period = isPM ? "PM" : "AM";

    return "$hh:$mm $period";
  }

  /// ---------------------------
  /// API CALL
  /// ---------------------------
  Future<void> updateMealTimes() async {
    setState(() => isLoading = true);

    final mealTimes = [
      {"meal": "breakfast", "time": _formatStrict12h(breakfastTime)},
      {"meal": "lunch", "time": _formatStrict12h(lunchTime)},
      {"meal": "dinner", "time": _formatStrict12h(dinnerTime)},
    ];

    try {
      final response = await http.put(
        Uri.parse("http://10.21.9.41:5000/api/patient/updateTimes"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"mealTimes": mealTimes}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meal times updated")),
        );
      } else {
        throw Exception("Update failed");
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server error")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Timings"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _tile("Breakfast Time", breakfastTime,
                    () => _pickTime(breakfastTime, (t) => breakfastTime = t)),
            _tile("Lunch Time", lunchTime,
                    () => _pickTime(lunchTime, (t) => lunchTime = t)),
            _tile("Dinner Time", dinnerTime,
                    () => _pickTime(dinnerTime, (t) => dinnerTime = t)),
            const SizedBox(height: 30),
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
          _formatStrict12h(time), // 👈 02:00 PM, 09:00 AM
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: onTap,
      ),
    );
  }
}