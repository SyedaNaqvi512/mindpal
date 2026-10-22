import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DatabaseService {
  static const String _databaseName = 'mindpal.db';
  static const int _databaseVersion = 4;
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
      onConfigure: (db) async {
        // Needed so ON DELETE CASCADE really works.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE journal_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            mood INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT
          )
        ''');

        await _createReflectionsTable(db);
        await _createTagsTable(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createReflectionsTable(db);
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE journal_entries ADD COLUMN updated_at TEXT');
          await _createTagsTable(db);
          await _createIndexes(db);
        }
        // (a database older than version 2 got the full reflections table above)
        if (oldVersion >= 2 && oldVersion < 4) {
          await _addReflectionColumns(db);
        }
      },
    );
  }

  /// Creates the reflections table.
  static Future<void> _createReflectionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE reflections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        reflection_text TEXT NOT NULL,
        thinking_pattern TEXT,
        server_reflection_id TEXT,
        created_at TEXT NOT NULL,
        parts_json TEXT,
        status TEXT NOT NULL DEFAULT 'accepted',
        source TEXT NOT NULL DEFAULT 'unknown',
        edited INTEGER NOT NULL DEFAULT 0,
        rating TEXT,
        rating_reason TEXT,
        rating_sent INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (entry_id)
          REFERENCES journal_entries (id)
          ON DELETE CASCADE
      )
    ''');
  }

  /// Version 4: reflection drafts, source label, edits and ratings (FR-22 to FR-24).
  /// Reflections saved before this version count as accepted.
  static Future<void> _addReflectionColumns(Database db) async {
    for (final sql in const [
      'ALTER TABLE reflections ADD COLUMN parts_json TEXT',
      "ALTER TABLE reflections ADD COLUMN status TEXT NOT NULL DEFAULT 'accepted'",
      "ALTER TABLE reflections ADD COLUMN source TEXT NOT NULL DEFAULT 'unknown'",
      'ALTER TABLE reflections ADD COLUMN edited INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE reflections ADD COLUMN rating TEXT',
      'ALTER TABLE reflections ADD COLUMN rating_reason TEXT',
      'ALTER TABLE reflections ADD COLUMN rating_sent INTEGER NOT NULL DEFAULT 0',
    ]) {
      await db.execute(sql);
    }
  }

  /// Feeling tags of an entry (FR-10).
  static Future<void> _createTagsTable(Database db) async {
    await db.execute('''
      CREATE TABLE entry_tags (
        entry_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (entry_id, tag),
        FOREIGN KEY (entry_id)
          REFERENCES journal_entries (id)
          ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX idx_entries_created ON journal_entries (created_at)');
    await db.execute(
        'CREATE INDEX idx_reflections_entry ON reflections (entry_id)');
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

  static Future<void> _writeTags(
      DatabaseExecutor txn, int entryId, List<String> tags) async {
    await txn.delete('entry_tags', where: 'entry_id = ?', whereArgs: [entryId]);
    for (final tag in tags.toSet()) {
      await txn.insert('entry_tags', {'entry_id': entryId, 'tag': tag});
    }
  }

  /// Inserts a journal entry (and its feeling tags) into the encrypted database.
  static Future<int> insertJournalEntry({
    required String content,
    required int mood,
    List<String> tags = const [],
  }) async {
    if (mood < 1 || mood > 5) throw ArgumentError('mood must be 1 to 5');
    final db = await database;

    return db.transaction((txn) async {
      final id = await txn.insert('journal_entries', {
        'content': content,
        'mood': mood,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _writeTags(txn, id, tags);
      return id;
    });
  }

  /// Edits the text, mood and tags of an entry (FR-14).
  static Future<void> updateEntry({
    required int id,
    required String content,
    required int mood,
    List<String> tags = const [],
  }) async {
    if (mood < 1 || mood > 5) throw ArgumentError('mood must be 1 to 5');
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'journal_entries',
        {
          'content': content,
          'mood': mood,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _writeTags(txn, id, tags);
    });
  }

  /// Inserts a reflection linked to a journal entry.
  static Future<int> insertReflection({
    required int entryId,
    required String text,
    String? thinkingPattern,
    String? serverReflectionId,
  }) async {
    final db = await database;

    return db.insert('reflections', {
      'entry_id': entryId,
      'reflection_text': text,
      'thinking_pattern': thinkingPattern,
      'server_reflection_id': serverReflectionId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Keeps one reflection per entry: the new one replaces the old one.
  /// A new reflection starts as a draft until the user decides (FR-23).
  static Future<int> replaceReflection({
    required int entryId,
    required String text,
    String? thinkingPattern,
    String? serverReflectionId,
    String? partsJson,
    String source = 'unknown',
    String status = 'draft',
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      await txn.delete('reflections',
          where: 'entry_id = ?', whereArgs: [entryId]);
      return txn.insert('reflections', {
        'entry_id': entryId,
        'reflection_text': text,
        'thinking_pattern': thinkingPattern,
        'server_reflection_id': serverReflectionId,
        'created_at': DateTime.now().toIso8601String(),
        'parts_json': partsJson,
        'source': source,
        'status': status,
      });
    });
  }

  /// The reflection of an entry, or null.
  static Future<Map<String, dynamic>?> getReflection(int entryId) async {
    final db = await database;
    final rows = await db.query('reflections',
        where: 'entry_id = ?',
        whereArgs: [entryId],
        orderBy: 'id DESC',
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Accept a draft (FR-23).
  static Future<void> acceptReflection(int entryId) async {
    final db = await database;
    await db.update('reflections', {'status': 'accepted'},
        where: 'entry_id = ?', whereArgs: [entryId]);
  }

  /// Edit the reflection text. The edited text is kept as plain text and accepted.
  static Future<void> editReflection(int entryId, String text) async {
    final db = await database;
    await db.update(
        'reflections',
        {
          'reflection_text': text,
          'parts_json': null,
          'edited': 1,
          'status': 'accepted',
        },
        where: 'entry_id = ?',
        whereArgs: [entryId]);
  }

  /// Dismiss: the draft is deleted (FR-23).
  static Future<void> deleteReflection(int entryId) async {
    final db = await database;
    await db.delete('reflections',
        where: 'entry_id = ?', whereArgs: [entryId]);
  }

  /// Saves the user's rating on the phone (FR-24). [sent] says whether the
  /// server already has it. The rating never includes the entry text.
  static Future<void> setReflectionRating(
    int entryId, {
    required String rating,
    String? reason,
    bool sent = false,
  }) async {
    final db = await database;
    await db.update(
        'reflections',
        {
          'rating': rating,
          'rating_reason': reason,
          'rating_sent': sent ? 1 : 0,
        },
        where: 'entry_id = ?',
        whereArgs: [entryId]);
  }

  static Future<void> markRatingSent(int entryId) async {
    final db = await database;
    await db.update('reflections', {'rating_sent': 1},
        where: 'entry_id = ?', whereArgs: [entryId]);
  }

  static const String _entrySelect = '''
    SELECT e.id, e.content, e.mood, e.created_at, e.updated_at,
      (SELECT r.thinking_pattern FROM reflections r
         WHERE r.entry_id = e.id ORDER BY r.id DESC LIMIT 1) AS thinking_pattern,
      (SELECT r.reflection_text FROM reflections r
         WHERE r.entry_id = e.id ORDER BY r.id DESC LIMIT 1) AS reflection_text,
      (SELECT r.status FROM reflections r
         WHERE r.entry_id = e.id ORDER BY r.id DESC LIMIT 1) AS reflection_status,
      (SELECT group_concat(t.tag, ',') FROM entry_tags t
         WHERE t.entry_id = e.id) AS tags
    FROM journal_entries e
  ''';

  static String _escapeLike(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// FR-15: newest first, with optional keyword, date range and mood filters.
  /// The keyword matches the entry text and its feeling tags.
  static Future<List<Map<String, dynamic>>> searchEntries({
    String query = '',
    DateTime? from,
    DateTime? to,
    int? mood,
    int limit = 500,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    final q = query.trim();
    if (q.isNotEmpty) {
      final like = '%${_escapeLike(q)}%';
      where.add("(e.content LIKE ? ESCAPE '\\' OR EXISTS ("
          "SELECT 1 FROM entry_tags t WHERE t.entry_id = e.id "
          "AND t.tag LIKE ? ESCAPE '\\'))");
      args.addAll([like, like]);
    }
    if (from != null) {
      where.add('e.created_at >= ?');
      args.add(DateTime(from.year, from.month, from.day).toIso8601String());
    }
    if (to != null) {
      where.add('e.created_at < ?');
      args.add(DateTime(to.year, to.month, to.day)
          .add(const Duration(days: 1))
          .toIso8601String());
    }
    if (mood != null) {
      where.add('e.mood = ?');
      args.add(mood);
    }

    final sql = '$_entrySelect'
        '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}'
        ' ORDER BY e.created_at DESC LIMIT ?';
    args.add(limit);
    return db.rawQuery(sql, args);
  }

  /// One entry with its mood, tags and saved reflection (FR-16).
  static Future<Map<String, dynamic>?> getEntry(int id) async {
    final db = await database;
    final rows = await db.rawQuery('$_entrySelect WHERE e.id = ?', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Gets recent journal entries with their associated reflections.
  static Future<List<Map<String, dynamic>>> getRecentEntries({
    int limit = 5,
  }) =>
      searchEntries(limit: limit);

  /// Reads all journal entries from the encrypted database.
  static Future<List<Map<String, dynamic>>> getJournalEntries() async {
    final db = await database;

    return db.query(
      'journal_entries',
      orderBy: 'created_at DESC',
    );
  }

  /// Deletes a journal entry and everything attached to it (FR-14).
  static Future<void> deleteJournalEntry(int id) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('reflections', where: 'entry_id = ?', whereArgs: [id]);
      await txn.delete('entry_tags', where: 'entry_id = ?', whereArgs: [id]);
      await txn.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
    });
  }
}
