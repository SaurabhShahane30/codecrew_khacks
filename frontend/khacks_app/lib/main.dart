import 'package:flutter/material.dart';
import 'package:khacks_app/role_selection_screen.dart';
import 'package:khacks_app/services/notification_service.dart';
import 'package:khacks_app/services/alarm_service.dart'; // ✅ ADD
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize alarm manager
  await AndroidAlarmManager.initialize();

  // Initialize notifications
  await NotificationService.init();

  runApp(const MyApp());
}

/* =========================
   MAIN APP (UNCHANGED)
   ========================= */
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('exact_alarm_permission');

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestExactAlarmPermission();
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
      debugShowCheckedModeBanner: false,
      title: 'MediBuddy',
      theme: ThemeData(primarySwatch: Colors.blue),


      // 🔹 KEEP LOGIN AS DEFAULT
      home: RoleSelectionScreen(),

      // 🔹 ADD ROUTE FOR HOME PAGE
      routes: {
        '/home': (_) => const HomePage(),
      },
    );
  }
}

/* =========================
   HOME PAGE (ADDED)
   ========================= */
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAlarmSystem();
  }

  Future<void> _initializeAlarmSystem() async {
    debugPrint("🚀 Initializing alarm system...");

    try {
      await AlarmService.initializeMidnightSync();
      await AlarmService.syncAndScheduleAlarms();

      setState(() => _isInitialized = true);

      debugPrint("✅ Alarm system initialized");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Alarms synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
    }
  }

  Future<void> _onMedicineAdded() async {
    await AlarmService.onMedicineAdded();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Alarms updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _manualSync() async {
    await AlarmService.syncAndScheduleAlarms();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sync complete'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Reminder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _manualSync,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _isInitialized ? 'Alarm system active' : 'Initializing...',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: AlarmService.testAlarm,
              child: const Text('Test Alarm (5 sec)'),
            ),

            ElevatedButton(
              onPressed: _onMedicineAdded,
              child: const Text('Simulate Add Medicine'),
            ),

            OutlinedButton(
              onPressed: AlarmService.clearAllLocalAlarms,
              child: const Text('Clear All Alarms'),
            ),
          ],
        ),
      ),
    );
  }
}
