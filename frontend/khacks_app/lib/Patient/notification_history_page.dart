import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'medication_popup_dialog.dart';

class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({Key? key}) : super(key: key);

  @override
  State<NotificationHistoryPage> createState() => _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage> {
  static const String BASE_URL = '10.21.9.41:5000';
  static const Color lavender = Color(0xFFB39DDB);

  bool _isLoading = true;
  bool _useTestData = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();

      final response = await http.get(
        Uri.parse('$BASE_URL/api/alarm/history'),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 3));

      debugPrint('📥 History response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _history = List<Map<String, dynamic>>.from(data['history'] ?? []);
          _isLoading = false;
          _useTestData = false;
        });

        debugPrint('✅ Loaded ${_history.length} history items from backend');
      } else {
        throw Exception('Failed to fetch history');
      }
    } catch (e) {
      debugPrint('⚠️ Backend not available, using test data: $e');

      // ✅ USE TEST DATA
      setState(() {
        _history = [
          {
            'alarmCode': 999999,
            'time': '8:00 AM',
            'status': 'missed',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
            'medicines': [
              {'name': 'Paracetamol', 'isCritical': false},
              {'name': 'Cough Syrup', 'isCritical': true},
            ],
          },
          {
            'alarmCode': 999998,
            'time': '2:00 PM',
            'status': 'taken',
            'timestamp': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
            'medicines': [
              {'name': 'Vitamin D', 'isCritical': false},
            ],
          },
          {
            'alarmCode': 999997,
            'time': '6:00 PM',
            'status': 'snoozed',
            'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            'medicines': [
              {'name': 'Aspirin', 'isCritical': true},
            ],
          },
        ];
        _isLoading = false;
        _useTestData = true;
      });

      debugPrint('✅ Loaded ${_history.length} TEST history items');
    }
  }

  Future<void> _openAlarmDialog(int alarmCode) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MedicationPopupDialog(alarmCode: alarmCode),
    );

    if (result != null) {
      _fetchHistory();
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Unknown time';

    try {
      final dt = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else {
        return DateFormat('MMM dd, h:mm a').format(dt);
      }
    } catch (e) {
      return dateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Notification History',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_useTestData) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TEST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: lavender,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No notification history',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your alarms will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchHistory,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _history.length,
          itemBuilder: (context, index) {
            final item = _history[index];
            final alarmCode = item['alarmCode'];
            final time = item['time'] ?? 'Unknown';
            final status = item['status'] ?? 'missed';
            final timestamp = item['timestamp'];
            final medicines = List<Map<String, dynamic>>.from(
                item['medicines'] ?? []
            );

            Color statusColor;
            IconData statusIcon;
            String statusText;

            switch (status) {
              case 'taken':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                statusText = 'Taken';
                break;
              case 'snoozed':
                statusColor = Colors.blue;
                statusIcon = Icons.snooze;
                statusText = 'Snoozed';
                break;
              default:
                statusColor = Colors.orange;
                statusIcon = Icons.warning_amber_rounded;
                statusText = 'Missed';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: status == 'missed'
                      ? () => _openAlarmDialog(alarmCode)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                statusIcon,
                                color: statusColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Alarm at $time',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D3142),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(timestamp),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (medicines.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: medicines.map((med) {
                              final name = med['name'] ?? 'Unknown';
                              final isCritical = med['isCritical'] ?? false;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: lavender.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: lavender.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.medication,
                                      size: 14,
                                      color: lavender,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isCritical) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (status == 'missed') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openAlarmDialog(alarmCode),
                              icon: const Icon(Icons.touch_app, size: 18),
                              label: const Text('Take Action'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: lavender,
                                side: BorderSide(color: lavender),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}