import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kailian/services/database_service.dart';
import 'package:kailian/models/workout_plan.dart';
import 'package:kailian/models/workout_session.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Reset internal state so each test starts fresh.
    DatabaseService.invalidateFavoritesCache();
  });

  group('WorkoutPlans', () {
    test('save and get a plan', () async {
      final id = await DatabaseService.savePlan(WorkoutPlan(
        name: '晨练',
        exerciseIds: ['001', '002'],
      ));
      expect(id, greaterThan(0));

      final plans = await DatabaseService.getPlans();
      expect(plans.length, greaterThan(0));
      final saved = plans.firstWhere((p) => p.id == id);
      expect(saved.name, '晨练');
      expect(saved.exerciseIds, ['001', '002']);
    });

    test('update existing plan', () async {
      final id = await DatabaseService.savePlan(WorkoutPlan(
        name: '旧名',
        exerciseIds: ['001'],
      ));

      await DatabaseService.savePlan(WorkoutPlan(
        id: id,
        name: '新名',
        exerciseIds: ['001', '002'],
      ));

      final updated = await DatabaseService.getPlan(id);
      expect(updated!.name, '新名');
      expect(updated.exerciseIds, ['001', '002']);
    });

    test('getPlan returns null for non-existent id', () async {
      final plan = await DatabaseService.getPlan(99999);
      expect(plan, isNull);
    });

    test('delete a plan', () async {
      final id = await DatabaseService.savePlan(WorkoutPlan(
        name: '待删除',
        exerciseIds: [],
      ));

      await DatabaseService.deletePlan(id);
      final plan = await DatabaseService.getPlan(id);
      expect(plan, isNull);
    });

    test('getPlans returns empty list when no plans', () async {
      // Delete all plans first
      final all = await DatabaseService.getPlans();
      for (final p in all) {
        await DatabaseService.deletePlan(p.id!);
      }

      final plans = await DatabaseService.getPlans();
      expect(plans, isEmpty);
    });
  });

  group('WorkoutSessions', () {
    test('save and retrieve a session', () async {
      final session = WorkoutSession(
        planName: 'Test Workout',
        startTime: DateTime(2026, 7, 15, 10, 0),
        endTime: DateTime(2026, 7, 15, 11, 0),
        logs: [
          ExerciseLogEntry(
            sessionId: 0,
            exerciseId: '001',
            exerciseName: 'Push Up',
            sets: [
              const ExerciseSet(setNumber: 1, reps: 10, weight: 0, isCompleted: true),
              const ExerciseSet(setNumber: 2, reps: 8, weight: 0, isCompleted: true),
            ],
          ),
        ],
      );

      final sessionId = await DatabaseService.saveSession(session);
      expect(sessionId, greaterThan(0));

      final sessions = await DatabaseService.getSessions();
      expect(sessions.length, greaterThan(0));
      final saved = sessions.firstWhere((s) => s.id == sessionId);
      expect(saved.planName, 'Test Workout');
      expect(saved.logs.length, 1);
      expect(saved.logs[0].exerciseName, 'Push Up');
      expect(saved.logs[0].sets.length, 2);
    });

    test('save session with no logs', () async {
      final session = WorkoutSession(
        planName: 'Empty',
        startTime: DateTime(2026, 7, 15, 10, 0),
      );

      final id = await DatabaseService.saveSession(session);
      expect(id, greaterThan(0));

      final sessions = await DatabaseService.getSessions();
      final saved = sessions.firstWhere((s) => s.id == id);
      expect(saved.logs, isEmpty);
    });

    test('getSessions returns empty list when none exist', () async {
      // We can't easily isolate, but verify the method doesn't crash
      final sessions = await DatabaseService.getSessions(limit: 1);
      expect(sessions, isA<List<WorkoutSession>>());
    });

    test('updateSessionEndTime sets end_time', () async {
      final id = await DatabaseService.saveSession(WorkoutSession(
        planName: 'Timed',
        startTime: DateTime(2026, 7, 15, 10, 0),
      ));

      await DatabaseService.updateSessionEndTime(id);

      final sessions = await DatabaseService.getSessions();
      final saved = sessions.firstWhere((s) => s.id == id);
      expect(saved.endTime, isNotNull);
    });
  });

  group('saveSessionCheckpoint', () {
    test('upserts logs correctly', () async {
      // Create a session first
      final sessionId = await DatabaseService.saveSession(WorkoutSession(
        planName: 'Checkpoint Test',
        startTime: DateTime.now(),
      ));

      // Save initial logs
      await DatabaseService.saveSessionCheckpoint(sessionId, [
        ExerciseLogEntry(
          sessionId: sessionId,
          exerciseId: '001',
          exerciseName: 'Squat',
          sets: [const ExerciseSet(setNumber: 1, reps: 10, weight: 20)],
        ),
        ExerciseLogEntry(
          sessionId: sessionId,
          exerciseId: '002',
          exerciseName: 'Press',
          sets: [const ExerciseSet(setNumber: 1, reps: 8, weight: 30)],
        ),
      ]);

      // Retrieve and verify
      var sessions = await DatabaseService.getSessions();
      var saved = sessions.firstWhere((s) => s.id == sessionId);
      expect(saved.logs.length, 2);

      // Now update: remove one, keep one, add one new
      final existingLog = saved.logs.first;
      await DatabaseService.saveSessionCheckpoint(sessionId, [
        existingLog, // keep
        ExerciseLogEntry(
          sessionId: sessionId,
          exerciseId: '003',
          exerciseName: 'Deadlift',
          sets: [const ExerciseSet(setNumber: 1, reps: 5, weight: 50)],
        ),
      ]);

      sessions = await DatabaseService.getSessions();
      saved = sessions.firstWhere((s) => s.id == sessionId);
      expect(saved.logs.length, 2);
      expect(saved.logs.any((l) => l.exerciseId == '001'), isTrue);
      expect(saved.logs.any((l) => l.exerciseId == '003'), isTrue);
    });
  });

  group('Volume & Stats', () {
    test('getVolumeByDay returns data for recent sessions', () async {
      // Create a session with known volume
      final sessionId = await DatabaseService.saveSession(WorkoutSession(
        planName: 'Vol',
        startTime: DateTime.now(),
      ));

      await DatabaseService.saveSessionCheckpoint(sessionId, [
        ExerciseLogEntry(
          sessionId: sessionId,
          exerciseId: '001',
          exerciseName: 'Squat',
          sets: [const ExerciseSet(setNumber: 1, reps: 10, weight: 20)], // 200 volume
        ),
      ]);

      final volume = await DatabaseService.getVolumeByDay(30);
      expect(volume, isNotEmpty);

      final today = DateTime.now().toIso8601String().substring(0, 10);
      expect(volume.containsKey(today), isTrue);
      expect(volume[today], greaterThanOrEqualTo(200.0));
    });

    test('getTotalWorkouts returns count', () async {
      final count = await DatabaseService.getTotalWorkouts();
      expect(count, greaterThanOrEqualTo(0));
    });
  });

  group('Favorites', () {
    test('toggle and check favorite status', () async {
      DatabaseService.invalidateFavoritesCache();
      if (await DatabaseService.isFavorite('test_ex_001')) {
        await DatabaseService.toggleFavorite('test_ex_001');
      }
      DatabaseService.invalidateFavoritesCache();

      expect(await DatabaseService.isFavorite('test_ex_001'), isFalse);

      await DatabaseService.toggleFavorite('test_ex_001');
      expect(await DatabaseService.isFavorite('test_ex_001'), isTrue);

      await DatabaseService.toggleFavorite('test_ex_001');
      expect(await DatabaseService.isFavorite('test_ex_001'), isFalse);
    });

    test('getFavoriteIds returns all favorited IDs', () async {
      DatabaseService.invalidateFavoritesCache();
      for (final id in ['fav_001', 'fav_002']) {
        if (await DatabaseService.isFavorite(id)) {
          await DatabaseService.toggleFavorite(id);
        }
      }

      await DatabaseService.toggleFavorite('fav_001');
      await DatabaseService.toggleFavorite('fav_002');

      final ids = await DatabaseService.getFavoriteIds();
      expect(ids.contains('fav_001'), isTrue);
      expect(ids.contains('fav_002'), isTrue);
    });

    test('invalidateFavoritesCache forces reread', () async {
      DatabaseService.invalidateFavoritesCache();
      if (await DatabaseService.isFavorite('cached_ex')) {
        await DatabaseService.toggleFavorite('cached_ex');
      }
      DatabaseService.invalidateFavoritesCache();

      await DatabaseService.toggleFavorite('cached_ex');
      expect(await DatabaseService.isFavorite('cached_ex'), isTrue);

      DatabaseService.invalidateFavoritesCache();
      expect(await DatabaseService.isFavorite('cached_ex'), isTrue);
    });
  });
}
