// lib/services/bluetooth_service.dart
// FIXED: Added runtime Bluetooth permission request for Android 12+

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/vital_reading.dart';
import 'database_service.dart';

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BluetoothConnection? _connection;
  StreamSubscription?  _sub;
  String               _buffer = '';

  bool          get isConnected => _connection?.isConnected ?? false;
  VitalReading? _latest;
  VitalReading? get latest => _latest;

  final _db = DatabaseService();
  static const String _deviceName = 'HealthMonitor';

  Future<String?> connect() async {
    if (isConnected) return null;

    // STEP 1: Request runtime permissions (required Android 12+)
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final denied = statuses.values.any(
      (s) => s == PermissionStatus.denied || s == PermissionStatus.permanentlyDenied,
    );

    if (denied) {
      return 'Bluetooth permission denied.\nGo to phone Settings → Apps → Rural Health Monitor → Permissions → enable Bluetooth.';
    }

    // STEP 2: Enable Bluetooth if off
    final btEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
    if (!btEnabled) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await Future.delayed(const Duration(seconds: 2));
    }

    // STEP 3: Find device in paired list
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      debugPrint('[BT] Paired: ${devices.map((d) => d.name).toList()}');

      BluetoothDevice? target;
      for (final d in devices) {
        if (d.name == _deviceName) { target = d; break; }
      }

      if (target == null) {
        return 'Device "$_deviceName" not found.\n\nTo fix:\n1. Make sure ESP32 is powered (green LED blinked)\n2. Phone Settings → Bluetooth → Scan\n3. Find "$_deviceName" and tap to pair\n4. Return to app and tap SCAN';
      }

      // STEP 4: Connect
      _connection = await BluetoothConnection.toAddress(target.address);
      debugPrint('[BT] Connected to ${target.name}');

      _sub = _connection!.input!.listen(
        _onData,
        onDone:  _onDisconnect,
        onError: (_) => _onDisconnect(),
      );

      notifyListeners();
      return null;

    } catch (e) {
      return 'Connection failed: ${e.toString().replaceFirst("Exception: ", "")}';
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _connection?.close();
    _connection = null;
    _buffer = '';
    notifyListeners();
  }

  void _onData(Uint8List data) {
    _buffer += utf8.decode(data, allowMalformed: true);
    while (_buffer.contains('\n')) {
      final idx  = _buffer.indexOf('\n');
      final line = _buffer.substring(0, idx).trim();
      _buffer    = _buffer.substring(idx + 1);
      if (line.isEmpty) continue;
      _parseLine(line);
    }
  }

  void _parseLine(String line) {
    if (line.contains('STATUS:NOFINGER'))    { notifyListeners(); return; }
    if (line.contains('STATUS:CALIBRATING')) { notifyListeners(); return; }
    try {
      final reading = VitalReading.fromBluetoothString(line);
      if (reading.hr > 0 && reading.spo2 > 0) {
        _latest = reading;
        _db.insertReading(reading);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[BT] Parse error: $e');
    }
  }

  void _onDisconnect() {
    _connection = null;
    _sub = null;
    notifyListeners();
  }
}
