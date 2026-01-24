import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:khacks_app/core/app_button.dart';
import 'package:khacks_app/core/app_card.dart';
import './LoginPage.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final TextEditingController _caregiverCodeController =
  TextEditingController();

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  String caregiver = "No";

  // ================= SIGN UP =================
  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final phone = int.tryParse(_phoneController.text.trim());
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        phone == null ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackbar("Please fill all fields");
      return;
    }

    if (password.length < 6) {
      _showSnackbar("Password must be at least 6 characters");
      return;
    }

    if (password != confirmPassword) {
      _showSnackbar("Passwords do not match");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.181:5000/api/patient/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': password,
          'caregiver': caregiver,
          'caregiverCode':
          caregiver == "Yes" ? _caregiverCodeController.text.trim() : null,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await storage.write(key: 'token', value: data['token']);

        _showSnackbar("Sign-Up Successful!", isSuccess: true);

        Timer(const Duration(seconds: 2), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
        });
      } else {
        _showSnackbar(data['message'] ?? "Sign-up failed");
      }
    } catch (e) {
      _showSnackbar("Sign-up failed");
    }
  }

  void _showSnackbar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Patient Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              field("Name", Icons.person, controller: _nameController),
              const SizedBox(height: 16),

              field(
                "Phone",
                Icons.phone,
                controller: _phoneController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),

              field(
                "Password",
                Icons.lock,
                controller: _passwordController,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 16),

              field(
                "Confirm Password",
                Icons.lock,
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                  onPressed: () => setState(() =>
                  _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: appCardDecoration(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  value: caregiver,
                  items: const [
                    DropdownMenuItem(value: "Yes", child: Text("Yes")),
                    DropdownMenuItem(value: "No", child: Text("No")),
                  ],
                  onChanged: (v) => setState(() => caregiver = v!),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: "Do you have a caregiver?",
                  ),
                ),
              ),

              if (caregiver == "Yes") ...[
                const SizedBox(height: 16),
                field(
                  "Caregiver Code",
                  Icons.qr_code,
                  controller: _caregiverCodeController,
                ),
              ],

              const SizedBox(height: 24),
              appButton("Sign Up", _signUp),
            ],
          ),
        ),
      ),
    );
  }

  // ================= FIELD =================
  Widget field(
      String hint,
      IconData icon, {
        TextEditingController? controller,
        bool obscureText = false,
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
        Widget? suffixIcon,
      }) {
    return Container(
      decoration: appCardDecoration(),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _caregiverCodeController.dispose();
    super.dispose();
  }
}
