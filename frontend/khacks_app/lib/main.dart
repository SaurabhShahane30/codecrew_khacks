import 'package:flutter/material.dart';
import 'package:khacks_app/role_selection_screen.dart';
import 'package:khacks_app/services/notification_service.dart';
import 'package:khacks_app/services/alarm_service.dart';
import 'package:khacks_app/services/auth_service.dart';
import 'package:khacks_app/Patient/medication_popup_dialog.dart';
import 'package:khacks_app/Patient/notification_history_page.dart';
import 'package:khacks_app/Patient/HomePage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';

// ✅ Global navigator key to show dialog from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AndroidAlarmManager.initialize();
  await NotificationService.init();

  // ✅ Handle notification taps globally
  NotificationService.onNotificationTap = (payload) {
    debugPrint('🔔 Notification tapped with payload: $payload');

    if (payload != null && payload.isNotEmpty) {
      final String alarmId = payload;

      if (alarmId != null) {
        // Show popup dialog
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => MedicationPopupDialog(alarmId: alarmId),
            fullscreenDialog: true,
          ),
        );
      }
    }
  };

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('exact_alarm_permission');
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestExactAlarmPermission();
    });
  }

  // Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  Future<void> requestExactAlarmPermission() async {
    try {
      await platform.invokeMethod('requestExactAlarm');
      debugPrint('✅ Exact alarm permission requested');
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to request permission: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MediBuddy',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _isLoading
          ? const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      )
          : _isLoggedIn
          ? HomePage()
          : RoleSelectionScreen(),
      routes: {
        '/home': (_) => HomePage(),
        // '/history': (_) => const NotificationHistoryPage(),
        '/role-selection': (_) => RoleSelectionScreen(),
      },
    );
  }

  void onTranslatedLanguage(Locale? locale) {
    setState(() {});
  }
}