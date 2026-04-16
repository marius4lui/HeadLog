import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/daily_headache_stat.dart';
import '../models/headache_entry.dart';

final headacheDatabaseProvider = Provider<HeadacheDatabase>((ref) {
  throw UnimplementedError('Database must be overridden in main().');
});

class HeadacheDatabase {
  static const _databaseName = 'headlog.db';
  static const _databaseVersion = 1;
  static const _entriesTable = 'headache_entries';

  Database? _database;

  Future<void> initialize() async {
    if (_database != null) {
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_entriesTable (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            intensity INTEGER NOT NULL,
            note TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_headache_entries_timestamp '
          'ON $_entriesTable(timestamp DESC)',
        );
      },
    );
  }

  Database get _db {
    final db = _database;
    if (db == null) {
      throw StateError('Database has not been initialized.');
    }
    return db;
  }

  Future<List<HeadacheEntry>> fetchRecentEntries({int limit = 30}) async {
    final rows = await _db.query(
      _entriesTable,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return rows.map(HeadacheEntry.fromMap).toList(growable: false);
  }

  Future<void> insertEntry(HeadacheEntry entry) {
    return _db.insert(
      _entriesTable,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEntry(String id) {
    return _db.delete(_entriesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DailyHeadacheStat>> fetchDailyCounts({int days = 7}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT substr(timestamp, 1, 10) AS day, COUNT(*) AS count
      FROM $_entriesTable
      WHERE timestamp >= ?
      GROUP BY day
      ORDER BY day DESC
      LIMIT ?
      ''',
      [
        DateTime.now().subtract(Duration(days: days - 1)).toIso8601String(),
        days,
      ],
    );

    return rows
        .map((row) {
          final day = DateTime.parse('${row['day']}T00:00:00');
          final count = row['count'] as int? ?? 0;
          return DailyHeadacheStat(dayStart: day, count: count);
        })
        .toList(growable: false);
  }
}
