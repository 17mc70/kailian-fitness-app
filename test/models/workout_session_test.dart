import 'package:flutter_test/flutter_test.dart';
import 'package:kailian/models/workout_session.dart';

void main() {
  group('ExerciseSet', () {
    test('equality compares all fields', () {
      const a = ExerciseSet(setNumber: 1, reps: 10, weight: 20, isCompleted: true);
      const b = ExerciseSet(setNumber: 1, reps: 10, weight: 20, isCompleted: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when any field differs', () {
      const base = ExerciseSet(setNumber: 1, reps: 10, weight: 20);
      expect(base, isNot(equals(const ExerciseSet(setNumber: 2, reps: 10, weight: 20))));
      expect(base, isNot(equals(const ExerciseSet(setNumber: 1, reps: 12, weight: 20))));
      expect(base, isNot(equals(const ExerciseSet(setNumber: 1, reps: 10, weight: 25))));
      expect(base, isNot(equals(const ExerciseSet(setNumber: 1, reps: 10, weight: 20, isCompleted: true))));
    });

    test('estimatedOneRM returns 0 when weight is 0', () {
      const set = ExerciseSet(setNumber: 1, reps: 10, weight: 0);
      expect(set.estimatedOneRM, 0.0);
    });

    test('estimatedOneRM returns 0 when reps is 0', () {
      const set = ExerciseSet(setNumber: 1, reps: 0, weight: 20);
      expect(set.estimatedOneRM, 0.0);
    });

    test('estimatedOneRM uses Epley formula', () {
      // weight * (1 + reps / 30) = 20 * (1 + 10/30) = 20 * 1.333... = 26.666...
      const set = ExerciseSet(setNumber: 1, reps: 10, weight: 20);
      expect(set.estimatedOneRM, closeTo(26.6667, 0.001));
    });

    test('toMap / fromMap roundtrip', () {
      const set = ExerciseSet(setNumber: 2, reps: 8, weight: 30, isCompleted: true);
      final map = set.toMap();
      final restored = ExerciseSet.fromMap(map);
      expect(restored, equals(set));
    });

    test('fromMap defaults when keys missing', () {
      final restored = ExerciseSet.fromMap({});
      expect(restored.setNumber, 1);
      expect(restored.reps, 0);
      expect(restored.weight, 0.0);
      expect(restored.isCompleted, isFalse);
    });

    test('fromMap reads is_completed as int 1 = true', () {
      expect(ExerciseSet.fromMap({'is_completed': 1}).isCompleted, isTrue);
      expect(ExerciseSet.fromMap({'is_completed': 0}).isCompleted, isFalse);
      expect(ExerciseSet.fromMap({'is_completed': null}).isCompleted, isFalse);
    });

    test('copyWith only changes specified fields', () {
      const set = ExerciseSet(setNumber: 1, reps: 10, weight: 20);
      final copied = set.copyWith(reps: 12);
      expect(copied.setNumber, 1);
      expect(copied.reps, 12);
      expect(copied.weight, 20);
      expect(copied.isCompleted, isFalse);
    });
  });

  group('ExerciseLogEntry', () {
    test('totalReps sums all set reps', () {
      final log = ExerciseLogEntry(
        sessionId: 1,
        exerciseId: '001',
        exerciseName: 'Push Up',
        sets: [
          const ExerciseSet(setNumber: 1, reps: 10, weight: 0),
          const ExerciseSet(setNumber: 2, reps: 8, weight: 0),
          const ExerciseSet(setNumber: 3, reps: 6, weight: 0),
        ],
      );
      expect(log.totalReps, 24);
    });

    test('totalReps returns 0 for empty sets', () {
      final log = ExerciseLogEntry(
        sessionId: 1,
        exerciseId: '001',
        exerciseName: 'test',
        sets: [],
      );
      expect(log.totalReps, 0);
    });

    test('totalVolume sums reps * weight', () {
      final log = ExerciseLogEntry(
        sessionId: 1,
        exerciseId: '001',
        exerciseName: 'Squat',
        sets: [
          const ExerciseSet(setNumber: 1, reps: 10, weight: 20),
          const ExerciseSet(setNumber: 2, reps: 8, weight: 25),
        ],
      );
      // 10*20 + 8*25 = 200 + 200 = 400
      expect(log.totalVolume, 400.0);
    });

    test('maxOneRM returns best estimate across sets', () {
      final log = ExerciseLogEntry(
        sessionId: 1,
        exerciseId: '001',
        exerciseName: 'Bench',
        sets: [
          const ExerciseSet(setNumber: 1, reps: 10, weight: 20), // 26.67
          const ExerciseSet(setNumber: 2, reps: 5, weight: 40),  // 46.67
          const ExerciseSet(setNumber: 3, reps: 3, weight: 50),  // 55.0
        ],
      );
      expect(log.maxOneRM, closeTo(55.0, 0.01));
    });

    test('maxOneRM returns 0 for empty sets', () {
      final log = ExerciseLogEntry(
        sessionId: 1,
        exerciseId: '001',
        exerciseName: 'test',
        sets: [],
      );
      expect(log.maxOneRM, 0.0);
    });

    test('toMap / fromMap roundtrip', () {
      final log = ExerciseLogEntry(
        id: 5,
        sessionId: 1,
        exerciseId: '001',
        exerciseName: 'Press',
        sets: [
          const ExerciseSet(setNumber: 1, reps: 10, weight: 20),
          const ExerciseSet(setNumber: 2, reps: 8, weight: 25),
        ],
        notes: 'felt good',
      );

      final map = log.toMap();
      final restored = ExerciseLogEntry.fromMap(map);

      expect(restored.id, 5);
      expect(restored.sessionId, 1);
      expect(restored.exerciseId, '001');
      expect(restored.exerciseName, 'Press');
      expect(restored.sets.length, 2);
      expect(restored.sets[0], const ExerciseSet(setNumber: 1, reps: 10, weight: 20));
      expect(restored.sets[1], const ExerciseSet(setNumber: 2, reps: 8, weight: 25));
      expect(restored.notes, 'felt good');
    });

    test('fromMap handles invalid sets_data gracefully', () {
      final restored = ExerciseLogEntry.fromMap({
        'session_id': 1,
        'exercise_id': '001',
        'exercise_name': 'test',
        'sets_data': 'not valid json',
      });
      expect(restored.sets, isEmpty);
    });

    test('fromMap handles null sets_data', () {
      final restored = ExerciseLogEntry.fromMap({
        'session_id': 1,
        'exercise_id': '001',
        'exercise_name': 'test',
        'sets_data': null,
      });
      expect(restored.sets, isEmpty);
    });

    test('fromMap defaults when fields missing', () {
      final restored = ExerciseLogEntry.fromMap({});
      expect(restored.sessionId, 0);
      expect(restored.exerciseId, '');
      expect(restored.exerciseName, '');
      expect(restored.sets, isEmpty);
      expect(restored.notes, isNull);
    });

    test('isNew returns true when id is null', () {
      final log = ExerciseLogEntry(
        sessionId: 1, exerciseId: '001', exerciseName: 't', sets: []);
      expect(log.isNew, isTrue);
    });

    test('isNew returns false when id is not null', () {
      final log = ExerciseLogEntry(
        id: 1, sessionId: 1, exerciseId: '001', exerciseName: 't', sets: []);
      expect(log.isNew, isFalse);
    });
  });

  group('WorkoutSession', () {
    test('duration returns zero when endTime is null', () {
      final session = WorkoutSession(startTime: DateTime(2026, 7, 15, 10, 0));
      expect(session.duration, Duration.zero);
    });

    test('duration computes difference correctly', () {
      final session = WorkoutSession(
        startTime: DateTime(2026, 7, 15, 10, 0),
        endTime: DateTime(2026, 7, 15, 11, 30),
      );
      expect(session.duration, const Duration(hours: 1, minutes: 30));
    });

    test('totalSets only counts completed sets', () {
      final session = WorkoutSession(
        startTime: DateTime.now(),
        logs: [
          ExerciseLogEntry(
            sessionId: 1, exerciseId: '001', exerciseName: 'A',
            sets: [
              const ExerciseSet(setNumber: 1, reps: 10, weight: 0, isCompleted: true),
              const ExerciseSet(setNumber: 2, reps: 10, weight: 0, isCompleted: false),
            ],
          ),
          ExerciseLogEntry(
            sessionId: 1, exerciseId: '002', exerciseName: 'B',
            sets: [
              const ExerciseSet(setNumber: 1, reps: 8, weight: 0, isCompleted: true),
            ],
          ),
        ],
      );
      expect(session.totalSets, 2);
    });

    test('totalVolume sums all logs volume', () {
      final session = WorkoutSession(
        startTime: DateTime.now(),
        logs: [
          ExerciseLogEntry(
            sessionId: 1, exerciseId: '001', exerciseName: 'A',
            sets: [const ExerciseSet(setNumber: 1, reps: 10, weight: 20)],
          ),
          ExerciseLogEntry(
            sessionId: 1, exerciseId: '002', exerciseName: 'B',
            sets: [const ExerciseSet(setNumber: 1, reps: 8, weight: 30)],
          ),
        ],
      );
      // 200 + 240 = 440
      expect(session.totalVolume, 440.0);
    });

    test('toMap / fromMap roundtrip', () {
      final now = DateTime(2026, 7, 15, 10, 0, 0);
      final end = DateTime(2026, 7, 15, 11, 0, 0);
      final session = WorkoutSession(
        id: 1,
        planId: 2,
        planName: 'Upper Body',
        startTime: now,
        endTime: end,
        notes: 'good session',
      );

      final map = session.toMap();
      final restored = WorkoutSession.fromMap(map);

      expect(restored.id, 1);
      expect(restored.planId, 2);
      expect(restored.planName, 'Upper Body');
      expect(restored.notes, 'good session');
    });

    test('fromMap handles null end_time', () {
      final restored = WorkoutSession.fromMap({
        'id': 1,
        'start_time': '2026-07-15T10:00:00',
        'end_time': null,
      });
      expect(restored.endTime, isNull);
    });

    test('isNew returns true when id is null', () {
      final session = WorkoutSession(startTime: DateTime.now());
      expect(session.isNew, isTrue);
    });

    test('isNew returns false when id is not null', () {
      final session = WorkoutSession(id: 1, startTime: DateTime.now());
      expect(session.isNew, isFalse);
    });
  });
}
