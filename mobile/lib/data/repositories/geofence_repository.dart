import '../local_db/database_helper.dart';
import '../models/local_geofence.dart';

class GeofenceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<LocalGeofence>> getAllGeofences() async {
    final db = await _dbHelper.appDb;
    final result = await db.query(
      'geofences',
      orderBy: 'created_at_utc DESC',
    );
    return result.map((json) => LocalGeofence.fromMap(json)).toList();
  }

  Future<List<LocalGeofence>> getGeofencesByLink(String linkId) async {
    final db = await _dbHelper.appDb;
    final result = await db.query(
      'geofences',
      where: 'linked_saved_link_id = ?',
      whereArgs: [linkId],
      orderBy: 'created_at_utc DESC',
    );
    return result.map((json) => LocalGeofence.fromMap(json)).toList();
  }

  Future<void> insertGeofence(LocalGeofence fence) async {
    final db = await _dbHelper.appDb;
    await db.insert(
      'geofences',
      fence.toMap(),
    );
  }

  Future<void> updateGeofence(LocalGeofence fence) async {
    final db = await _dbHelper.appDb;
    await db.update(
      'geofences',
      fence.toMap(),
      where: 'id = ?',
      whereArgs: [fence.id],
    );
  }

  Future<void> deleteGeofence(String id) async {
    final db = await _dbHelper.appDb;
    await db.delete(
      'geofences',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

