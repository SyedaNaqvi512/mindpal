import 'package:flutter/foundation.dart';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/database/database_service.dart';
import '../models/exercise_session.dart';

/// Reads and writes exercise sessions in the encrypted on-device database
/// (FR-44, FR-45, FR-52). Account deletion removes the whole database (FR-34).
class ExerciseRepository {
  static const table = 'exercise_sessions';
  static bool _ready = false;

  static Future<Database> _db() async {
    final db = await DatabaseService.database;
    if (!_ready) {
      await DatabaseService.ensureExerciseTable();
      _ready = true;
    }
    return db;
  }

  /// Bumped whenever a session is saved or deleted, so lists can reload.
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  /// Inserts or updates [s] and returns its id.
  static Future<int> save(ExerciseSession s) async {
    final db = await _db();
    s.updatedAt = DateTime.now();
    if (s.id == null) {
      s.id = await db.insert(table, s.toRow());
    } else {
      await db.update(table, s.toRow(), where: 'id = ?', whereArgs: [s.id]);
    }
    changed.value++;
    return s.id!;
  }

  /// Unfinished sessions, newest first (FR-44).
  static Future<List<ExerciseSession>> inProgress() async {
    final db = await _db();
    final rows = await db.query(
      table,
      where: 'status = ?',
      whereArgs: [ExerciseSession.inProgress],
      orderBy: 'updated_at DESC',
    );
    return rows.map(ExerciseSession.fromRow).toList();
  }

  /// Finished sessions, newest first (FR-45).
  static Future<List<ExerciseSession>> completed() async {
    final db = await _db();
    final rows = await db.query(
      table,
      where: 'status = ?',
      whereArgs: [ExerciseSession.completed],
      orderBy: 'completed_at DESC',
    );
    return rows.map(ExerciseSession.fromRow).toList();
  }

  /// Finished sessions related to one journal entry (FR-48).
  static Future<List<ExerciseSession>> forEntry(int entryId) async {
    final db = await _db();
    final rows = await db.query(
      table,
      where: 'entry_id = ? AND status = ?',
      whereArgs: [entryId, ExerciseSession.completed],
      orderBy: 'completed_at DESC',
    );
    return rows.map(ExerciseSession.fromRow).toList();
  }

  /// Deletes one session (FR-44 discard, FR-52).
  static Future<void> delete(int id) async {
    final db = await _db();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    changed.value++;
  }

  /// Deletes every saved exercise answer (FR-52).
  static Future<void> deleteAll() async {
    final db = await _db();
    await db.delete(table);
    changed.value++;
  }
}
