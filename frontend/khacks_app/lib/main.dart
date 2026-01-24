import 'package:flutter/material.dart';
import 'package:khacks_app/role_selection_screen.dart';
import 'package:flutter/services.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

    });
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Khacks',
      theme: ThemeData(primarySwatch: Colors.blue),
      // 🔹 KEEP LOGIN AS DEFAULT
      home: RoleSelectionScreen(),
      // 🔹 ADD ROUTE FOR HOME PAGE
      routes: {
        // '/home': (_) => const HomePage(),
      },
    );
  }
}

