import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/patient_profile.dart';
import '../models/vital_reading.dart';
import '../services/database_service.dart';

class HistoryBody extends StatefulWidget {
  final PatientProfile profile;
  const HistoryBody({super.key, required this.profile});

  @override
  State<HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<HistoryBody> {
  final _db = DatabaseService();
  List<VitalReading> _readings = [];
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _db.getAllReadings();
      if (!mounted) return;
      setState(() { _readings = rows; _showAll = false; });
    } catch (_) {
      // sqflite not available on web — readings stay empty
    }
  }

  String _fmt(String iso) {
    try {
      final dt    = DateTime.parse(iso);
      final today = DateTime.now();
      final isToday = dt.year == today.year && dt.month == today.month && dt.day == today.day;
      return '${isToday ? "Today" : DateFormat("MMM d").format(dt)} · ${DateFormat("HH:mm").format(dt)}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final total = _readings.length;
    final risk  = _readings.where((r) => r.isRisk).length;
    final shown = _showAll ? _readings : _readings.take(5).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Purple header ───────────────────────────────────────────
          Container(
            color: AppTheme.purple,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(children: [
                  const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Reading',  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
                    Text('history',  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
                  ]),
                ]),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: _readings.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Summary cards
                        Row(children: [
                          Expanded(child: _summaryCard('Total\nreadings', '$total', AppTheme.purple)),
                          const SizedBox(width: 12),
                          Expanded(child: _summaryCard('Risk\nevents', '$risk', AppTheme.danger)),
                        ]),
                        const SizedBox(height: 12),
                        const Text('Most recent first', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        ...shown.map(_readingRow),
                        if (!_showAll && _readings.length > 5)
                          TextButton(
                            onPressed: () => setState(() => _showAll = true),
                            child: Text('Show all $total readings',
                                style: const TextStyle(color: AppTheme.purple, fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppTheme.purple.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.show_chart_rounded, color: AppTheme.purple.withOpacity(0.4), size: 38),
          ),
          const SizedBox(height: 20),
          const Text('No readings yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Readings will appear here once you connect to the device and start a monitoring session.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.purple,
              side: const BorderSide(color: AppTheme.purple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _summaryCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.cardBorder)),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.3))),
      Text(value, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: color)),
    ]),
  );

  Widget _readingRow(VitalReading r) {
    final risk = r.isRisk;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fmt(r.timestamp), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text('HR ${r.hr.toInt()} · ${r.temp.toStringAsFixed(1)}°C · SpO2 ${r.spo2.toInt()}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: risk ? AppTheme.danger : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: risk ? AppTheme.danger : AppTheme.success, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!risk)
              Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.success)),
            Text(risk ? '● RISK' : 'OK',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: risk ? Colors.white : AppTheme.success)),
          ]),
        ),
      ]),
    );
  }
}