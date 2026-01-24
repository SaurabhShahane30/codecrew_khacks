import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // ✅ NEW: Callback for when user taps notification
  static Function(String?)? onNotificationTap;

  static Future<void> init() async {
    debugPrint('🔧 Initializing NotificationService...');

    await AndroidAlarmManager.initialize();
    debugPrint('✅ AndroidAlarmManager initialized');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    // ✅ NEW: Handle notification tap
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Notification tapped! Payload: ${response.payload}');
        if (onNotificationTap != null) {
          onNotificationTap!(response.payload);
        }
      },
    );

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
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
    );

    debugPrint("✅ Background notification displayed!");
  }

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

  static Future<void> scheduleTestAlarm({int seconds = 10}) async {
    final DateTime testTime = DateTime.now().add(Duration(seconds: seconds));
    await scheduleAlarm(testTime, "Test Medicine");
    debugPrint("🧪 Test alarm will fire in $seconds seconds at $testTime");
  }

  static Future<void> cancelAlarm(int alarmId) async {
    await AndroidAlarmManager.cancel(alarmId);
    debugPrint("❌ Alarm $alarmId cancelled");
  }

  // ✅ MODIFIED: Now includes alarmCode in payload
  static Future<void> showMedicationAlarm(String medicineName, {int? alarmCode}) async {
    debugPrint("🔔 Showing immediate alarm for: $medicineName (Code: $alarmCode)");

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '💊 Medication Reminder',
      'Time to take: $medicineName',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'med_alarm_channel',
          'Medication Alarms',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          sound: RawResourceAndroidNotificationSound('alarm'),
        ),
      ),
      payload: alarmCode?.toString(), // ✅ Pass alarmCode as payload
    );

    debugPrint("✅ Notification shown for $medicineName");
  }
}