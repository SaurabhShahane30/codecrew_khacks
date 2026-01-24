import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

import '../services/alarm_service.dart';

/// =======================
/// BACKEND SERVICE
/// =======================
class MedicationService {
  static const String MAIN_BACKEND = 'http://10.21.9.41:5000';
  static const String VOICE_SERVER = 'http://10.21.0.139:5001';

  // Cloudinary configuration - REPLACE WITH YOUR VALUES
  static final cloudinary = CloudinaryPublic(
    'djqbzwhet',  // Replace with your Cloudinary cloud name
    'medicine_photos',  // Replace with your upload preset
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

  static Future<void> addMedication(Map<String, dynamic> medicationData) async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final response = await http.post(
        Uri.parse('$MAIN_BACKEND/api/medicine/add'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(medicationData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Medication added successfully");
      } else {
        throw Exception("Failed to add medication");
      }
    } catch (e) {
      debugPrint("Error adding medication: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> processVoiceInput(String audioPath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$VOICE_SERVER/api/medicine/process-voice'),
      );

      request.files.add(await http.MultipartFile.fromPath('audio', audioPath));

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return jsonDecode(responseData);
      } else {
        throw Exception("Failed to process voice input");
      }
    } catch (e) {
      debugPrint("Error processing voice: $e");
      rethrow;
    }
  }
}

/// =======================
/// UI SCREEN
/// =======================
class AddMedicationScreen extends StatefulWidget {
  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Photo upload state
  File? _medicinePhoto;
  String? _medicinePhotoUrl;
  bool _isUploadingPhoto = false;

  static const Color lavender = Color(0xFFB39DDB);

  String medicineType = "tablet";
  Map<String, bool> intakeMap = {
    "Before Breakfast": false,
    "After Breakfast": false,
    "Before Lunch": false,
    "After Lunch": false,
    "Before Dinner": false,
    "After Dinner": false,
  };
  List<TimeOfDay> customTimes = [];
  String frequency = "Daily";
  int doseCount = 1;
  bool isCritical = false;

  // Voice recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _recordingPath;

  @override
  void dispose() {
    _audioRecorder.dispose();
    nameController.dispose();
    durationController.dispose();
    super.dispose();
  }

  /// Pick medicine photo
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

        // Upload to Cloudinary
        final url = await MedicationService.uploadMedicinePhoto(_medicinePhoto!);

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

  /// Remove medicine photo
  void _removeMedicinePhoto() {
    setState(() {
      _medicinePhoto = null;
      _medicinePhotoUrl = null;
    });
  }

