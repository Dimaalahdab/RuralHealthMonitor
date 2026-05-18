// lib/screens/dashboard_screen.dart
// UPDATED: Bluetooth wired into LiveDashboard.
// Only LiveDashboard changed — everything else (tabs, nav, history, export) is identical.

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/patient_profile.dart';
import '../models/vital_reading.dart';
import '../services/database_service.dart';
import '../services/bluetooth_service.dart';
import 'history_screen.dart';
import 'export_screen.dart';

class DashboardScreen extends StatefulWidget {
  final PatientProfile profile;
  final int initialTab;
  const DashboardScreen({super.key, required this.profile, this.initialTab = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late int _currentTab;

  @override
  void initState() { super.initState(); _currentTab = widget.initialTab; }

  void _goTab(int i) => setState(() => _currentTab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(children: [
        _tab(0, LiveDashboard(profile: widget.profile)),
        _tab(1, HistoryBody(profile: widget.profile)),
        _tab(2, ExportBody(profile: widget.profile)),
      ]),
      bottomNavigationBar: _AppBottomNav(currentIndex: _currentTab, onTap: _goTab),
    );
  }

  Widget _tab(int i, Widget child) => Offstage(offstage: _currentTab != i, child: child);
}

// ── Bottom nav — unchanged ─────────────────────────────────────────────────────
class _AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _AppBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            _NavItem(icon: Icons.grid_view_rounded,      label: 'Dashboard', selected: currentIndex == 0, onTap: () => onTap(0)),
            _NavItem(icon: Icons.calendar_month_rounded, label: 'History',   selected: currentIndex == 1, onTap: () => onTap(1)),
            _NavItem(icon: Icons.upload_rounded,         label: 'Export',    selected: currentIndex == 2, onTap: () => onTap(2)),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.purple : AppTheme.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: color)),
        ]),
      ),
    );
  }
}

// ── Live Dashboard — UPDATED with real Bluetooth ──────────────────────────────
class LiveDashboard extends StatefulWidget {
  final PatientProfile profile;
  const LiveDashboard({super.key, required this.profile});

  @override
  State<LiveDashboard> createState() => _LiveDashboardState();
}

class _LiveDashboardState extends State<LiveDashboard> {
  final _bt = BluetoothService();
  final List<double> _history = [];
  bool _connecting = false;
  String? _btError;

  @override
  void initState() {
    super.initState();
    _bt.addListener(_onBtUpdate);
  }

  @override
  void dispose() {
    _bt.removeListener(_onBtUpdate);
    super.dispose();
  }

  void _onBtUpdate() {
    if (!mounted) return;
    final latest = _bt.latest;
    if (latest != null && latest.hr > 0) {
      _history.add(latest.hr);
      if (_history.length > 8) _history.removeAt(0);
    }
    setState(() {});
  }

  Future<void> _scan() async {
    setState(() { _connecting = true; _btError = null; });
    final error = await _bt.connect();
    if (!mounted) return;
    setState(() { _connecting = false; _btError = error; });
  }

