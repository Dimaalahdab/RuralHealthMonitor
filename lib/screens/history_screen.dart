import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app_theme.dart';
import '../../../models/patient_profile.dart';
import '../../../models/vital_reading.dart';
import '../../../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  final PatientProfile profile;
  const HistoryScreen({super.key, required this.profile});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _dbService = DatabaseService();
  List<VitalReading>? _readings;

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    final readings = await _dbService.getAllReadings();
    setState(() => _readings = readings);
  }

  String _formatTime(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp);
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return isoTimestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    final riskCount = readings?.where((r) => r.isRisk).length ?? 0;
    final totalCount = readings?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reading History'),
            Text(
              widget.profile.name,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReadings,
          ),
        ],
      ),
      body: readings == null
          ? const Center(child: CircularProgressIndicator())
          : readings.isEmpty
              ? _EmptyState()
              : Column(
                  children: [
                    _SummaryBar(
                        total: totalCount,
                        risk: riskCount,
                        name: widget.profile.name),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadReadings,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: readings.length,
                          itemBuilder: (ctx, i) =>
                              _ReadingRow(reading: readings[i], formatTime: _formatTime),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int total;
  final int risk;
  final String name;

  const _SummaryBar(
      {required this.total, required this.risk, required this.name});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (risk / total * 100).toStringAsFixed(0) : '0';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          _stat('$total', 'Total', AppTheme.primary),
          _divider(),
          _stat('$risk', 'Risk', AppTheme.danger),
          _divider(),
          _stat('$pct%', 'Risk Rate',
              risk == 0 ? AppTheme.success : AppTheme.warning),
        ],
      ),
    );
  }

  Widget _stat(String val, String lbl, Color color) => Expanded(
        child: Column(
          children: [
            Text(val,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(lbl,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      );

  Widget _divider() => Container(
      width: 1, height: 32, color: AppTheme.cardBorder, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _ReadingRow extends StatelessWidget {
  final VitalReading reading;
  final String Function(String) formatTime;

  const _ReadingRow({required this.reading, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final risk = reading.isRisk;
    final accent = risk ? AppTheme.danger : AppTheme.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: risk ? AppTheme.danger.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: risk
              ? AppTheme.danger.withOpacity(0.25)
              : AppTheme.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(
                risk ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Vitals
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(reading.timestamp),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip('❤ ${reading.hr.toInt()} bpm', risk && (reading.hr > 110 || reading.hr < 50)),
                      const SizedBox(width: 6),
                      _chip('🌡 ${reading.temp.toStringAsFixed(1)}°', risk && reading.temp > 38),
                      const SizedBox(width: 6),
                      _chip('💨 ${reading.spo2.toInt()}%', risk && reading.spo2 < 94),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                risk ? 'RISK' : 'OK',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, bool highlight) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: highlight
              ? AppTheme.danger.withOpacity(0.08)
              : AppTheme.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: highlight ? AppTheme.danger.withOpacity(0.2) : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: highlight ? AppTheme.danger : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.show_chart_rounded,
                color: AppTheme.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'No readings yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connect to the device and start monitoring\nto see your readings here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
