import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    debugPrint('🔧 Initializing NotificationService...');

    await AndroidAlarmManager.initialize();
    debugPrint('✅ AndroidAlarmManager initialized');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    await _notifications.initialize(settings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'med_alarm_channel',
      'Medication Alarms',
      description: 'Medication reminder notifications',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ NotificationService initialized');
  }

  @pragma('vm:entry-point')
  static Future<void> _alarmCallback() async {
    debugPrint("🔔 ALARM CALLBACK TRIGGERED IN BACKGROUND!");

    final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

    // Re-create channel with sound in background isolate
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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '💊 Medication Reminder',
      'Time to take your medicine!',
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
          audioAttributesUsage: AudioAttributesUsage.alarm, // ✅ This is important!
        ),
      ),
    );

    debugPrint("✅ Background notification displayed!");
  }

  // Schedule alarm for specific time
  static Future<void> scheduleAlarm(DateTime scheduledTime, String medicineName) async {
    final int alarmId = scheduledTime.millisecondsSinceEpoch ~/ 1000;

    debugPrint("⏰ Scheduling alarm for: $scheduledTime");
    debugPrint("⏰ Alarm ID: $alarmId");

    await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      alarmId,
      _alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    debugPrint("✅ Alarm scheduled successfully!");
  }

  // For immediate testing
  static Future<void> scheduleTestAlarm({int seconds = 10}) async {
    final DateTime testTime = DateTime.now().add(Duration(seconds: seconds));
    await scheduleAlarm(testTime, "Test Medicine");
    debugPrint("🧪 Test alarm will fire in $seconds seconds at $testTime");
  }

  // Cancel a specific alarm
  static Future<void> cancelAlarm(int alarmId) async {
    await AndroidAlarmManager.cancel(alarmId);
    debugPrint("❌ Alarm $alarmId cancelled");
  }

  // Show immediate notification (for testing when app is open)
  static Future<void> showMedicationAlarm(String medicineName) async {
    debugPrint("🔔 Showing immediate alarm for: $medicineName");

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '💊 Medication Reminder',
      'Time to take: $medicineName',
      const NotificationDetails(
        android: AndroidNotificationDetails(
            'med_alarm_channel',
            'Medication Alarms',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            sound: RawResourceAndroidNotificationSound('alarm')
          // playSound: true,
          // enableVibration: true,
        ),
      ),
    );

    debugPrint("✅ Notification shown for $medicineName");
  }
}