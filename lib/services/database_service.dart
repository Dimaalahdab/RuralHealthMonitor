import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../../models/vital_reading.dart';

class DatabaseService {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'health_monitor.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            hr REAL NOT NULL,
            temp REAL NOT NULL,
            spo2 REAL NOT NULL,
            status TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertReading(VitalReading reading) async {
    final database = await db;
    return database.insert('readings', reading.toMap()..remove('id'));
  }

  Future<List<VitalReading>> getAllReadings() async {
    final database = await db;
    final maps = await database.query(
      'readings',
      orderBy: 'id DESC',
    );
    return maps.map(VitalReading.fromMap).toList();
  }

  Future<void> clearAll() async {
    final database = await db;
    await database.delete('readings');
  }
}
