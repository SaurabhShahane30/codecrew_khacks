import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class MedicationPopupDialog extends StatefulWidget {
  final String alarmId;

  const MedicationPopupDialog({
    Key? key,
    required this.alarmId,
  }) : super(key: key);

  @override
  State<MedicationPopupDialog> createState() => _MedicationPopupDialogState();
}

class _MedicationPopupDialogState extends State<MedicationPopupDialog> {
  static const String BASE_URL = 'http://10.21.9.41:5000';
  static const Color lavender = Color(0xFFB39DDB);

  bool _isLoading = true;
  String? _error;
  bool _useTestData = true; // ✅ Flag to use test data when backend is unavailable
  late String alarmId;
  String? _alarmTime;
  List<Map<String, dynamic>> _medicines = [];
  Set<String> _takenMedicines = {};

  @override
  void initState() {
    super.initState();
    alarmId = widget.alarmId;
    debugPrint("your code is ${alarmId}");
    _fetchAlarmDetails();
  }

  Future<void> _fetchAlarmDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();

      final response = await http.get(
        Uri.parse('$BASE_URL/api/alarm/details').replace(
          queryParameters: { 'alarmId': alarmId },
        ),
        headers: {
          "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 3));

      debugPrint('📥 Alarm details response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final alarm = data['alarm'];  // ✅ Access nested alarm object

        setState(() {
          _alarmTime = alarm['time'] ?? 'Unknown time';
          _medicines = List<Map<String, dynamic>>.from(alarm['medicines'] ?? []);
          _isLoading = false;
          _useTestData = false;
        });

        debugPrint('✅ Loaded ${_medicines.length} medicines from backend');
      } else {
        throw Exception('Failed to fetch alarm details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Backend not available, using test data: $e');

      // ✅ USE TEST DATA when backend is unavailable
      setState(() {
        _alarmTime = '8:00 AM';
        _medicines = [
          {
            '_id': 'test1',
            'name': 'Paracetamol',
            'type': 'tablet',
            'doseCount': 2,
            'isCritical': false,
          },
          {
            '_id': 'test2',
            'name': 'Cough Syrup',
            'type': 'syrup',
            'doseCount': 10,
            'isCritical': true,
          },
        ];
        _isLoading = false;
        _useTestData = true;
      });

      debugPrint('✅ Loaded ${_medicines.length} TEST medicines');
    }
  }
  Future<void> _markAsTaken() async {
    if (_takenMedicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one medicine'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ If using test data, just show success message
    if (_useTestData) {
      if (mounted) {
        Navigator.pop(context, 'taken');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Marked ${_takenMedicines.length} medicine(s) as taken (TEST MODE)'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // ✅ Otherwise, try backend
    try {
      final token = await AuthService.getToken();

      final response = await http.post(
        Uri.parse('$BASE_URL/api/alarm/taken'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'alarmId': alarmId,
          'medicines': _takenMedicines.toList(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, 'taken');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Marked as taken'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to mark as taken');
      }
    } catch (e) {
      debugPrint('❌ Error marking as taken: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _snooze() async {
    // ✅ If using test data, just show success message
    if (_useTestData) {
      if (mounted) {
        Navigator.pop(context, 'snoozed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Snoozed for 10 minutes (TEST MODE)'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }

    // ✅ Otherwise, try backend
    try {
      final token = await AuthService.getToken();

      final response = await http.post(
        Uri.parse('$BASE_URL/api/alarm/snooze'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'alarmId': alarmId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, 'snoozed');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏰ Snoozed for 10 minutes'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        throw Exception('Failed to snooze');
      }
    } catch (e) {
      debugPrint('❌ Error snoozing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lavender.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medication, color: lavender, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medication Reminder',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      if (_alarmTime != null)
                        Text(
                          _alarmTime!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      // ✅ Show TEST MODE indicator
                      if (_useTestData)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TEST MODE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Content
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_medicines.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No medicines found for this alarm'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _medicines.length,
                  itemBuilder: (context, index) {
                    final medicine = _medicines[index];
                    final medicineId = medicine['_id'] ?? medicine['id'] ?? '';
                    final name = medicine['name'] ?? 'Unknown';
                    final type = medicine['type'] ?? 'tablet';
                    final dose = medicine['doseCount'] ?? 1;
                    final isCritical = medicine['isCritical'] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _takenMedicines.contains(medicineId)
                            ? lavender.withOpacity(0.1)
                            : Colors.white,
                        border: Border.all(
                          color: _takenMedicines.contains(medicineId)
                              ? lavender
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CheckboxListTile(
                        value: _takenMedicines.contains(medicineId),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _takenMedicines.add(medicineId);
                            } else {
                              _takenMedicines.remove(medicineId);
                            }
                          });
                        },
                        title: Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (isCritical) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          type == 'syrup' ? '$dose ml' : '$dose tablet${dose > 1 ? 's' : ''}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        activeColor: lavender,
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _snooze,
                    icon: const Icon(Icons.snooze),
                    label: const Text('Snooze'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markAsTaken,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Taken'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lavender,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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