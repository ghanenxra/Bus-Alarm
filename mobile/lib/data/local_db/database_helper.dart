import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bus_alarm_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createDB,
        ),
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE saved_links (
        id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL,
        share_url TEXT NOT NULL,
        token_expiry_utc TEXT,
        added_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        last_known_status TEXT NOT NULL DEFAULT 'unknown',
        last_activated_at_utc TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE geofences (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius_meters INTEGER NOT NULL DEFAULT 200,
        linked_saved_link_id TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        trigger_mode TEXT NOT NULL DEFAULT 'crossing',
        cooldown_seconds INTEGER NOT NULL DEFAULT 900,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL,
        FOREIGN KEY (linked_saved_link_id) REFERENCES saved_links (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_alert_history (
        id TEXT PRIMARY KEY,
        backend_alert_id TEXT,
        geofence_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        distance_meters REAL,
        occurred_at_utc TEXT NOT NULL,
        dismissed_at_utc TEXT,
        action TEXT
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}

