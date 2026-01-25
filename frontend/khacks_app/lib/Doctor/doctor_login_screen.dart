import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/input_field.dart';
import '../core/app_button.dart';
import '../services/auth_service.dart';
import './doctor_home_screen.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> loginDoctor() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("http://10.21.9.41:5000/api/doctor/signin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phoneController.text.trim(),
          "password": passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      final token = data['token'];

      // Extract userId from various possible field names
      final dynamic userIdValue = data['userId'] ?? data['id'] ?? data['patientId'];
      final String? userId = userIdValue?.toString();

      // ✅ Save authentication data using AuthService
      await AuthService.saveAuth(
        token: token,
        role: 'doctor',
        userId: userId,
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("doctorToken", data["token"]);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DoctorHomeScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Login failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server error")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Doctor Login")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: phoneController,
              decoration: inputDecoration("Phone Number", Icons.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: inputDecoration("Password", Icons.lock),
            ),
            const SizedBox(height: 24),

            isLoading
                ? const CircularProgressIndicator()
                : appButton("Login", loginDoctor),
          ],
        ),
      ),
    );
  }
}