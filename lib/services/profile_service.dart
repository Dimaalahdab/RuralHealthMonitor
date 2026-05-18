import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient_profile.dart';

class ProfileService {
  static const _kName    = 'patient_name';
  static const _kAge     = 'patient_age';
  static const _kPin     = 'patient_pin';
  static const _kFails   = 'failed_attempts';
  static const _kLock    = 'lock_until';

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> saveProfile(PatientProfile profile) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, profile.name);
    await p.setInt(_kAge,     profile.age);
    await p.setString(_kPin,  profile.pin);
    debugPrint('[ProfileService] Saved: name=${profile.name} pin=${profile.pin}');
  }

  // ── Check setup done ───────────────────────────────────────────────────────
  Future<bool> isSetupDone() async {
    final p = await SharedPreferences.getInstance();
    final ok = p.getString(_kName) != null && p.getString(_kPin) != null;
    debugPrint('[ProfileService] isSetupDone=$ok');
    return ok;
  }

  // ── Load profile ───────────────────────────────────────────────────────────
  Future<PatientProfile?> getProfile() async {
    final p    = await SharedPreferences.getInstance();
    final name = p.getString(_kName);
    final age  = p.getInt(_kAge);
    final pin  = p.getString(_kPin);
    debugPrint('[ProfileService] getProfile: name=$name age=$age pinSet=${pin != null}');
    if (name == null || pin == null) return null;
    return PatientProfile(name: name, age: age ?? 0, pin: pin);
  }

  // ── Verify PIN ─────────────────────────────────────────────────────────────
  /// Returns null on success, error string on failure.
  Future<String?> verifyPin(String entered) async {
    final p   = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check lockout
    final lockUntil = p.getInt(_kLock) ?? 0;
    if (now < lockUntil) {
      final secs = ((lockUntil - now) / 1000).ceil();
      return 'Locked. Try again in $secs seconds.';
    }

    final stored = p.getString(_kPin) ?? '';
    debugPrint('[ProfileService] verifyPin: entered=$entered stored=$stored');

    if (entered == stored) {
      await p.setInt(_kFails, 0);
      debugPrint('[ProfileService] PIN correct ✓');
      return null; // ✅ success
    }

    // Wrong PIN — increment fails
    final fails = (p.getInt(_kFails) ?? 0) + 1;
    await p.setInt(_kFails, fails);
    debugPrint('[ProfileService] Wrong PIN. fails=$fails');

    if (fails >= 3) {
      await p.setInt(_kLock,  now + 30000);
      await p.setInt(_kFails, 0);
      return 'Too many attempts. Locked for 30 seconds.';
    }
    return 'Incorrect PIN. ${3 - fails} attempt(s) remaining.';
  }

  Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    debugPrint('[ProfileService] All data cleared.');
  }
}