import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/patient_profile.dart';
import '../models/vital_reading.dart';

class ExportService {
  // Hardcoded 32-byte AES key (padded/trimmed to exactly 32 chars)
  static const _rawKey = 'RuralHealthKey2024';

  enc.Key get _key {
    final raw = _rawKey.padRight(32, '0').substring(0, 32);
    return enc.Key(Uint8List.fromList(utf8.encode(raw)));
  }

  /// Encrypts [plaintext] with AES-256-CBC.
  /// A fresh random 16-byte IV is generated for every call.
  /// Output format:  base64(iv):base64(ciphertext)
  String _encrypt(String plaintext) {
    final iv        = enc.IV.fromSecureRandom(16); // ← random per export
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Builds the JSON payload, encrypts it, writes to a temp file, and
  /// triggers the system share sheet so the user can send it anywhere.
  Future<void> exportAndShare({
    required PatientProfile profile,
    required List<VitalReading> readings,
  }) async {
    // 1 — Build plain-text payload
    final payload = {
      'patient': {
        'name': profile.name,
        'age':  profile.age,
      },
      'readings':    readings.map((r) => r.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
      'total':       readings.length,
      'risk_count':  readings.where((r) => r.isRisk).length,
    };

    final plainJson = jsonEncode(payload);

    // 2 — Encrypt
    final encrypted = _encrypt(plainJson);

    // 3 — Write to app documents directory
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/patient_data.json');
    await file.writeAsString(encrypted, flush: true);

    // 4 — Share via system sheet (WhatsApp, Gmail, Bluetooth, USB, …)
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Health data for ${profile.name}',
      text:    'Rural Health Monitor — encrypted patient data export',
    );
  }
}