import 'package:flutter/material.dart';
import 'package:khacks_app/core/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientOverviewScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientOverviewScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientOverviewScreen> createState() => _PatientOverviewScreenState();
}

class _PatientOverviewScreenState extends State<PatientOverviewScreen> {
  /// 🔗 Opens the detailed report website in Chrome
  Future<void> _openDetailedReport() async {
    final Uri url = Uri.parse(
      "http://10.21.11.24:5173/?patientId=${widget.patientId}",
    );
    // 👆 Web dashboard reads patientId from query param

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not open detailed report');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: Text(widget.patientName),
        backgroundColor: AppTheme.lavender,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _infoCard(
              title: "OVERALL ADHERENCE",
              value: "92%",
              subtitle: "Last 7 days",
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _smallCard("RISK LEVEL", "Low Risk"),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _smallCard("MISSED DOSES", "3"),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _aiSummaryCard(),

            const Spacer(),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lavender,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _openDetailedReport,
              child: const Text("View Detailed Report"),
            ),

            const SizedBox(height: 8),
            const Text(
              "Opens in web dashboard",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- UI CARDS --------------------

  Widget _infoCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallCard(String title, String value) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiSummaryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.auto_awesome, color: AppTheme.lavender),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Patient shows excellent adherence patterns with consistent morning medication intake. Minor delays observed during weekends. Overall compliance is well above target thresholds.",
                style: TextStyle(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}