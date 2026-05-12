import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../app_theme.dart';
import '../models/patient_profile.dart';
import '../models/vital_reading.dart';
import '../services/database_service.dart';
import 'history_screen.dart';
import 'export_screen.dart';

class DashboardScreen extends StatefulWidget {
  final PatientProfile profile;
  const DashboardScreen({super.key, required this.profile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dbService = DatabaseService();
  BluetoothConnection? _connection;
  bool _connecting = false;
  bool _connected = false;
  String _statusMsg = 'Tap Connect to start monitoring';
  VitalReading? _latest;
  final List<double> _hrHistory = [];
  String _buffer = '';
  int _currentIndex = 0;

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }

  Future<void> _connectBluetooth() async {
    setState(() {
      _connecting = true;
      _statusMsg = 'Scanning for RuralHealthMonitor...';
    });

    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? target;
      for (final d in devices) {
        if (d.name == 'RuralHealthMonitor') {
          target = d;
          break;
        }
      }

      if (target == null) {
        setState(() {
          _connecting = false;
          _statusMsg = 'Device not found. Pair it in Bluetooth settings first.';
        });
        return;
      }

      final conn = await BluetoothConnection.toAddress(target.address);
      setState(() {
        _connection = conn;
        _connected = true;
        _connecting = false;
        _statusMsg = 'Connected — place finger on sensor';
      });

      conn.input!.listen(
        (data) {
          _buffer += String.fromCharCodes(data);
          while (_buffer.contains('\n')) {
            final idx = _buffer.indexOf('\n');
            final line = _buffer.substring(0, idx).trim();
            _buffer = _buffer.substring(idx + 1);
            if (line.contains('HR:')) _processLine(line);
          }
        },
        onDone: () {
          setState(() {
            _connected = false;
            _statusMsg = 'Connection lost. Tap Connect to retry.';
          });
        },
      );
    } catch (e) {
      setState(() {
        _connecting = false;
        _statusMsg = 'Connection failed: $e';
      });
    }
  }

  Future<void> _processLine(String line) async {
    final reading = VitalReading.fromBluetoothString(line);
    await _dbService.insertReading(reading);
    setState(() {
      _latest = reading;
      _hrHistory.add(reading.hr);
      if (_hrHistory.length > 20) _hrHistory.removeAt(0);
    });
  }

  void _disconnect() {
    _connection?.dispose();
    setState(() {
      _connection = null;
      _connected = false;
      _statusMsg = 'Disconnected. Tap Connect to start monitoring.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRisk = _latest?.isRisk ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: AppTheme.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Text(widget.profile.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryScreen(profile: widget.profile),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Export',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExportScreen(profile: widget.profile),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar
            _StatusBanner(
              isRisk: isRisk,
              message: _statusMsg,
              connected: _connected,
            ),
            const SizedBox(height: 16),
            // Vital cards
            Row(
              children: [
                Expanded(
                  child: _VitalCard(
                    icon: Icons.favorite_rounded,
                    label: 'Heart Rate',
                    value: _latest != null ? '${_latest!.hr.toInt()}' : '--',
                    unit: 'BPM',
                    isRisk: _latest != null && (_latest!.hr > 110 || _latest!.hr < 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VitalCard(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperature',
                    value: _latest != null ? _latest!.temp.toStringAsFixed(1) : '--',
                    unit: '°C',
                    isRisk: _latest != null && _latest!.temp > 38.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _VitalCard(
              icon: Icons.air_rounded,
              label: 'Blood Oxygen (SpO₂)',
              value: _latest != null ? '${_latest!.spo2.toInt()}' : '--',
              unit: '%',
              isRisk: _latest != null && _latest!.spo2 < 94,
              wide: true,
            ),
            const SizedBox(height: 20),
            // Mini chart
            if (_hrHistory.length > 1)
              _MiniChart(values: _hrHistory, label: 'Heart Rate Trend'),
            const SizedBox(height: 24),
            // Connect / disconnect button
            SizedBox(
              width: double.infinity,
              child: _connected
                  ? OutlinedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _connecting ? null : _connectBluetooth,
                      icon: _connecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.bluetooth_rounded),
                      label:
                          Text(_connecting ? 'Connecting...' : 'Connect to Device'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final bool isRisk;
  final bool connected;
  final String message;

  const _StatusBanner(
      {required this.isRisk,
      required this.connected,
      required this.message});

  @override
  Widget build(BuildContext context) {
    final color = isRisk ? AppTheme.danger : AppTheme.success;
    final bgColor = isRisk
        ? AppTheme.danger.withOpacity(0.08)
        : connected
            ? AppTheme.success.withOpacity(0.08)
            : AppTheme.cardBorder.withOpacity(0.3);
    final icon = isRisk
        ? Icons.warning_rounded
        : connected
            ? Icons.check_circle_rounded
            : Icons.bluetooth_rounded;
    final textColor =
        isRisk ? AppTheme.danger : connected ? AppTheme.success : AppTheme.textSecondary;
    final label = isRisk
        ? '⚠ RISK DETECTED — Please seek medical attention'
        : connected
            ? '✓ NORMAL — All readings within safe range'
            : message;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool isRisk;
  final bool wide;

  const _VitalCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.isRisk,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isRisk ? AppTheme.danger : AppTheme.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRisk ? AppTheme.danger.withOpacity(0.4) : AppTheme.cardBorder,
        ),
        boxShadow: isRisk
            ? [
                BoxShadow(
                    color: AppTheme.danger.withOpacity(0.08),
                    blurRadius: 8,
                    spreadRadius: 2)
              ]
            : [],
      ),
      child: wide
          ? Row(
              children: [
                _iconBox(accent),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(value,
                            style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: accent)),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(unit,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary)),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                if (isRisk)
                  const Icon(Icons.warning_rounded,
                      color: AppTheme.danger, size: 20),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _iconBox(accent),
                    if (isRisk)
                      const Icon(Icons.warning_rounded,
                          color: AppTheme.danger, size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: accent)),
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(unit,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _iconBox(Color accent) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: accent, size: 18),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<double> values;
  final String label;

  const _MiniChart({required this.values, required this.label});

  @override
  Widget build(BuildContext context) {
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final range = (max - min).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _LinePainter(values: values, min: min, range: range),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final double min;
  final double range;

  _LinePainter({required this.values, required this.min, required this.range});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Dots
    final dotPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - min) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}
