import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/patient_profile.dart';

class ProfileService {
  static const _keyName = 'patient_name';
  static const _keyAge = 'patient_age';
  static const _keyPin = 'patient_pin';
  static const _keySetupDone = 'setup_done';
  static const _keyFailedAttempts = 'failed_attempts';
  static const _keyLockUntil = 'lock_until';

  // ── Setup ────────────────────────────────────────────────────────────────

  Future<bool> isSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySetupDone) ?? false;
  }

  Future<void> saveProfile(PatientProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, profile.name);
    await prefs.setInt(_keyAge, profile.age);
    await prefs.setString(_keyPin, profile.pin);
    await prefs.setBool(_keySetupDone, true);
  }

  Future<PatientProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyName);
    final age = prefs.getInt(_keyAge);
    final pin = prefs.getString(_keyPin);
    if (name == null || age == null || pin == null) return null;
    return PatientProfile(name: name, age: age, pin: pin);
  }

  // ── PIN verification ─────────────────────────────────────────────────────

  /// Returns null on success, or an error message string on failure.
  Future<String?> verifyPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();

    // Check lock
    final lockUntil = prefs.getInt(_keyLockUntil) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < lockUntil) {
      final remaining = ((lockUntil - now) / 1000).ceil();
      return 'Too many attempts. Try again in $remaining seconds.';
    }

    final storedPin = prefs.getString(_keyPin) ?? '';
    if (enteredPin == storedPin) {
      await prefs.setInt(_keyFailedAttempts, 0);
      return null; // success
    }

    // Wrong PIN
    final attempts = (prefs.getInt(_keyFailedAttempts) ?? 0) + 1;
    await prefs.setInt(_keyFailedAttempts, attempts);
    if (attempts >= 3) {
      await prefs.setInt(_keyLockUntil, now + 30000); // 30s lock
      await prefs.setInt(_keyFailedAttempts, 0);
      return 'Too many wrong attempts. Locked for 30 seconds.';
    }
    return 'Incorrect PIN. ${3 - attempts} attempt(s) remaining.';
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
