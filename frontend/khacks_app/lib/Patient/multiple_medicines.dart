import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

import '../services/auth_service.dart';


/// =======================
/// BACKEND SERVICE
/// =======================
class MultipleMedicineService {
  static const String MAIN_BACKEND = 'http://10.21.9.41:5000';
  static const String PRESCRIPTION_SERVER = 'http://10.21.0.139:5002';

  // Cloudinary configuration - REPLACE WITH YOUR VALUES
  static final cloudinary = CloudinaryPublic(
    'djqbzwhet',
    'medicine_photos',
    cache: false,
  );

  static Future<String?> uploadMedicinePhoto(File imageFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'medicine_photos',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> extractFromFile(String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$PRESCRIPTION_SERVER/api/medicine/extract-file'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = jsonDecode(responseData);

        if (jsonData['success'] == true) {
          final medicines = jsonData['medicines'] as List;
          return medicines.map((m) => m as Map<String, dynamic>).toList();
        } else {
          throw Exception(jsonData['message'] ?? 'No medicines detected');
        }
      } else {
        throw Exception('Failed to process file');
      }
    } catch (e) {
      debugPrint('Error extracting from file: $e');
      rethrow;
    }
  }

  static Future<void> addMedication(Map<String, dynamic> medicationData) async {
    try {
      final token = await AuthService.getToken();
      debugPrint("Before");
      final response = await http.post(
        Uri.parse('$MAIN_BACKEND/api/medicine/add'),
        headers: {'Content-Type': 'application/json',"Authorization": "Bearer $token",},
        body: jsonEncode(medicationData),
      );
      debugPrint("After");

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add medication');
      }
    } catch (e) {
      debugPrint('Error adding medication: $e');
      rethrow;
    }
  }
}

/// =======================
/// UI SCREEN
///

/// =======================
///

/// =======================
/// EDIT MEDICINE SCREEN
/// =======================
class EditMedicineScreen extends StatefulWidget {
  final Map<String, dynamic> medicine;
  final Function(Map<String, dynamic>) onSave;

