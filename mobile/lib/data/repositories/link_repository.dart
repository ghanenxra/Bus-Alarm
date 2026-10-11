import 'package:sqflite/sqflite.dart';
import '../local_db/database_helper.dart';
import '../models/saved_link.dart';

class LinkRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<SavedLink>> getAllLinks() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'saved_links',
      orderBy: 'is_favorite DESC, added_at_utc DESC',
    );
    return result.map((json) => SavedLink.fromMap(json)).toList();
  }

  Future<SavedLink?> getLinkById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'saved_links',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return SavedLink.fromMap(maps.first);
    }
    return null;
  }

  Future<void> insertLink(SavedLink link) async {
    final db = await _dbHelper.database;
    await db.insert(
      'saved_links',
      link.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLink(SavedLink link) async {
    final db = await _dbHelper.database;
    await db.update(
      'saved_links',
      link.toMap(),
      where: 'id = ?',
      whereArgs: [link.id],
    );
  }

  Future<void> deleteLink(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'saved_links',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

