import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    payload: alarmId.toString(),
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

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to fetch alarms: ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['alarms'] == null ||
          responseData['alarms'] is! List) {
        debugPrint('❌ No alarms array found');
        return;
      }

      final List alarms = responseData['alarms'];
      if (alarms.isEmpty) {
        debugPrint('ℹ️ No alarms to schedule');
        return;
      }

      /// ✅ Clear only AFTER successful fetch
      await clearAllLocalAlarms();

      final prefs = await SharedPreferences.getInstance();
      int scheduledCount = 0;

      for (final alarm in alarms) {
        try {
          if (alarm['alarmCode'] == null || alarm['time'] == null) continue;

          final List<String> medicineNames = [];
          if (alarm['medicines'] is List) {
            for (final medicine in alarm['medicines']) {
              if (medicine is Map && medicine['name'] != null) {
                medicineNames.add(medicine['name'].toString());
              }
            }
          }

          if (medicineNames.isEmpty) continue;

          final int alarmCode = alarm['alarmCode'] is int
              ? alarm['alarmCode']
              : int.parse(alarm['alarmCode'].toString());

          final String timeStr = alarm['time'].toString();
          final String medicinesDisplay = medicineNames.join(', ');

          await prefs.setString('alarm_$alarmCode', medicinesDisplay);
          await _trackAlarmId(alarmCode);

          await scheduleAlarm(alarmCode, timeStr);
          scheduledCount++;
        } catch (e) {
          debugPrint('❌ Alarm processing error: $e');
        }
      }

      debugPrint(
          '✅ Successfully scheduled $scheduledCount/${alarms.length} alarms');
    } catch (e, stackTrace) {
      debugPrint('❌ Alarm sync error: $e');
      debugPrint('$stackTrace');
    }
  }

  /// ⏰ Schedule a single alarm
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
      }

      await AndroidAlarmManager.oneShotAt(
        alarmTime,
        alarmCode,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      debugPrint('✅ Alarm $alarmCode scheduled at $alarmTime');
    } catch (e) {
      debugPrint('❌ Alarm schedule error: $e');
    }
  }

  /// 🗑️ Clear all locally tracked alarms
  static Future<void> clearAllLocalAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final trackedIds = prefs.getStringList('tracked_alarm_ids') ?? [];

    for (final idStr in trackedIds) {
      try {
        final id = int.parse(idStr);
        await AndroidAlarmManager.cancel(id);
        await prefs.remove('alarm_$id');
      } catch (_) {}
    }

    await prefs.setStringList('tracked_alarm_ids', []);
    debugPrint('🗑️ All local alarms cleared');
  }

  static Future<void> _trackAlarmId(int alarmCode) async {
    final prefs = await SharedPreferences.getInstance();
    final tracked = prefs.getStringList('tracked_alarm_ids') ?? [];

    if (!tracked.contains(alarmCode.toString())) {
      tracked.add(alarmCode.toString());
      await prefs.setStringList('tracked_alarm_ids', tracked);
    }
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

    await AndroidAlarmManager.oneShotAt(
      testTime,
      999999,
      alarmCallback,
      exact: true,
      wakeup: true,
    );

    debugPrint('🧪 Test alarm scheduled');
  }

  static Future<void> cancelAlarm(int alarmCode) async {
    await AndroidAlarmManager.cancel(alarmCode);

    final prefs = await SharedPreferences.getInstance();
    final tracked = prefs.getStringList('tracked_alarm_ids') ?? [];
    tracked.remove(alarmCode.toString());
    await prefs.setStringList('tracked_alarm_ids', tracked);
  }
}
