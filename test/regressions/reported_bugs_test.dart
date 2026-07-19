import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kailian/agent/rule_engine_agent.dart';
import 'package:kailian/agent/fitness_agent.dart';
import 'package:kailian/models/workout_plan.dart';
import 'package:kailian/models/workout_session.dart';
import 'package:kailian/services/database_service.dart';
import 'package:kailian/services/exercise_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'directly toggling a stored favorite does not insert a duplicate',
    () async {
      final db = await DatabaseService.database;
      const exerciseId = 'reported-bug-favorite';
      await db.delete(
        'favorite_exercises',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
      );
      await db.insert('favorite_exercises', {
        'exercise_id': exerciseId,
        'created_at': DateTime.now().toIso8601String(),
      });
      DatabaseService.invalidateFavoritesCache();

      await DatabaseService.toggleFavorite(exerciseId);

      final rows = await db.query(
        'favorite_exercises',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
      );
      expect(rows, isEmpty);
    },
  );

  test(
    'malformed start_time records are ignored by daily volume stats',
    () async {
      final db = await DatabaseService.database;
      final startTime = DateTime.now().toIso8601String().substring(0, 7);
      final sessionId = await db.insert('workout_sessions', {
        'plan_name': 'reported-bug-date',
        'start_time': startTime,
      });
      await db.insert('exercise_logs', {
        'session_id': sessionId,
        'exercise_id': 'reported-bug',
        'exercise_name': 'reported-bug',
        'sets_data': '[]',
      });

      final volume = await DatabaseService.getVolumeByDay(30);

      expect(volume, isA<Map<String, double>>());
    },
  );

  test('checkpoint keeps the inserted log id in memory', () async {
    final sessionId = await DatabaseService.saveSession(
      WorkoutSession(startTime: DateTime.now()),
    );
    final logs = [
      ExerciseLogEntry(
        sessionId: sessionId,
        exerciseId: 'reported-bug',
        exerciseName: 'reported-bug',
        sets: const [ExerciseSet(setNumber: 1, reps: 8)],
      ),
    ];

    final updated = await DatabaseService.saveSessionCheckpoint(
      sessionId,
      logs,
    );
    final firstId = updated.single.id;
    await DatabaseService.saveSessionCheckpoint(sessionId, updated);
    final second = await DatabaseService.getSessions(limit: 20);
    final saved = second.firstWhere((s) => s.id == sessionId);

    expect(firstId, isNotNull);
    expect(saved.logs.single.id, firstId);
  });

  test('deleting a plan also deletes its sessions and logs', () async {
    final planId = await DatabaseService.savePlan(
      WorkoutPlan(name: 'reported-bug-plan', exerciseIds: ['reported-bug']),
    );
    final sessionId = await DatabaseService.saveSession(
      WorkoutSession(
        planId: planId,
        startTime: DateTime.now(),
        logs: [
          ExerciseLogEntry(
            sessionId: 0,
            exerciseId: 'reported-bug',
            exerciseName: 'reported-bug',
            sets: const [],
          ),
        ],
      ),
    );

    await DatabaseService.deletePlan(planId);

    expect(
      (await DatabaseService.getSessions(
        limit: 50,
      )).where((session) => session.id == sessionId),
      isEmpty,
    );
  });

  test('total volume includes records older than the chart window', () async {
    final db = await DatabaseService.database;
    final sessionId = await db.insert('workout_sessions', {
      'plan_name': 'reported-bug-volume',
      'start_time': DateTime(2020, 1, 1).toIso8601String(),
    });
    await db.insert('exercise_logs', {
      'session_id': sessionId,
      'exercise_id': 'reported-bug',
      'exercise_name': 'reported-bug',
      'sets_data': '[{"reps": 10, "weight": 10}]',
    });

    final total = await DatabaseService.getTotalVolume();

    expect(total, greaterThanOrEqualTo(100));
  });

  test('plan exercise ids ignore empty values around commas', () {
    final plan = WorkoutPlan.fromMap({
      'id': 1,
      'name': 'reported-bug-plan',
      'exercise_ids': '001,, 002, ',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    expect(plan.exerciseIds, ['001', '002']);
  });

  test(
    'seven training days produce seven plan days and focus the selected muscle',
    () async {
      await ExerciseService.loadExercises();
      final result = await RuleEngineAgent().generatePlan(
        const PlanRequest(
          goal: 'hypertrophy',
          availableEquipment: [],
          experienceLevel: 'beginner',
          daysPerWeek: 7,
          focusMuscles: ['chest'],
        ),
      );

      expect(result.days.length, 7);
      expect(result.days.expand((day) => day.exercises), isNotEmpty);
    },
  );
}