  bool validateForm() {
    if (nameController.text.trim().isEmpty) {
      showError("Please enter medicine name");
      return false;
    }

    final intakeSelected = intakeMap.values.any((selected) => selected == true);
    if (!intakeSelected && customTimes.isEmpty) {
      showError("Please select at least one intake time or add a custom time");
      return false;
    }

    final duration = int.tryParse(durationController.text);
    if (duration == null || duration <= 0) {
      showError("Duration must be greater than 0 days");
      return false;
    }

    if (medicineType == "tablet" && doseCount < 1) {
      showError("Tablet count must be at least 1");
      return false;
    }

    if (medicineType == "syrup" && doseCount < 5) {
      showError("Syrup quantity must be at least 5 ml");
      return false;
    }

    return true;
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });

      if (path != null) {
        await processRecording(path);
      }
    } else {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission required")),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/medication_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> processRecording(String audioPath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await MedicationService.processVoiceInput(audioPath);

      setState(() {
        nameController.text = result['name'] ?? '';
        medicineType = result['type'] ?? 'tablet';
        doseCount = result['doseCount'] ?? (medicineType == 'syrup' ? 5 : 1);
        frequency = result['frequency'] ?? 'Daily';
        isCritical = result['isCritical'] ?? false;
        durationController.text = (result['durationDays'] ?? 7).toString();

        intakeMap.forEach((key, value) {
          intakeMap[key] = false;
        });
        final intakeTimes = result['intakeTimes'] as List? ?? [];
        for (var time in intakeTimes) {
          if (intakeMap.containsKey(time)) {
            intakeMap[time] = true;
          }
        }

        customTimes.clear();
        final customTimeStrings = result['customTimes'] as List? ?? [];
        for (var timeStr in customTimeStrings) {
          try {
            final parts = timeStr.toString().split(':');
            if (parts.length == 2) {
              customTimes.add(TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              ));
            }
          } catch (e) {
            debugPrint("Error parsing time: $e");
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Voice input processed! Review and edit if needed."),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error processing voice: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> pickCustomTime({int? editIndex}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: editIndex != null
          ? customTimes[editIndex]
          : TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: lavender,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF2D3142),
              ),
            ),
            child: child!,
          ),
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

  void saveMedication() async {
    if (!validateForm()) return;

    final intakeTimes = intakeMap.entries.where((e) => e.value).map((e) => e.key).toList();

    final medicationData = {
      "name": nameController.text.trim(),
      "type": medicineType,
      "intakeTimes": intakeTimes,
      "customTimes": customTimes.map((t) => t.format(context)).toList(),
      "frequency": frequency,
      "doseCount": doseCount,
      "isCritical": isCritical,
      "durationDays": int.parse(durationController.text),
      "photoUrl": _medicinePhotoUrl,
      "createdAt": DateTime.now().toIso8601String(),
    };

    try {
      await MedicationService.addMedication(medicationData);
      await AlarmService.syncAndScheduleAlarms();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Medication & alarms scheduled"),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );

      Navigator.pop(context);
    } catch (e, stackTrace) {
      debugPrint("❌ SAVE MEDICATION ERROR: $e");
      debugPrint("📌 STACK TRACE: $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save medication: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget buildMealSection(String title) {
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
                onTap: () => setState(() => intakeMap[beforeKey] = !beforeSelected),
              ),
              const SizedBox(width: 12),
              pill(
                label: "After Meal",
                selected: afterSelected,
                onTap: () => setState(() => intakeMap[afterKey] = !afterSelected),
              ),
            ],
          ),
        ],
      ),
    );
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

          if (_medicinePhoto != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _medicinePhoto!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
            if (_medicinePhotoUrl != null)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Add Medication",
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
            /// VOICE INPUT BUTTON
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [const Color(0xFFE57373), const Color(0xFFEF5350)]
                      : [lavender, lavender.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? const Color(0xFFE57373) : lavender).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRecording
                        ? "Recording... Tap to stop"
                        : _isProcessing
                        ? "Processing..."
                        : "Tap to add medication by voice",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : toggleRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? "Stop Recording" : "Start Recording"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: lavender,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(thickness: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 24),

            /// MEDICINE PHOTO SECTION
            _buildPhotoSection(),
            const SizedBox(height: 28),

            /// Name Section
            const Text(
              "Medicine Name",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: nameController,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: lavender, width: 2),
                  ),
                  hintText: "Enter medicine name",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.medication, color: lavender),
                ),
              ),
            ),

            const SizedBox(height: 28),

            /// Medicine Type Section
            const Text(
              "Medicine Type",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            Container(
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
              child: DropdownButtonFormField<String>(
                value: medicineType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                dropdownColor: Colors.white,
              ),
            ),

            const SizedBox(height: 28),

            /// Intake Section
            const Text(
              "Time of Intake",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 12),
            buildMealSection("Breakfast"),
            buildMealSection("Lunch"),
            buildMealSection("Dinner"),

            const SizedBox(height: 20),

            /// Custom Time Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: lavender.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: lavender.withOpacity(0.3)),
              ),
              child: TextButton.icon(
                onPressed: () => pickCustomTime(),
                icon: const Icon(Icons.add_circle_outline, color: lavender),
                label: const Text(
                  "Add Custom Time",
                  style: TextStyle(color: lavender, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 8),

            for (int i = 0; i < customTimes.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lavender.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.access_time, color: lavender, size: 20),
                  ),
                  title: Text(
                    customTimes[i].format(context),
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2D3142)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: lavender),
                        onPressed: () => pickCustomTime(editIndex: i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFE57373)),
                        onPressed: () => setState(() => customTimes.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),

            /// Frequency Section
            const Text(
              "Frequency",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            Container(
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
              child: DropdownButtonFormField<String>(
                value: frequency,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.repeat, color: lavender),
                ),
                items: ["Daily", "Alternate Days"]
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => frequency = v!),
                dropdownColor: Colors.white,
              ),
            ),

            const SizedBox(height: 28),

            /// Duration Section
            const Text(
              "Duration (days)",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: lavender, width: 2),
                  ),
                  hintText: "e.g. 7",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.calendar_today, color: lavender),
                ),
              ),
            ),

            const SizedBox(height: 28),

            /// Dose Section
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
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          medicineType == "tablet"
                              ? Icons.medical_services_outlined
                              : Icons.water_drop_outlined,
                          color: lavender,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          medicineType == "tablet" ? "Number of Tablets" : "Quantity (ml)",
                          style: const TextStyle(fontSize: 15, color: Color(0xFF2D3142)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: lavender.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove, color: lavender),
                            onPressed: (medicineType == "tablet" && doseCount > 1) ||
                                (medicineType == "syrup" && doseCount > 5)
                                ? () => setState(() {
                              if (medicineType == "syrup") {
                                doseCount -= 5;
                              } else {
                                doseCount--;
                              }
                            })
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            medicineType == "tablet" ? "$doseCount" : "$doseCount ml",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: lavender.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: lavender),
                            onPressed: () => setState(() {
                              if (medicineType == "syrup") {
                                doseCount += 5;
                              } else {
                                doseCount++;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Container(
              decoration: BoxDecoration(
                color: isCritical ? const Color(0xFFFFEBEE) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isCritical ? const Color(0xFFE57373) : const Color(0xFFE0E0E0)),
              ),
              child: CheckboxListTile(
                title: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: isCritical ? const Color(0xFFE57373) : Colors.grey,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Critical Medication",
                      style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2D3142)),
                    ),
                  ],
                ),
                value: isCritical,
                onChanged: (v) => setState(() => isCritical = v!),
                activeColor: const Color(0xFFE57373),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),

            const SizedBox(height: 32),

            /// Save Button
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: lavender,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: lavender.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: saveMedication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Save Medication",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}