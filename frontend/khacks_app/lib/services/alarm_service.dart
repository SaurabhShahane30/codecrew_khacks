import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔔 CRITICAL: Global callback - runs in separate isolate
@pragma('vm:entry-point')
void alarmCallback(int alarmId) async {
  debugPrint("🔥 ALARM CALLBACK TRIGGERED for ID: $alarmId");

  final prefs = await SharedPreferences.getInstance();
  final medicineName = prefs.getString('alarm_$alarmId') ?? 'Your medication';

  await NotificationService.init();
  await NotificationService.showMedicationAlarm(medicineName);

  debugPrint("✅ Alarm notification triggered for: $medicineName");
}

// 🌙 MIDNIGHT SYNC CALLBACK - Runs every day at 00:00
@pragma('vm:entry-point')
void midnightSyncCallback() async {
  debugPrint("🌙 MIDNIGHT SYNC TRIGGERED at ${DateTime.now()}");


  // Perform the sync
  await AlarmService.syncAndScheduleAlarms();

  debugPrint("✅ Midnight sync completed");
}

class AlarmService {
  static const int MIDNIGHT_SYNC_ID = 999998; // Reserved ID for midnight sync
  static const String BASE_URL = 'http://10.21.9.41:5000';

  /// Initialize midnight sync - call this once during app startup
  static Future<void> initializeMidnightSync() async {
    debugPrint("🌙 Setting up midnight sync...");


    // Calculate next midnight
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));

    debugPrint("📅 Next midnight sync scheduled for: $nextMidnight");

    // Schedule periodic midnight sync
    final success = await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      MIDNIGHT_SYNC_ID,
      midnightSyncCallback,
      startAt: nextMidnight,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    if (success) {
      debugPrint("✅ Midnight sync initialized successfully");
    } else {
      debugPrint("❌ Failed to initialize midnight sync");
    }
  }

  /// Main sync function - fetches alarms and schedules them
  static Future<void> syncAndScheduleAlarms() async {


    try {
      // Step 1: Clear all existing alarms
      await clearAllLocalAlarms();

      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      // Step 2: Fetch fresh alarms from backend
      final response = await http.get(
          Uri.parse('$BASE_URL/api/alarm/upcoming'),
          headers: {"Authorization": "Bearer $token",}
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to fetch alarms: ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      debugPrint('📦 API Response: Success=${responseData['success']}, Count=${responseData['count']}');

      if (responseData['alarms'] == null || responseData['alarms'] is! List) {
        debugPrint('❌ No alarms array found in response');
        return;
      }

      final List alarms = responseData['alarms'];
      debugPrint('📋 Found ${alarms.length} alarms to schedule');

      // Step 3: Schedule all new alarms
      final prefs = await SharedPreferences.getInstance();
      int scheduledCount = 0;

      for (final alarm in alarms) {
        try {
          if (alarm['alarmCode'] == null || alarm['time'] == null) {
            debugPrint('⚠️ Skipping alarm with missing alarmCode or time');
            continue;
          }

          // Extract medicine names
          final List<String> medicineNames = [];
          if (alarm['medicines'] != null && alarm['medicines'] is List) {
            for (final medicine in alarm['medicines']) {
              if (medicine is Map && medicine['name'] != null) {
                medicineNames.add(medicine['name'].toString());
              }
            }
          }

          if (medicineNames.isEmpty) {
            debugPrint('⚠️ Skipping alarm ${alarm['alarmCode']} - no medicines');
            continue;
          }

          final int alarmCode = alarm['alarmCode'] is int
              ? alarm['alarmCode']
              : int.parse(alarm['alarmCode'].toString());

          final String timeStr = alarm['time'].toString();
          final String medicinesDisplay = medicineNames.join(', ');

          // Store medicine name for callback
          await prefs.setString('alarm_$alarmCode', medicinesDisplay);

          // Track this alarm ID
          await _trackAlarmId(alarmCode);

          debugPrint('⏰ Scheduling: Code=$alarmCode, Time=$timeStr, Meds=$medicinesDisplay');

          await scheduleAlarm(alarmCode, timeStr);
          scheduledCount++;

        } catch (e) {
          debugPrint('❌ Error processing alarm: $e');
          continue;
        }
      }

      debugPrint('✅ Successfully scheduled $scheduledCount/${alarms.length} alarms');

    } catch (e, stackTrace) {
      debugPrint('❌ Error syncing alarms: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Schedule a single alarm
  static Future<void> scheduleAlarm(int alarmCode, String timeStr) async {
    try {
      final parsed = DateFormat('h:mm a').parse(timeStr.trim());

      final now = DateTime.now();
      DateTime alarmTime = DateTime(
        now.year,
        now.month,
        now.day,
        parsed.hour,
        parsed.minute,
      );

      // If time already passed today, schedule for tomorrow
      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(const Duration(days: 1));
      }

      debugPrint('📅 Scheduling alarm $alarmCode for: $alarmTime');

      final success = await AndroidAlarmManager.oneShotAt(
        alarmTime,
        alarmCode,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      if (success) {
        debugPrint('✅ Alarm $alarmCode scheduled for $alarmTime');
      } else {
        debugPrint('❌ Failed to schedule alarm $alarmCode');
      }

    } catch (e) {
      debugPrint('❌ Error scheduling alarm $alarmCode: $e');
    }
  }

  /// Clear all local alarms
  static Future<void> clearAllLocalAlarms() async {
    debugPrint('🗑️ Clearing all local alarms...');

    final prefs = await SharedPreferences.getInstance();
    final trackedIds = prefs.getStringList('tracked_alarm_ids') ?? [];

    for (final idStr in trackedIds) {
      try {
        final alarmCode = int.parse(idStr);
        await AndroidAlarmManager.cancel(alarmCode);

        // Also remove medicine name from storage
        await prefs.remove('alarm_$alarmCode');

        debugPrint('✅ Cancelled alarm: $alarmCode');
      } catch (e) {
        debugPrint('❌ Error cancelling alarm $idStr: $e');
      }
    }

    // Clear the tracking list
    await prefs.setStringList('tracked_alarm_ids', []);
    debugPrint('✅ All local alarms cleared');
  }

  /// Track alarm IDs so we can cancel them later
  static Future<void> _trackAlarmId(int alarmCode) async {
    final prefs = await SharedPreferences.getInstance();
    final tracked = prefs.getStringList('tracked_alarm_ids') ?? [];

    if (!tracked.contains(alarmCode.toString())) {
      tracked.add(alarmCode.toString());
      await prefs.setStringList('tracked_alarm_ids', tracked);
    }
  }

  /// Called when user adds a new medicine
  static Future<void> onMedicineAdded() async {
    debugPrint('💊 New medicine added - triggering immediate sync...');

    // Wait a moment for backend to process
    await Future.delayed(const Duration(milliseconds: 500));

    // Sync alarms (this will clear old ones and add new ones)
    await syncAndScheduleAlarms();

    debugPrint('✅ Medicine addition sync completed');
  }

  /// Test alarm (for debugging)
  static Future<void> testAlarm() async {
    debugPrint('🧪 Setting test alarm for 5 seconds from now');

    final testTime = DateTime.now().add(const Duration(seconds: 5));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_999999', 'Test Medicine');

    final success = await AndroidAlarmManager.oneShotAt(
      testTime,
      999999,
      alarmCallback,
      exact: true,
      wakeup: true,
    );

    if (success) {
      debugPrint('✅ Test alarm scheduled for: $testTime');
    } else {
      debugPrint('❌ Failed to schedule test alarm');
    }
  }

  /// Cancel a specific alarm
  static Future<void> cancelAlarm(int alarmCode) async {
    await AndroidAlarmManager.cancel(alarmCode);

    // Remove from tracking
    final prefs = await SharedPreferences.getInstance();
    final tracked = prefs.getStringList('tracked_alarm_ids') ?? [];
    tracked.remove(alarmCode.toString());
    await prefs.setStringList('tracked_alarm_ids', tracked);

    debugPrint('🗑️ Cancelled alarm: $alarmCode');
  }
}