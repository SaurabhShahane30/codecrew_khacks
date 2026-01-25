import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auth_service.dart';

/// 🔔 CRITICAL: Global callback - runs in separate isolate
@pragma('vm:entry-point')
void alarmCallback(int alarmId) async {
  debugPrint("🔥 ALARM CALLBACK TRIGGERED for ID: $alarmId");

  final prefs = await SharedPreferences.getInstance();
  final medicineName = prefs.getString('alarm_$alarmId') ?? 'Your medication';
  final originalId = prefs.getString('alarm_original_$alarmId') ?? '';

  final FlutterLocalNotificationsPlugin notifications =
  FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'med_alarm_channel',
    'Medication Alarms',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('alarm'),
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  await notifications
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await notifications.show(
    alarmId,
    '💊 Medication Reminder',
    'Time to take: $medicineName',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'med_alarm_channel',
        'Medication Alarms',
        channelDescription: 'Medication reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        sound: RawResourceAndroidNotificationSound('alarm'),
        playSound: true,
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    ),
    payload: originalId,
  );

  debugPrint("✅ Alarm notification triggered for: $medicineName");
}

/// 🌙 MIDNIGHT SYNC CALLBACK
@pragma('vm:entry-point')
void midnightSyncCallback() async {
  debugPrint("🌙 MIDNIGHT SYNC TRIGGERED");
  await AlarmService.syncAndScheduleAlarms();
  debugPrint("✅ Midnight sync completed");
}

class AlarmService {
  static const int MIDNIGHT_SYNC_ID = 999998;
  static const String BASE_URL = 'http://10.21.9.41:5000';

  /// 🌙 Schedule daily midnight sync
  static Future<void> initializeMidnightSync() async {
    debugPrint("🌙 Initializing midnight sync...");

    await AndroidAlarmManager.cancel(MIDNIGHT_SYNC_ID);

    final now = DateTime.now();
    final nextMidnight =
    DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    final success = await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      MIDNIGHT_SYNC_ID,
      midnightSyncCallback,
      startAt: nextMidnight,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    debugPrint(
        success ? "✅ Midnight sync scheduled" : "❌ Midnight sync failed");
  }

  /// 🔄 Sync alarms from backend and schedule locally
  static Future<void> syncAndScheduleAlarms() async {
    try {
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('❌ No auth token found. Skipping alarm sync.');
        return;
      }

      final response = await http
          .get(
        Uri.parse('$BASE_URL/api/alarm/upcoming'),
        headers: {"Authorization": "Bearer $token"},
      )
          .timeout(const Duration(seconds: 10));

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to fetch alarms: ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['alarms'] == null ||
          responseData['alarms'] is! List) {
        debugPrint('❌ No alarms array found in response');
        return;
      }

      final List alarms = responseData['alarms'];

      if (alarms.isEmpty) {
        debugPrint('ℹ️ No alarms to schedule');
        await clearAllLocalAlarms();
        return;
      }

      debugPrint('📋 Found ${alarms.length} alarms to process');

      final prefs = await SharedPreferences.getInstance();
      int scheduledCount = 0;
      List<String> validAlarmIds = [];

      for (int i = 0; i < alarms.length; i++) {
        final alarm = alarms[i];

        debugPrint('🔍 Processing alarm $i: ${alarm.toString()}');

        // ✅ FIX: Backend returns "alarmId" not "_id"
        final alarmId = alarm['alarmId'] ?? alarm['_id'];
        final timeStr = alarm['time'];

        if (alarmId == null || timeStr == null) {
          debugPrint('⚠️ Alarm $i missing alarmId or time, skipping');
          continue;
        }

        try {
          final List<String> medicineNames = [];
          if (alarm['medicines'] is List) {
            for (final medicine in alarm['medicines']) {
              if (medicine is Map && medicine['name'] != null) {
                medicineNames.add(medicine['name'].toString());
              }
            }
          }

          if (medicineNames.isEmpty) {
            debugPrint('⚠️ Alarm $i has no valid medicines, skipping');
            continue;
          }

          // ✅ Use backend's alarmCode if available, otherwise hash alarmId
          final int alarmCode = alarm['alarmCode'] ?? alarmId.toString().hashCode;

          final String medicinesDisplay = medicineNames.join(', ');

          debugPrint('💊 Scheduling: $medicinesDisplay at $timeStr');
          debugPrint('   Alarm ID: $alarmId');
          debugPrint('   Alarm Code: $alarmCode');

          // ✅ Store both the medicine name and original ID
          await prefs.setString('alarm_$alarmCode', medicinesDisplay);
          await prefs.setString('alarm_original_$alarmCode', alarmId.toString());

          validAlarmIds.add(alarmCode.toString());

          await scheduleAlarm(alarmCode, timeStr);
          scheduledCount++;

          debugPrint('✅ Successfully scheduled alarm $scheduledCount');
        } catch (e, stack) {
          debugPrint('❌ Error processing alarm $i: $e');
          debugPrint('Stack: $stack');
        }
      }

