import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/profile_service.dart';
import 'dashboard_screen.dart';
import 'patient_setup_screen.dart';
import '../models/patient_profile.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _svc = ProfileService();

  String _pin = '';
  String? _error;
  bool _loading = true;
  bool _busy = false; // true while verifying or navigating

  // Loaded once on init — never null after loading completes
  PatientProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load profile ───────────────────────────────────────────────────────────
  Future<void> _load() async {
    final profile = await _svc.getProfile();
    if (!mounted) return;

    if (profile == null) {
      // No profile saved yet — go to setup
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PatientSetupScreen()),
      );
      return;
    }

    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  // ── Key tap ────────────────────────────────────────────────────────────────
  void _tap(String digit) {
    if (_busy || _pin.length >= 4) return;
    final next = _pin + digit;
    setState(() {
      _pin = next;
      _error = null;
    });
    if (next.length == 4) _verify(next);
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  // ── Verify ─────────────────────────────────────────────────────────────────
  Future<void> _verify(String pin) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final errorMsg = await _svc.verifyPin(pin);

      if (!mounted) return;

      if (errorMsg == null) {
        // ✅ PIN correct — navigate to dashboard
        // Profile is guaranteed non-null here (we returned early if null above)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _profile != null ? DashboardScreen(profile: _profile!) : const PatientSetupScreen(),
          ),
        );
        // Don't set state after navigation
        return;
      }

      // ❌ Wrong PIN
      setState(() {
        _error = errorMsg;
        _pin = '';
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _pin = '';
        _busy = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.purple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Icon
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: AppTheme.purple, size: 34),
            ),
            const SizedBox(height: 20),
            const Text('Health Monitor',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('Enter your 4-digit PIN',
                style: TextStyle(
                    fontSize: 15, color: AppTheme.textSecondary)),
            const SizedBox(height: 32),

            // ── PIN dots ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppTheme.purple : Colors.transparent,
                    border: Border.all(
                      color: _error != null
                          ? AppTheme.danger
                          : filled
                              ? AppTheme.purple
                              : AppTheme.cardBorder,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // ── Error text ────────────────────────────────────────────────
            SizedBox(
              height: 18,
              child: _error != null
                  ? Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 12))
                  : null,
            ),

            const Spacer(),

            // ── Numpad ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _row(['1', '2', '3']),
                  const SizedBox(height: 12),
                  _row(['4', '5', '6']),
                  const SizedBox(height: 12),
                  _row(['7', '8', '9']),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 84),
                      _key('0'),
                      _backspace(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _row(List<String> digits) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: digits.map(_key).toList(),
      );

  Widget _key(String digit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _busy ? null : () => _tap(digit),
          child: Container(
            width: 72, height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(digit,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ),
      ),
    );
  }

  Widget _backspace() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _busy ? null : _delete,
        child: const SizedBox(
          width: 72, height: 72,
          child: Icon(Icons.backspace_outlined,
              color: AppTheme.textSecondary, size: 22),
        ),
      ),
    );
  }
}