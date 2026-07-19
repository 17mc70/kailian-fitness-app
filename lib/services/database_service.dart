import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/workout_templates.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';

class DatabaseService {
  static Database? _database;
  static Future<Database>? _pendingInit;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _pendingInit ??= _initDatabase();
    _database = await _pendingInit;
    _pendingInit = null;
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kailian.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workout_plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            exercise_ids TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE workout_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_id INTEGER,
            plan_name TEXT,
            start_time TEXT NOT NULL,
            end_time TEXT,
            notes TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE exercise_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            exercise_id TEXT NOT NULL,
            exercise_name TEXT NOT NULL,
            sets_data TEXT NOT NULL,
            notes TEXT,
            FOREIGN KEY (session_id) REFERENCES workout_sessions(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE favorite_exercises (
            exercise_id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL
          )
        ''');
        // Seed preset plans for new installations
        await _seedPresetPlans(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS exercise_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL,
              exercise_id TEXT NOT NULL,
              exercise_name TEXT NOT NULL,
              sets_data TEXT NOT NULL,
              notes TEXT,
              FOREIGN KEY (session_id) REFERENCES workout_sessions(id)
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS favorite_exercises (
              exercise_id TEXT PRIMARY KEY,
              created_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          // Seed preset plans for existing users upgrading
          await _seedPresetPlans(db);
        }
      },
    );
  }

  /// Seed preset workout plans into the database if no plans exist.
  static Future<void> _seedPresetPlans(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM workout_plans'),
    );
    if (count != null && count > 0) return; // already have plans

    final now = DateTime.now().toIso8601String();
    for (final tpl in workoutTemplates) {
      await db.insert('workout_plans', {
        'name': tpl.name,
        'description': '${tpl.description}\n${tpl.tagLine}',
        'exercise_ids': tpl.exerciseIds.join(','),
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // === Workout Plans ===

  static Future<int> savePlan(WorkoutPlan plan) async {
    final db = await database;
    if (plan.id != null) {
      await db.update(
        'workout_plans',
        plan.toMap(),
        where: 'id = ?',
        whereArgs: [plan.id],
      );
      return plan.id!;
    }
    return db.insert('workout_plans', plan.toMap());
  }

  static Future<List<WorkoutPlan>> getPlans() async {
    final db = await database;
    final maps = await db.query('workout_plans', orderBy: 'updated_at DESC');
    return maps.map((m) => WorkoutPlan.fromMap(m)).toList();
  }

  static Future<WorkoutPlan?> getPlan(int id) async {
    final db = await database;
    final maps = await db.query(
      'workout_plans',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return WorkoutPlan.fromMap(maps.first);
  }

  static Future<int> deletePlan(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.delete(
        'exercise_logs',
        where:
            'session_id IN (SELECT id FROM workout_sessions WHERE plan_id = ?)',
        whereArgs: [id],
      );
      await txn.delete(
        'workout_sessions',
        where: 'plan_id = ?',
        whereArgs: [id],
      );
      return txn.delete('workout_plans', where: 'id = ?', whereArgs: [id]);
    });
  }

  // === Workout Sessions ===

  static Future<int> saveSession(WorkoutSession session) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('workout_sessions', session.toMap());
      for (final log in session.logs) {
        await txn.insert('exercise_logs', {
          'session_id': id,
          'exercise_id': log.exerciseId,
          'exercise_name': log.exerciseName,
          'sets_data': jsonEncode(log.sets.map((s) => s.toMap()).toList()),
          'notes': log.notes ?? '',
        });
      }
      return id;
    });
  }

  static Future<void> updateSessionEndTime(int sessionId) async {
    final db = await database;
    await db.update(
      'workout_sessions',
      {'end_time': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  static Future<void> saveExerciseLog(ExerciseLogEntry log) async {
    final db = await database;
    await db.insert('exercise_logs', {
      'session_id': log.sessionId,
      'exercise_id': log.exerciseId,
      'exercise_name': log.exerciseName,
      'sets_data': jsonEncode(log.sets.map((s) => s.toMap()).toList()),
      'notes': log.notes ?? '',
    });
  }

  /// Save mid-workout checkpoint: upsert logs for this session.
  /// Uses INSERT OR REPLACE to avoid O(n²) delete+re-insert pattern.
  static Future<List<ExerciseLogEntry>> saveSessionCheckpoint(
    int sessionId,
    List<ExerciseLogEntry> logs,
  ) async {
    final db = await database;
    final updatedLogs = List<ExerciseLogEntry>.from(logs);
    await db.transaction((txn) async {
      // Get existing log IDs for this session
      final existing = await txn.rawQuery(
        'SELECT id FROM exercise_logs WHERE session_id = ?',
        [sessionId],
      );
      final existingIds = existing
          .map((r) => r['id'] as int?)
          .whereType<int>()
          .toSet();
      final currentIds = logs
          .where((l) => l.id != null)
          .map((l) => l.id!)
          .toSet();

      // Delete logs no longer in the current list
      final toDelete = existingIds.difference(currentIds);
      for (final id in toDelete) {
        await txn.delete('exercise_logs', where: 'id = ?', whereArgs: [id]);
      }

      // Upsert remaining logs
      for (var index = 0; index < logs.length; index++) {
        final log = logs[index];
        final data = <String, dynamic>{
          'session_id': sessionId,
          'exercise_id': log.exerciseId,
          'exercise_name': log.exerciseName,
          'sets_data': jsonEncode(log.sets.map((s) => s.toMap()).toList()),
          'notes': log.notes ?? '',
        };
        if (log.id != null && existingIds.contains(log.id)) {
          data['id'] = log.id;
          await txn.insert(
            'exercise_logs',
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          final insertedId = await txn.insert('exercise_logs', data);
          updatedLogs[index] = log.copyWith(id: insertedId);
        }
      }
    });
    return updatedLogs;
  }

  static Future<List<WorkoutSession>> getSessions({int? limit}) async {
    final db = await database;
    final maps = await db.query(
      'workout_sessions',
      orderBy: 'start_time DESC',
      limit: limit,
    );
    if (maps.isEmpty) return [];

    // Fetch all session IDs
    final sessionIds = maps
        .map((m) => m['id'] as int?)
        .whereType<int>()
        .toList();
    if (sessionIds.isEmpty) return [];

    // Single batch query for all logs
    final placeholders = sessionIds.map((_) => '?').join(',');
    final logMaps = await db.rawQuery(
      'SELECT * FROM exercise_logs WHERE session_id IN ($placeholders)',
      sessionIds,
    );

    // Group logs by session_id
    final Map<int, List<ExerciseLogEntry>> logsBySession = {};
    for (final m in logMaps) {
      final sid = m['session_id'] as int? ?? 0;
      logsBySession.putIfAbsent(sid, () => []).add(_parseLogEntry(m));
    }

    return maps.map((m) {
      final session = WorkoutSession.fromMap(m);
      final sid = session.id ?? 0;
      return WorkoutSession(
        id: session.id,
        planId: session.planId,
        planName: session.planName,
        startTime: session.startTime,
        endTime: session.endTime,
        notes: session.notes,
        logs: logsBySession[sid] ?? [],
      );
    }).toList();
  }

  static ExerciseLogEntry _parseLogEntry(Map<String, dynamic> m) {
    List<ExerciseSet> sets = [];
    try {
      final decoded = jsonDecode(m['sets_data'] as String? ?? '[]') as List;
      sets = decoded
          .map((s) => ExerciseSet.fromMap(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('_parseLogEntry: failed to parse sets_data: $e');
    }
    return ExerciseLogEntry(
      id: m['id'] as int?,
      sessionId: m['session_id'] as int? ?? 0,
      exerciseId: m['exercise_id'] as String? ?? '',
      exerciseName: m['exercise_name'] as String? ?? '',
      sets: sets,
      notes: m['notes'] as String?,
    );
  }

  static Future<Map<String, double>> getVolumeByDay(int days) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    final maps = await db.rawQuery(
      '''
      SELECT ws.start_time, el.sets_data
      FROM workout_sessions ws
      INNER JOIN exercise_logs el ON ws.id = el.session_id
      WHERE ws.start_time >= ?
    ''',
      [cutoff],
    );

    final Map<String, double> dailyVolume = {};
    for (final m in maps) {
      final startTime = m['start_time'] as String? ?? '';
      if (startTime.length < 10) continue;
      final date = startTime.substring(0, 10);
      try {
        final decoded = jsonDecode(m['sets_data'] as String? ?? '[]') as List;
        double volume = 0;
        for (final s in decoded) {
          volume +=
              ((s['reps'] as num?)?.toDouble() ?? 0) *
              ((s['weight'] as num?)?.toDouble() ?? 0);
        }
        dailyVolume[date] = (dailyVolume[date] ?? 0) + volume;
      } catch (e) {
        debugPrint('getVolumeByDay: failed to parse sets_data: $e');
      }
    }
    return dailyVolume;
  }

  static Future<int> getTotalWorkouts() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM workout_sessions',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<int> getTotalSets() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(json_array_length(sets_data)), 0) as total FROM exercise_logs',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('getTotalSets: $e');
      // Fallback for older SQLite without json_array_length
      final logs = await db.query('exercise_logs', columns: ['sets_data']);
      int total = 0;
      for (final m in logs) {
        try {
          final decoded = jsonDecode(m['sets_data'] as String? ?? '[]') as List;
          total += decoded.length;
        } catch (e) {
          debugPrint('getTotalSets: failed to parse sets_data: $e');
        }
      }
      return total;
    }
  }

  static Future<double> getTotalVolume() async {
    final db = await database;
    final rows = await db.query('exercise_logs', columns: ['sets_data']);
    var total = 0.0;
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row['sets_data'] as String? ?? '[]') as List;
        for (final rawSet in decoded) {
          final set = rawSet as Map<String, dynamic>;
          total +=
              ((set['reps'] as num?)?.toDouble() ?? 0) *
              ((set['weight'] as num?)?.toDouble() ?? 0);
        }
      } catch (e) {
        debugPrint('getTotalVolume: failed to parse sets_data: $e');
      }
    }
    return total;
  }

  // === Favorites ===

  static final Set<String> _favoriteCache = {};

  static void invalidateFavoritesCache() {
    _favoriteCache.clear();
  }

  static Future<Set<String>> getFavoriteIds() async {
    if (_favoriteCache.isNotEmpty) return _favoriteCache;
    final db = await database;
    final rows = await db.query('favorite_exercises');
    _favoriteCache.addAll(rows.map((r) => r['exercise_id'] as String));
    return _favoriteCache;
  }

  static Future<bool> isFavorite(String exerciseId) async {
    if (_favoriteCache.isEmpty) await getFavoriteIds();
    return _favoriteCache.contains(exerciseId);
  }

  static Future<void> toggleFavorite(String exerciseId) async {
    final db = await database;
    if (_favoriteCache.isEmpty) await getFavoriteIds();
    if (_favoriteCache.contains(exerciseId)) {
      await db.delete(
        'favorite_exercises',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
      );
      _favoriteCache.remove(exerciseId);
    } else {
      await db.insert('favorite_exercises', {
        'exercise_id': exerciseId,
        'created_at': DateTime.now().toIso8601String(),
      });
      _favoriteCache.add(exerciseId);
    }
  }
}
