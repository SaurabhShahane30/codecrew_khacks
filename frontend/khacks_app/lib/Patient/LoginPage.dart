//LoginPage.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:khacks_app/core/app_button.dart';
import 'package:khacks_app/core/input_field.dart';
import '../core/app_button.dart';
import '../core/input_field.dart';
import '../services/auth_service.dart';
import './SignUppage.dart';
import './HomePage.dart';


import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  bool _isLoading = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final storage = FlutterSecureStorage();

  String? _errorMessage;


  @override
  void initState() {
    super.initState();
  }

  // TODO: Implement MongoDB login function
  Future<void> login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      int? phone = int.tryParse(_phoneController.text.trim());

      if (phone == null) {
        setState(() {
          _errorMessage = "Invalid phone number";
          _isLoading = false;
        });
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('http://10.21.9.41:5000/api/patient/signin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phone,        // ✅ number
            'password': _passwordController.text.trim(),
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
          role: 'patient',
          userId: userId,
        );

        if (response.statusCode == 200) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        } else {
          setState(() {
            _errorMessage = "Invalid phone or password";
          });
        }

      } catch (e) {
        setState(() {
          _errorMessage = "Something went wrong. Please try again.";
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Login"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Phone Number
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.number,
                decoration: inputDecoration("Phone Number", Icons.phone),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter phone number";
                  }
                  if (value.length != 10) {
                    return "Phone number must be 10 digits";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: inputDecoration(
                  "Password",
                  Icons.lock,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter password";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Error Message
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),

              const SizedBox(height: 24),

              // Login Button (OLD STYLE)
              appButton("Login", () {
                if (_formKey.currentState!.validate()) {
                  login();
                }
              }),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignUpScreen()),
                  );
                },
                child: const Text("New patient? Sign up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}