      await _updateTrackedAlarmIds(validAlarmIds);

      debugPrint(
          '✅ Successfully scheduled $scheduledCount/${alarms.length} alarms');
    } catch (e, stackTrace) {
      debugPrint('❌ Alarm sync error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// ⏰ Schedule a single alarm using alarmCode directly
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

      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(const Duration(days: 1));
        debugPrint('⏭️ Alarm time in past, scheduling for tomorrow');
      }

      final success = await AndroidAlarmManager.oneShotAt(
        alarmTime,
        alarmCode,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      if (success) {
        debugPrint('✅ Alarm scheduled at $alarmTime (code: $alarmCode)');
      } else {
        debugPrint('❌ Failed to schedule alarm $alarmCode');
      }
    } catch (e, stack) {
      debugPrint('❌ Alarm schedule error for $alarmCode: $e');
      debugPrint('Stack: $stack');
    }
  }

  /// 🗑️ Clear all locally tracked alarms
  static Future<void> clearAllLocalAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final trackedIds = prefs.getStringList('tracked_alarm_ids') ?? [];

    debugPrint('🗑️ Clearing ${trackedIds.length} tracked alarms');

    for (final idStr in trackedIds) {
      try {
        final int alarmCode = int.parse(idStr);
        await AndroidAlarmManager.cancel(alarmCode);
        await prefs.remove('alarm_$alarmCode');
        await prefs.remove('alarm_original_$alarmCode');
        debugPrint('🗑️ Cancelled alarm: $alarmCode');
      } catch (e) {
        debugPrint('⚠️ Failed to clear alarm $idStr: $e');
      }
    }

    await prefs.setStringList('tracked_alarm_ids', []);
    debugPrint('✅ All local alarms cleared');
  }

  /// ✅ Update tracked alarm IDs
  static Future<void> _updateTrackedAlarmIds(List<String> newIds) async {
    final prefs = await SharedPreferences.getInstance();

    final oldIds = prefs.getStringList('tracked_alarm_ids') ?? [];
    for (final oldId in oldIds) {
      if (!newIds.contains(oldId)) {
        try {
          final int alarmCode = int.parse(oldId);
          await AndroidAlarmManager.cancel(alarmCode);
          await prefs.remove('alarm_$alarmCode');
          await prefs.remove('alarm_original_$alarmCode');
          debugPrint('🗑️ Removed outdated alarm: $alarmCode');
        } catch (e) {
          debugPrint('⚠️ Failed to remove alarm $oldId: $e');
        }
      }
    }

    await prefs.setStringList('tracked_alarm_ids', newIds);
    debugPrint('📝 Updated tracking: ${newIds.length} alarms');
  }

  /// 💊 Trigger sync when medicine is added (NON-BLOCKING)
  static Future<void> onMedicineAdded() async {
    debugPrint('💊 Medicine added → triggering alarm sync');
    Future.microtask(syncAndScheduleAlarms);
  }

  /// 🧪 Test alarm
  static Future<void> testAlarm() async {
    final testTime = DateTime.now().add(const Duration(seconds: 5));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_999999', 'Test Medicine');
    await prefs.setString('alarm_original_999999', 'test_id_123');

    final success = await AndroidAlarmManager.oneShotAt(
      testTime,
      999999,
      alarmCallback,
      exact: true,
      wakeup: true,
    );

    debugPrint(success ? '✅ Test alarm scheduled for 5 seconds' : '❌ Test alarm failed');
  }
}