  const EditMedicineScreen({
    Key? key,
    required this.medicine,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  static const Color lavender = Color(0xFFB39DDB);

  late TextEditingController nameController;
  late TextEditingController durationController;
  late String medicineType;
  late Map<String, bool> intakeMap;
  late List<TimeOfDay> customTimes;
  late String frequency;
  late int doseCount;
  late bool isCritical;

  // Photo upload state
  final ImagePicker _imagePicker = ImagePicker();
  File? _medicinePhoto;
  String? _medicinePhotoUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.medicine['name']);
    durationController = TextEditingController(
        text: (widget.medicine['durationDays'] ?? 7).toString()
    );

    medicineType = widget.medicine['type'] ?? 'tablet';

    intakeMap = {
      "Before Breakfast": false,
      "After Breakfast": false,
      "Before Lunch": false,
      "After Lunch": false,
      "Before Dinner": false,
      "After Dinner": false,
    };

    final intakeTimes = widget.medicine['intakeTimes'] as List? ?? [];
    for (var time in intakeTimes) {
      if (intakeMap.containsKey(time)) {
        intakeMap[time] = true;
      }
    }

    customTimes = [];
    final customTimeStrings = widget.medicine['customTimes'] as List? ?? [];
    for (var timeStr in customTimeStrings) {
      try {
        final parts = timeStr.toString().split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0].trim());
          final minute = int.parse(parts[1].trim().split(' ')[0]);
          customTimes.add(TimeOfDay(hour: hour, minute: minute));
        }
      } catch (e) {
        debugPrint("Error parsing time: $e");
      }
    }

    frequency = widget.medicine['frequency'] ?? 'Daily';
    doseCount = widget.medicine['doseCount'] ?? (medicineType == 'syrup' ? 5 : 1);
    isCritical = widget.medicine['isCritical'] ?? false;

    _medicinePhotoUrl = widget.medicine['photoUrl'] as String?;
  }

  @override
  void dispose() {
    nameController.dispose();
    durationController.dispose();
    super.dispose();
  }

  Future<void> _pickMedicinePhoto({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _medicinePhoto = File(image.path);
          _isUploadingPhoto = true;
        });

        final url = await MultipleMedicineService.uploadMedicinePhoto(_medicinePhoto!);

        setState(() {
          _medicinePhotoUrl = url;
          _isUploadingPhoto = false;
        });

        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo uploaded successfully!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload photo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeMedicinePhoto() {
    setState(() {
      _medicinePhoto = null;
      _medicinePhotoUrl = null;
    });
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera, color: lavender),
              const SizedBox(width: 10),
              const Text(
                "Medicine Photo (Optional)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_medicinePhoto != null || _medicinePhotoUrl != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _medicinePhoto != null
                      ? Image.file(
                    _medicinePhoto!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                      : Image.network(
                    _medicinePhotoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _removeMedicinePhoto,
                    ),
                  ),
                ),
                if (_isUploadingPhoto)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_medicinePhotoUrl != null && !_isUploadingPhoto)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Photo uploaded successfully",
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingPhoto ? null : () => _pickMedicinePhoto(fromCamera: true),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lavender.withOpacity(0.1),
                      foregroundColor: lavender,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingPhoto ? null : () => _pickMedicinePhoto(fromCamera: false),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lavender.withOpacity(0.1),
                      foregroundColor: lavender,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _saveMedicine() {
    if (nameController.text.trim().isEmpty) {
      _showError("Please enter medicine name");
      return;
    }

    final intakeSelected = intakeMap.values.any((selected) => selected == true);
    if (!intakeSelected && customTimes.isEmpty) {
      _showError("Please select at least one intake time or add a custom time");
      return;
    }

    final duration = int.tryParse(durationController.text);
    if (duration == null || duration <= 0) {
      _showError("Duration must be greater than 0 days");
      return;
    }

    if (medicineType == "tablet" && doseCount < 1) {
      _showError("Tablet count must be at least 1");
      return;
    }

    if (medicineType == "syrup" && doseCount < 5) {
      _showError("Syrup quantity must be at least 5 ml");
      return;
    }

    final intakeTimes = intakeMap.entries.where((e) => e.value).map((e) => e.key).toList();

    final updatedMedicine = {
      "name": nameController.text.trim(),
      "type": medicineType,
      "intakeTimes": intakeTimes,
      "customTimes": customTimes.map((t) => t.format(context)).toList(),
      "frequency": frequency,
      "doseCount": doseCount,
      "isCritical": isCritical,
      "durationDays": duration,
      "photoUrl": _medicinePhotoUrl,
    };

    widget.onSave(updatedMedicine);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Medication updated!"),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickCustomTime({int? editIndex}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: editIndex != null ? customTimes[editIndex] : TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: lavender,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2D3142),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (editIndex != null) {
          customTimes[editIndex] = picked;
        } else {
          customTimes.add(picked);
        }
      });
    }
  }

  Widget _buildMealSection(String title) {
    String beforeKey = "Before $title";
    String afterKey = "After $title";

    bool beforeSelected = intakeMap[beforeKey] == true;
    bool afterSelected = intakeMap[afterKey] == true;

    Widget pill({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? lavender : const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? lavender : const Color(0xFFE0E0E0),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF2D3142),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                title == "Breakfast"
                    ? Icons.breakfast_dining
                    : title == "Lunch"
                    ? Icons.lunch_dining
                    : Icons.dinner_dining,
                color: lavender,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF2D3142),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              pill(
                label: "Before Meal",
                selected: beforeSelected,
                onTap: () {
                  setState(() {
                    intakeMap[beforeKey] = !beforeSelected;
                  });
                },
              ),
              const SizedBox(width: 12),
              pill(
                label: "After Meal",
                selected: afterSelected,
                onTap: () {
                  setState(() {
                    intakeMap[afterKey] = !afterSelected;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Edit Medication',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: lavender,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// PHOTO SECTION
            _buildPhotoSection(),
            const SizedBox(height: 24),

            /// Name
            const Text(
              "Medicine Name",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: lavender, width: 2),
                ),
                hintText: "Enter medicine name",
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.medication, color: lavender),
              ),
            ),
            const SizedBox(height: 20),

            /// Type
            const Text(
              "Medicine Type",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: medicineType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.category, color: lavender),
              ),
              items: const [
                DropdownMenuItem(value: "tablet", child: Text("Tablet")),
                DropdownMenuItem(value: "syrup", child: Text("Syrup")),
                DropdownMenuItem(value: "other", child: Text("Other")),
              ],
              onChanged: (v) => setState(() {
                medicineType = v!;
                doseCount = v == "syrup" ? 5 : 1;
              }),
            ),
            const SizedBox(height: 20),

            /// Intake Times
            const Text(
              "Time of Intake",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 12),
            _buildMealSection("Breakfast"),
            _buildMealSection("Lunch"),
            _buildMealSection("Dinner"),
            const SizedBox(height: 16),

            /// Custom Times
            ElevatedButton.icon(
              onPressed: () => _pickCustomTime(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Add Custom Time"),
              style: ElevatedButton.styleFrom(
                backgroundColor: lavender.withOpacity(0.1),
                foregroundColor: lavender,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),

            for (int i = 0; i < customTimes.length; i++)
              ListTile(
                leading: const Icon(Icons.access_time, color: lavender),
                title: Text(customTimes[i].format(context)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: lavender),
                      onPressed: () => _pickCustomTime(editIndex: i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => setState(() => customTimes.removeAt(i)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            /// Frequency
            const Text(
              "Frequency",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: frequency,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.repeat, color: lavender),
              ),
              items: ["Daily", "Alternate Days"]
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => frequency = v!),
            ),

            const SizedBox(height: 20),

            /// Duration
            const Text(
              "Duration (days)",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: lavender, width: 2),
                ),
                hintText: "e.g. 7",
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.calendar_today, color: lavender),
              ),
            ),
            const SizedBox(height: 20),

            /// Dose
            if (medicineType != "other") ...[
              Text(
                medicineType == "tablet" ? "Dosage" : "Quantity",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: lavender),
                    onPressed: () {
                      if ((medicineType == "tablet" && doseCount > 1) ||
                          (medicineType == "syrup" && doseCount > 5)) {
                        setState(() {
                          doseCount -= medicineType == "syrup" ? 5 : 1;
                        });
                      }
                    },
                  ),
                  Text(
                    medicineType == "tablet" ? "$doseCount" : "$doseCount ml",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: lavender),
                    onPressed: () => setState(() {
                      doseCount += medicineType == "syrup" ? 5 : 1;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            /// Critical
            CheckboxListTile(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFE57373)),
                  SizedBox(width: 12),
                  Text("Critical Medication"),
                ],
              ),
              value: isCritical,
              onChanged: (v) => setState(() => isCritical = v!),
              activeColor: const Color(0xFFE57373),
            ),

            const SizedBox(height: 32),

            /// Save Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saveMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: lavender,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class MultipleMedicinesScreen extends StatefulWidget {
  @override
  State<MultipleMedicinesScreen> createState() => _MultipleMedicinesScreenState();
}

