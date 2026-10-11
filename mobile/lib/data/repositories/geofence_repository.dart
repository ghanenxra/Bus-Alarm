import 'package:sqflite/sqflite.dart';
import '../local_db/database_helper.dart';
import '../models/local_geofence.dart';

class GeofenceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<LocalGeofence>> getAllGeofences() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'geofences',
      orderBy: 'created_at_utc DESC',
    );
    return result.map((json) => LocalGeofence.fromMap(json)).toList();
  }

  Future<List<LocalGeofence>> getGeofencesByLink(String linkId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'geofences',
      where: 'linked_saved_link_id = ?',
      whereArgs: [linkId],
      orderBy: 'created_at_utc DESC',
    );
    return result.map((json) => LocalGeofence.fromMap(json)).toList();
  }

  Future<void> insertGeofence(LocalGeofence fence) async {
    final db = await _dbHelper.database;
    await db.insert(
      'geofences',
      fence.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGeofence(LocalGeofence fence) async {
    final db = await _dbHelper.database;
    await db.update(
      'geofences',
      fence.toMap(),
      where: 'id = ?',
      whereArgs: [fence.id],
    );
  }

  Future<void> deleteGeofence(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'geofences',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

