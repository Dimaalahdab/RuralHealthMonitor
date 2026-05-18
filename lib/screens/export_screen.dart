import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/patient_profile.dart';
import '../models/vital_reading.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

// ── Public widget used by DashboardScreen's tab ────────────────────────────
class ExportBody extends StatefulWidget {
  final PatientProfile profile;
  const ExportBody({super.key, required this.profile});

  @override
  State<ExportBody> createState() => _ExportBodyState();
}

class _ExportBodyState extends State<ExportBody> {
  final _db     = DatabaseService();
  final _export = ExportService();

  List<VitalReading>? _readings;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Reload every time the tab is shown (called from initState; also
  // triggered by pull-to-refresh via the RefreshIndicator below).
  Future<void> _load() async {
    try {
      final rows = await _db.getAllReadings();
      if (mounted) setState(() => _readings = rows);
    } catch (_) {
      if (mounted) setState(() => _readings = []);
    }
  }

  // ── Export ─────────────────────────────────────────────────────────────────
  Future<void> _doExport() async {
    final readings = _readings;
    if (readings == null || readings.isEmpty) {
      _snack('No readings to export. Connect to device first.', error: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      await _export.exportAndShare(
        profile:  widget.profile,
        readings: readings,
      );
    } catch (e) {
      if (mounted) _snack('Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fileSize() {
    final count = _readings?.length ?? 0;
    final bytes = count * 90 + 250; // rough estimate per reading
    if (bytes < 1024) return '~${bytes} B';
    return '~${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  String _dateRange() {
    final r = _readings;
    if (r == null || r.isEmpty) return '—';
    try {
      final oldest = DateTime.parse(r.last.timestamp);
      final newest = DateTime.parse(r.first.timestamp);
      final fmt = DateFormat('MMM d');
      if (oldest.year  == newest.year &&
          oldest.month == newest.month &&
          oldest.day   == newest.day) {
        return '${fmt.format(oldest)}, ${newest.year}';
      }
      return '${fmt.format(oldest)} – ${fmt.format(newest)}, ${newest.year}';
    } catch (_) {
      return '—';
    }
  }

  String _shortName(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length <= 1) return name;
    return '${parts.first} ${parts.last[0]}.';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final readings  = _readings;
    final total     = readings?.length ?? 0;
    final riskCount = readings?.where((r) => r.isRisk).length ?? 0;
    final hasData   = total > 0;
    final loading   = readings == null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Purple header ─────────────────────────────────────────────
          Container(
            color: AppTheme.purple,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Row(
                  children: [
                    const Icon(Icons.upload_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send to doctor',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('patient_data.json · AES-256 encrypted',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white70, size: 20),
                      tooltip: 'Reload readings',
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.purple))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppTheme.purple,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // ── Info card ──────────────────────────────
                          Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AppTheme.cardBorder),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              children: [
                                _InfoRow(
                                    label: 'Patient',
                                    value: _shortName(widget.profile.name)),
                                _InfoRow(
                                    label: 'Total readings',
                                    value: '$total'),
                                _InfoRow(
                                    label: 'Date range',
                                    value: _dateRange()),
                                _InfoRow(
                                  label: 'Risk events',
                                  value: riskCount == 0
                                      ? 'None'
                                      : '$riskCount detected',
                                  valueColor:
                                      riskCount > 0 ? AppTheme.danger : null,
                                  valueBold: riskCount > 0,
                                ),
                                _InfoRow(
                                    label: 'File size',
                                    value: _fileSize()),
                                _InfoRow(
                                  label: 'Encryption',
                                  value: 'AES-256 active',
                                  valueColor: AppTheme.success,
                                  isLast: true,
                                ),

                                const SizedBox(height: 20),

                                // ── EXPORT & SHARE ─────────────────
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: (!hasData || _exporting)
                                          ? null
                                          : _doExport,
                                      icon: _exporting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Icon(Icons.share_rounded,
                                              size: 18),
                                      label: Text(
                                          _exporting
                                              ? 'Preparing…'
                                              : 'EXPORT & SHARE',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.purple,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            AppTheme.purple.withOpacity(0.35),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ── VIEW FILE PREVIEW ──────────────
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: hasData
                                          ? () => _showPreview(context)
                                          : null,
                                      icon: const Icon(
                                          Icons.preview_rounded,
                                          size: 18),
                                      label: const Text('VIEW FILE PREVIEW',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppTheme.textPrimary,
                                        side: const BorderSide(
                                            color: AppTheme.cardBorder),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // ── Share method chips ─────────────
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _ShareChip(
                                          label: 'WhatsApp',
                                          color: const Color(0xFF25D366),
                                          onTap: hasData ? _doExport : null),
                                      _ShareChip(
                                          label: 'Gmail',
                                          color: const Color(0xFFEA4335),
                                          onTap: hasData ? _doExport : null),
                                      _ShareChip(
                                          label: 'Bluetooth',
                                          color: AppTheme.primary,
                                          onTap: hasData ? _doExport : null),
                                      _ShareChip(
                                          label: 'USB',
                                          color: AppTheme.textSecondary,
                                          onTap: hasData ? _doExport : null),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Text(
                                    'Tapping any method above opens the system share sheet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── No-data warning ────────────────────────
                          if (!hasData)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppTheme.warning
                                          .withOpacity(0.3)),
                                ),
                                child: const Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: AppTheme.warning, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No readings yet. Go to Dashboard, connect the device, and start a monitoring session.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF92400E),
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── File preview bottom sheet ──────────────────────────────────────────────
  void _showPreview(BuildContext context) {
    final readings = _readings ?? [];
    final sample   = readings.take(3).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.88,
        minChildSize: 0.35,
        expand: false,
        builder: (ctx, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.cardBorder,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Title row
              Row(children: [
                const Icon(Icons.preview_rounded,
                    color: AppTheme.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'File preview · first ${sample.length} of ${readings.length} readings',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ]),
              const SizedBox(height: 4),
              const Text(
                'This is the plain JSON before encryption.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              // Code block
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _buildPreviewJson(sample),
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFCDD6F4),
                      height: 1.65),
                ),
              ),
              const SizedBox(height: 14),

              // Encryption notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.success.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.lock_rounded,
                      color: AppTheme.success, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The exported file is AES-256-CBC encrypted with a fresh '
                      'random IV each time. Only authorised recipients with the '
                      'decryption key can read the data.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.success,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPreviewJson(List<VitalReading> sample) {
    final r = _readings!;
    final readingsJson = sample.map((v) {
      final t = v.timestamp.length >= 16
          ? v.timestamp.substring(0, 16)
          : v.timestamp;
      return '    {\n'
          '      "time":   "$t",\n'
          '      "HR":     ${v.hr.toStringAsFixed(1)},\n'
          '      "TEMP":   ${v.temp.toStringAsFixed(1)},\n'
          '      "SPO2":   ${v.spo2.toStringAsFixed(1)},\n'
          '      "status": "${v.status}"\n'
          '    }';
    }).join(',\n');

    final ellipsis =
        r.length > sample.length ? ',\n    // … ${r.length - sample.length} more …' : '';

    return '{\n'
        '  "patient": {\n'
        '    "name": "${widget.profile.name}",\n'
        '    "age":  ${widget.profile.age}\n'
        '  },\n'
        '  "exported_at": "${DateTime.now().toIso8601String().substring(0, 16)}",\n'
        '  "total":       ${r.length},\n'
        '  "risk_count":  ${r.where((v) => v.isRisk).length},\n'
        '  "readings": [\n'
        '$readingsJson'
        '$ellipsis\n'
        '  ]\n'
        '}';
  }
}

// ── Reusable sub-widgets ───────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textSecondary)),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          valueBold ? FontWeight.w700 : FontWeight.w500,
                      color: valueColor ?? AppTheme.textPrimary)),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: AppTheme.cardBorder),
      ],
    );
  }
}

class _ShareChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ShareChip({
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(
                child: Text(label[0],
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}