class _MultipleMedicinesScreenState extends State<MultipleMedicinesScreen> {
  static const Color lavender = Color(0xFFB39DDB);

  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _extractedMedicines = [];
  bool _isProcessing = false;
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Add Multiple Medications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: lavender,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// UPLOAD SECTION
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lavender, lavender.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: lavender.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFilePath != null
                        ? Icons.check_circle_outline
                        : Icons.upload_file,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFilePath != null
                        ? 'File Selected: $_selectedFileName'
                        : 'Upload prescription image or PDF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: lavender,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _pickGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: lavender,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickPDF,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Choose PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: lavender,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedFilePath != null && !_isProcessing) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _processFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lavender,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Extract Medications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            if (_isProcessing) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(lavender),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Processing prescription...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_extractedMedicines.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(thickness: 1, color: Color(0xFFE0E0E0)),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Extracted Medications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: lavender.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_extractedMedicines.length} found',
                      style: const TextStyle(
                        color: lavender,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _extractedMedicines.length,
                itemBuilder: (context, index) {
                  return _buildMedicineCard(_extractedMedicines[index], index);
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveAllMedications,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lavender,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    shadowColor: lavender.withOpacity(0.3),
                    elevation: 4,
                  ),
                  child: Text(
                    'Save All ${_extractedMedicines.length} Medications',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine, int index) {
    final intakeTimes = medicine['intakeTimes'] as List? ?? [];
    final customTimes = medicine['customTimes'] as List? ?? [];
    final photoUrl = medicine['photoUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lavender.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medication, color: lavender, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  medicine['name'] ?? 'Unknown Medicine',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: lavender),
                onPressed: () => _editMedicine(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFE57373)),
                onPressed: () => _deleteMedicine(index),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Medicine Photo if available
          if (photoUrl != null && photoUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                photoUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          _buildInfoRow(Icons.category, 'Type', _formatType(medicine['type'])),

          if (intakeTimes.isNotEmpty)
            _buildInfoRow(Icons.restaurant, 'Meal Times', intakeTimes.join(', ')),

          if (customTimes.isNotEmpty)
            _buildInfoRow(Icons.access_time, 'Custom Times', customTimes.join(', ')),

          _buildInfoRow(Icons.repeat, 'Frequency', medicine['frequency'] ?? 'Daily'),

          _buildInfoRow(Icons.timelapse, 'Duration', '${medicine['durationDays'] ?? 7} days'),

          if (medicine['type'] == 'tablet')
            _buildInfoRow(Icons.medical_services, 'Dosage', '${medicine['doseCount'] ?? 1} tablet(s)'),
          if (medicine['type'] == 'syrup')
            _buildInfoRow(Icons.water_drop, 'Quantity', '${medicine['doseCount'] ?? 5} ml'),
          if (medicine['type'] == 'other')
            _buildInfoRow(Icons.local_hospital, 'Dose Count', '${medicine['doseCount'] ?? 1}'),

          if (medicine['isCritical'] == true)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE57373)),
                  SizedBox(width: 6),
                  Text(
                    'Critical Medication',
                    style: TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontFamily: 'Roboto',
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2D3142),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatType(String? type) {
    if (type == null) return 'Tablet';
    return type[0].toUpperCase() + type.substring(1);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedFilePath = image.path;
        _selectedFileName = image.name;
      });
    }
  }

  Future<void> _pickGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedFilePath = image.path;
        _selectedFileName = image.name;
      });
    }
  }

  Future<void> _pickPDF() async {
    const XTypeGroup pdfType = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
    );

    final XFile? file = await openFile(
      acceptedTypeGroups: [pdfType],
    );

    if (file != null) {
      setState(() {
        _selectedFilePath = file.path;
        _selectedFileName = file.name;
      });
    }
  }


  Future<void> _processFile() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isProcessing = true;
      _extractedMedicines.clear();
    });

    try {
      final medicines = await MultipleMedicineService.extractFromFile(_selectedFilePath!);

      if (medicines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No medications found in the prescription'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _extractedMedicines = medicines;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${medicines.length} medication(s)! Review and save.'),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _editMedicine(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMedicineScreen(
          medicine: _extractedMedicines[index],
          onSave: (updatedMedicine) {
            setState(() {
              _extractedMedicines[index] = updatedMedicine;
            });
          },
        ),
      ),
    );
  }

  void _deleteMedicine(int index) {
    setState(() {
      _extractedMedicines.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Medication removed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  bool _validateMedicine(Map<String, dynamic> medicine) {
    if (medicine['name'] == null || medicine['name'].toString().trim().isEmpty) {
      return false;
    }

    final intakeTimes = medicine['intakeTimes'] as List? ?? [];
    final customTimes = medicine['customTimes'] as List? ?? [];

    if (intakeTimes.isEmpty && customTimes.isEmpty) {
      return false;
    }

    final duration = medicine['durationDays'] as int?;
    if (duration == null || duration <= 0) {
      return false;
    }

    final doseCount = medicine['doseCount'] as int? ?? 0;
    if (medicine['type'] == 'tablet' && doseCount < 1) {
      return false;
    }
    if (medicine['type'] == 'syrup' && doseCount < 5) {
      return false;
    }

    return true;
  }

  Future<void> _saveAllMedications() async {
    if (_extractedMedicines.isEmpty) return;

    List<String> invalidMedicines = [];
    for (int i = 0; i < _extractedMedicines.length; i++) {
      if (!_validateMedicine(_extractedMedicines[i])) {
        invalidMedicines.add(_extractedMedicines[i]['name'] ?? 'Medicine ${i + 1}');
      }
    }

    if (invalidMedicines.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid data in: ${invalidMedicines.join(', ')}. Please edit and fix.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(lavender),
        ),
      ),
    );

    int successCount = 0;
    int failCount = 0;

    for (var medicine in _extractedMedicines) {
      try {
        medicine['createdAt'] = DateTime.now().toIso8601String();
        await MultipleMedicineService.addMedication(medicine);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint('Failed to save ${medicine['name']}: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context);

      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully saved all $successCount medication(s)!'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $successCount, Failed $failCount medication(s)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}