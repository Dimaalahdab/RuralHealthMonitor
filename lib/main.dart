import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../services/profile_service.dart';
import '../screens/patient_setup_screen.dart';
import '../screens/pin_login_screen.dart';

void main() {
  runApp(const RuralHealthApp());
}

class RuralHealthApp extends StatelessWidget {
  const RuralHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rural Health Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _StartupRouter(),
    );
  }
}

/// Decides which screen to show on launch:
///  - First time ever → PatientSetupScreen
///  - Already set up  → PinLoginScreen
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final done = await ProfileService().isSetupDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => done ? const PinLoginScreen() : const PatientSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_rounded,
                color: AppTheme.primary, size: 48),
            SizedBox(height: 12),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
