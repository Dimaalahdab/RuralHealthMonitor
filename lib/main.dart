import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'services/profile_service.dart';
import 'screens/patient_setup_screen.dart';
import 'screens/pin_login_screen.dart';

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
    final profile = await ProfileService().getProfile();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => profile == null
            ? const PatientSetupScreen()
            : const PinLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppTheme.purple),
          strokeWidth: 2,
        ),
      ),
    );
  }
}