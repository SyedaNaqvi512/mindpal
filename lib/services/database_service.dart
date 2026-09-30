import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DatabaseService {
  static const String _databaseName = 'mindpal.db';
  static const int _databaseVersion = 1;
  static const String _databaseKeyName = 'mindpal_database_key';

  static final FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  static Database? _database;

  /// Returns the database instance.
  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  /// Opens the encrypted MindPal database.
  static Future<Database> _openDatabase() async {
    final databaseKey = await _getOrCreateDatabaseKey();
    final databasesPath = await getDatabasesPath();
    final databasePath = '$databasesPath/$_databaseName';

    return openDatabase(
      databasePath,
      password: databaseKey,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE journal_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            mood INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Gets the database key from secure storage.
  /// If it does not exist, a new random key is created and stored securely.
  static Future<String> _getOrCreateDatabaseKey() async {
    final existingKey = await _secureStorage.read(
      key: _databaseKeyName,
    );

    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    final random = Random.secure();
    final keyBytes = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    );

    final newKey = base64UrlEncode(keyBytes);

    await _secureStorage.write(
      key: _databaseKeyName,
      value: newKey,
    );

    return newKey;
  }

  /// Inserts a journal entry into the encrypted database.
  static Future<int> insertJournalEntry({
    required String content,
    required int mood,
  }) async {
    final db = await database;

    return db.insert(
      'journal_entries',
      {
        'content': content,
        'mood': mood,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Reads all journal entries from the encrypted database.
  static Future<List<Map<String, dynamic>>> getJournalEntries() async {
    final db = await database;

    return db.query(
      'journal_entries',
      orderBy: 'created_at DESC',
    );
  }

  /// Deletes a journal entry by its ID.
  static Future<int> deleteJournalEntry(int id) async {
    final db = await database;

    return db.delete(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}