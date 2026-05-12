import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; 
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/patient_profile.dart';
import '../models/vital_reading.dart';

class ExportService {
  static const _rawKey = 'RuralHealthKey2024';

  enc.Key get _key {
    // Pad / truncate to exactly 32 bytes for AES-256
    final bytes = utf8.encode(_rawKey.padRight(32, '0').substring(0, 32));
    return enc.Key(bytes as Uint8List? ?? Uint8List.fromList(bytes));
  }

  String _encrypt(String plaintext) {
    final iv = enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(_key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    // Prepend IV so dashboard can decrypt: base64(iv) + ':' + base64(ciphertext)
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Build the full export payload and share it.
  Future<void> exportAndShare({
    required PatientProfile profile,
    required List<VitalReading> readings,
  }) async {
    final payload = {
      'patient': profile.toJson(),
      'readings': readings.map((r) => r.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };

    final json = jsonEncode(payload);
    final encrypted = _encrypt(json);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/patient_data.json');
    await file.writeAsString(encrypted);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Health data for ${profile.name}',
      text: 'Rural Health Monitor — patient data export',
    );
  }
}
