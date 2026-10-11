import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Universal database interface supporting native SQLite and Web storage.
abstract class AppDb {
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  });

  Future<int> insert(
    String table,
    Map<String, dynamic> values,
  );

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static AppDb? _appDb;
  static Database? _rawSqfliteDb;

  DatabaseHelper._init();

  /// Returns the universal database client (native SQLite on mobile, persistent WebStorage on web).
  Future<AppDb> get appDb async {
    if (_appDb != null) return _appDb!;

    if (kIsWeb) {
      _appDb = SharedPreferencesDb();
    } else {
      try {
        final nativeDb = await _initNativeSqflite('bus_alarm_local.db');
        _rawSqfliteDb = nativeDb;
        _appDb = SqfliteDb(nativeDb);
      } catch (e) {
        debugPrint('Native SQLite initialization fallback to SharedPreferences: $e');
        _appDb = SharedPreferencesDb();
      }
    }
    return _appDb!;
  }

  /// Direct raw database getter for native platforms.
  Future<Database> get database async {
    if (_rawSqfliteDb != null) return _rawSqfliteDb!;
    _rawSqfliteDb = await _initNativeSqflite('bus_alarm_local.db');
    return _rawSqfliteDb!;
  }

  Future<Database> _initNativeSqflite(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

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
    final db = _rawSqfliteDb;
    if (db != null) {
      await db.close();
      _rawSqfliteDb = null;
    }
    _appDb = null;
  }
}

/// Native SQLite implementation wrapping sqflite.
class SqfliteDb implements AppDb {
  final Database _db;
  SqfliteDb(this._db);

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    return await _db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    return await _db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await _db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await _db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }
}

/// Universal web/fallback document store using SharedPreferences.
class SharedPreferencesDb implements AppDb {
  static final Map<String, List<Map<String, dynamic>>> _memoryCache = {};

  Future<List<Map<String, dynamic>>> _getTableData(String table) async {
    if (_memoryCache.containsKey(table)) {
      return _memoryCache[table]!;
    }
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('local_table_$table');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _memoryCache[table] = list;
        return list;
      } catch (_) {}
    }
    _memoryCache[table] = [];
    return _memoryCache[table]!;
  }

  Future<void> _saveTableData(String table, List<Map<String, dynamic>> data) async {
    _memoryCache[table] = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_table_$table', jsonEncode(data));
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final all = await _getTableData(table);
    List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(all);

    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      if (where.startsWith('id = ?')) {
        final id = whereArgs[0]?.toString();
        results = results.where((item) => item['id']?.toString() == id).toList();
      } else if (where.startsWith('linked_saved_link_id = ?')) {
        final linkId = whereArgs[0]?.toString();
        results = results.where((item) => item['linked_saved_link_id']?.toString() == linkId).toList();
      }
    }

    if (orderBy != null) {
      if (orderBy.contains('is_favorite DESC')) {
        results.sort((a, b) {
          final favA = (a['is_favorite'] == 1 || a['is_favorite'] == true) ? 1 : 0;
          final favB = (b['is_favorite'] == 1 || b['is_favorite'] == true) ? 1 : 0;
          if (favA != favB) return favB.compareTo(favA);
          final timeA = a['added_at_utc']?.toString() ?? '';
          final timeB = b['added_at_utc']?.toString() ?? '';
          return timeB.compareTo(timeA);
        });
      } else if (orderBy.contains('created_at_utc DESC')) {
        results.sort((a, b) {
          final timeA = a['created_at_utc']?.toString() ?? '';
          final timeB = b['created_at_utc']?.toString() ?? '';
          return timeB.compareTo(timeA);
        });
      }
    }

    return results;
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    final list = await _getTableData(table);
    final id = values['id']?.toString();
    final index = list.indexWhere((item) => item['id']?.toString() == id);
    if (index >= 0) {
      list[index] = Map<String, dynamic>.from(values);
    } else {
      list.add(Map<String, dynamic>.from(values));
    }
    await _saveTableData(table, list);
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = await _getTableData(table);
    int count = 0;
    final id = (whereArgs != null && whereArgs.isNotEmpty)
        ? whereArgs[0]?.toString()
        : values['id']?.toString();

    for (int i = 0; i < list.length; i++) {
      if (list[i]['id']?.toString() == id) {
        list[i].addAll(values);
        count++;
      }
    }
    await _saveTableData(table, list);
    return count;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = await _getTableData(table);
    final id = (whereArgs != null && whereArgs.isNotEmpty)
        ? whereArgs[0]?.toString()
        : null;

    if (id == null) return 0;
    final initialCount = list.length;
    list.removeWhere((item) => item['id']?.toString() == id);
    final deletedCount = initialCount - list.length;
    await _saveTableData(table, list);
    return deletedCount;
  }
}
