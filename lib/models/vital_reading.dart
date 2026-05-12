class VitalReading {
  final int? id;
  final String timestamp;
  final double hr;
  final double temp;
  final double spo2;
  final String status;

  VitalReading({
    this.id,
    required this.timestamp,
    required this.hr,
    required this.temp,
    required this.spo2,
    required this.status,
  });

  bool get isRisk => status == 'RISK';

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp,
        'hr': hr,
        'temp': temp,
        'spo2': spo2,
        'status': status,
      };

  Map<String, dynamic> toJson() => {
        'time': timestamp,
        'HR': hr,
        'TEMP': temp,
        'SPO2': spo2,
        'status': status,
      };

  factory VitalReading.fromMap(Map<String, dynamic> map) => VitalReading(
        id: map['id'],
        timestamp: map['timestamp'],
        hr: map['hr'],
        temp: map['temp'],
        spo2: map['spo2'],
        status: map['status'],
      );

  /// Parse a Bluetooth data string like: HR:85,TEMP:36.7,SPO2:97,STATUS:OK
  factory VitalReading.fromBluetoothString(String raw) {
    final parts = <String, String>{};
    for (final part in raw.trim().split(',')) {
      final kv = part.split(':');
      if (kv.length == 2) parts[kv[0].trim()] = kv[1].trim();
    }
    return VitalReading(
      timestamp: DateTime.now().toIso8601String(),
      hr: double.tryParse(parts['HR'] ?? '0') ?? 0,
      temp: double.tryParse(parts['TEMP'] ?? '0') ?? 0,
      spo2: double.tryParse(parts['SPO2'] ?? '0') ?? 0,
      status: parts['STATUS'] ?? 'UNKNOWN',
    );
  }
}
