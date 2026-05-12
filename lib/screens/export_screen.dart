import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/patient_profile.dart';
import '../models/vital_reading.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  final PatientProfile profile;
  const ExportScreen({super.key, required this.profile});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _dbService = DatabaseService();
  final _exportService = ExportService();

  List<VitalReading>? _readings;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    final r = await _dbService.getAllReadings();
    setState(() => _readings = r);
  }

  Future<void> _export() async {
    final readings = _readings;
    if (readings == null || readings.isEmpty) {
      _showSnack('No readings to export.', error: true);
      return;
    }

    setState(() => _exporting = true);
    try {
      await _exportService.exportAndShare(
        profile: widget.profile,
        readings: readings,
      );
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.danger : AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    final totalReadings = readings?.length ?? 0;
    final riskCount = readings?.where((r) => r.isRisk).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.15),
                    radius: 28,
                    child: Text(
                      widget.profile.name.isNotEmpty
                          ? widget.profile.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile.name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Age ${widget.profile.age}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Reading summary
            const Text(
              'EXPORT SUMMARY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _summaryCard(readings),
            const SizedBox(height: 20),
            // What's included
            const Text(
              "WHAT'S INCLUDED",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _includesCard(),
            const SizedBox(height: 20),
            // Security note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_rounded,
                      color: AppTheme.warning, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Your data is encrypted with AES-256 before export. Only the doctor\'s dashboard can read it.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (totalReadings == 0 || _exporting)
                    ? null
                    : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.share_rounded),
                label: Text(_exporting
                    ? 'Preparing export...'
                    : 'Export & Share with Doctor'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (totalReadings == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'No readings available yet. Connect to the device first.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(List<VitalReading>? readings) {
    final total = readings?.length ?? 0;
    final risk = readings?.where((r) => r.isRisk).length ?? 0;
    final ok = total - risk;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          _statChip('$total', 'Readings', AppTheme.primary),
          const SizedBox(width: 8),
          _statChip('$ok', 'Normal', AppTheme.success),
          const SizedBox(width: 8),
          _statChip('$risk', 'Risk', AppTheme.danger),
        ],
      ),
    );
  }

  Widget _statChip(String val, String lbl, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(val,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color)),
              Text(lbl,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );

  Widget _includesCard() {
    final items = [
      (Icons.person_outline_rounded, 'Patient name and age'),
      (Icons.favorite_rounded, 'All heart rate readings'),
      (Icons.thermostat_rounded, 'All temperature readings'),
      (Icons.air_rounded, 'All SpO₂ readings'),
      (Icons.access_time_rounded, 'Timestamps for each reading'),
      (Icons.warning_amber_rounded, 'Risk/OK status per reading'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(item.$1, size: 16, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(item.$2,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textPrimary)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