  @override
  Widget build(BuildContext context) {
    final connected = _bt.isConnected;
    final latest    = _bt.latest;
    final isRisk    = latest?.isRisk ?? false;

    final initials = widget.profile.name.trim().split(' ')
        .where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Purple header ─────────────────────────────────────────
          Container(
            color: AppTheme.purple,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(children: [
                  const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Health',  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
                      Text('Monitor', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
                    ]),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Text(initials.isEmpty ? '?' : initials,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Connection card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.cardBorder)),
                    child: Row(children: [
                      CircleAvatar(radius: 4, backgroundColor: connected ? AppTheme.success : const Color(0xFFADB5BD)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(connected ? 'HealthMonitor connected' : 'ESP32 not connected',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(connected ? 'Live · every 2s' : (_btError ?? 'Tap SCAN to connect'),
                              style: TextStyle(fontSize: 11, color: _btError != null ? AppTheme.danger : AppTheme.textSecondary)),
                        ]),
                      ),
                      GestureDetector(
                        onTap: connected ? _bt.disconnect : (_connecting ? null : _scan),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: AppTheme.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: _connecting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.purple))
                              : Text(connected ? 'DISCONNECT' : 'SCAN',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.purple)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Status row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current status', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      if (latest != null)
                        _statusPill(isRisk)
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(20)),
                          child: const Text('—', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Vital cards
                  Row(children: [
                    Expanded(child: _vCard('Heart rate', latest != null && latest.hr > 0 ? '${latest.hr.toInt()}' : '--', 'BPM',
                        AppTheme.danger, latest != null && isRisk && (latest.hr > 110 || latest.hr < 50))),
                    const SizedBox(width: 12),
                    Expanded(child: _vCard('Temperature', latest != null && latest.temp > 0 ? latest.temp.toStringAsFixed(1) : '--', '°C',
                        AppTheme.purple, latest != null && isRisk && latest.temp > 38, large: true)),
                  ]),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: _vCard('SpO2', latest != null && latest.spo2 > 0 ? '${latest.spo2.toInt()}' : '--', '%',
                        AppTheme.primary, latest != null && isRisk && latest.spo2 < 94)),
                    const SizedBox(width: 12),
                    Expanded(child: _statusCard(latest, isRisk)),
                  ]),
                  const SizedBox(height: 16),

                  if (_history.isNotEmpty) _barChart(),

                  if (latest == null) ...[
                    const SizedBox(height: 24),
                    _notConnectedHint(connected),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool isRisk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: (isRisk ? AppTheme.danger : AppTheme.success).withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (isRisk ? AppTheme.danger : AppTheme.success).withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: isRisk ? AppTheme.danger : AppTheme.success)),
      const SizedBox(width: 5),
      Text(isRisk ? 'Risk' : 'Normal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isRisk ? AppTheme.danger : AppTheme.success)),
    ]),
  );

  Widget _vCard(String label, String value, String unit, Color color, bool risk, {bool large = false}) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: risk ? AppTheme.danger.withOpacity(0.4) : AppTheme.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, style: TextStyle(
              fontSize: large ? 38 : 34, fontWeight: FontWeight.w700, height: 1,
              color: value == '--' ? AppTheme.cardBorder : (risk ? AppTheme.danger : color))),
          const SizedBox(width: 3),
          Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Text(unit, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        ]),
      ]),
    );

  Widget _statusCard(VitalReading? latest, bool isRisk) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Status', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      if (latest == null)
        const Text('--', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.cardBorder))
      else ...[
        Row(children: [
          CircleAvatar(radius: 5, backgroundColor: isRisk ? AppTheme.danger : AppTheme.success),
          const SizedBox(width: 8),
          Text(isRisk ? 'RISK' : 'OK', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: isRisk ? AppTheme.danger : AppTheme.success)),
        ]),
        const SizedBox(height: 2),
        Text(isRisk ? 'Risk detected' : 'No risk', style: TextStyle(fontSize: 12, color: isRisk ? AppTheme.danger : AppTheme.success)),
      ],
    ]),
  );

  Widget _barChart() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Heart rate — last 8 readings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
      const SizedBox(height: 12),
      SizedBox(height: 60, child: CustomPaint(painter: _BarPainter(values: _history), size: const Size(double.infinity, 60))),
    ]),
  );

  Widget _notConnectedHint(bool connected) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.purple.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.purple.withOpacity(0.15)),
    ),
    child: Column(children: [
      Icon(Icons.bluetooth_searching_rounded, color: AppTheme.purple.withOpacity(0.4), size: 40),
      const SizedBox(height: 12),
      Text(connected ? 'Waiting for readings...' : 'No device connected',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      const SizedBox(height: 6),
      Text(
        connected
          ? 'Place your finger on the sensor.\nReadings will appear here in ~15 seconds.'
          : 'Tap SCAN to connect to your HealthMonitor device.\nMake sure it is paired in phone Bluetooth settings first.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
      ),
    ]),
  );
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  _BarPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    final barW = (size.width / values.length) * 0.6;
    final gap  = (size.width / values.length) * 0.4;
    for (int i = 0; i < values.length; i++) {
      final ratio  = values[i] / maxV;
      final isHigh = values[i] > 100 || values[i] < 50;
      final isLast = i == values.length - 1;
      final paint  = Paint()
        ..color = isHigh ? AppTheme.danger : isLast ? AppTheme.purple : AppTheme.purple.withOpacity(0.45)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * (barW + gap) + gap / 2, size.height - ratio * size.height, barW, ratio * size.height), const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.values != values;
}
