import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app_theme.dart';
import '../../../models/patient_profile.dart';
import '../../../services/profile_service.dart';
import 'dashboard_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _profileService = ProfileService();
  PatientProfile? _profile;
  String _pin = '';
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getProfile();
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  void _onKeyTap(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == 4) _verifyPin();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifyPin() async {
    final error = await _profileService.verifyPin(_pin);
    if (error == null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(profile: _profile!),
        ),
      );
    } else {
      setState(() {
        _errorMessage = error;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.primary, size: 34),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _profile?.name ?? 'Patient',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your PIN to continue',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppTheme.primary : Colors.transparent,
                      border: Border.all(
                        color: _errorMessage != null
                            ? AppTheme.danger
                            : filled
                                ? AppTheme.primary
                                : AppTheme.cardBorder,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              // Error
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _errorMessage != null
                    ? Container(
                        key: ValueKey(_errorMessage),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 16, color: AppTheme.danger),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(height: 38),
              ),
              const Spacer(),
              // Numpad
              _buildNumpad(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['1', '2', '3']
              .map((d) => _numKey(d))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['4', '5', '6']
              .map((d) => _numKey(d))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['7', '8', '9']
              .map((d) => _numKey(d))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            const SizedBox(width: 12),
            _numKey('0'),
            const SizedBox(width: 12),
            _deleteKey(),
          ],
        ),
      ],
    );
  }

  Widget _numKey(String digit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onKeyTap(digit),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteKey() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _onDelete,
          child: SizedBox(
            width: 72,
            height: 72,
            child: const Icon(Icons.backspace_outlined,
                color: AppTheme.textSecondary, size: 22),
          ),
        ),
      ),
    );
  }
}
