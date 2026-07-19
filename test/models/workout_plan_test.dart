import 'package:flutter_test/flutter_test.dart';
import 'package:kailian/models/workout_plan.dart';

void main() {
  group('WorkoutPlan.toMap / fromMap', () {
    test('roundtrip preserves all fields', () {
      final now = DateTime(2026, 7, 15, 10, 0, 0);
      final plan = WorkoutPlan(
        id: 1,
        name: '上肢训练',
        description: '侧重推力动作',
        exerciseIds: ['001', '002', '003'],
        createdAt: now,
        updatedAt: now,
      );

      final map = plan.toMap();
      final restored = WorkoutPlan.fromMap(map);

      expect(restored.id, 1);
      expect(restored.name, '上肢训练');
      expect(restored.description, '侧重推力动作');
      expect(restored.exerciseIds, ['001', '002', '003']);
    });

    test('handles null description', () {
      final plan = WorkoutPlan(
        name: 'test',
        exerciseIds: [],
      );
      final map = plan.toMap();
      final restored = WorkoutPlan.fromMap(map);
      expect(restored.description, '');
    });

    test('handles empty exercise_ids string', () {
      final restored = WorkoutPlan.fromMap({
        'id': null,
        'name': 'test',
        'description': '',
        'exercise_ids': '',
        'created_at': '2026-07-15T10:00:00',
        'updated_at': '2026-07-15T10:00:00',
      });
      expect(restored.exerciseIds, isEmpty);
    });

    test('handles null exercise_ids', () {
      final restored = WorkoutPlan.fromMap({
        'id': null,
        'name': 'test',
        'description': null,
        'exercise_ids': null,
        'created_at': null,
        'updated_at': null,
      });
      expect(restored.exerciseIds, isEmpty);
      expect(restored.description, isNull);
    });

    test('parses single exercise ID', () {
      final restored = WorkoutPlan.fromMap({
        'name': 'test',
        'exercise_ids': '001',
        'created_at': '2026-07-15T10:00:00',
        'updated_at': '2026-07-15T10:00:00',
      });
      expect(restored.exerciseIds, ['001']);
    });

    test('handles invalid dates by falling back to now', () {
      final restored = WorkoutPlan.fromMap({
        'name': 'test',
        'exercise_ids': '',
        'created_at': 'not-a-date',
        'updated_at': 'not-a-date',
      });
      // Should parse to now — not exact, just verify not throwing
      expect(restored.createdAt.isAfter(DateTime(2020)), isTrue);
      expect(restored.updatedAt.isAfter(DateTime(2020)), isTrue);
    });

    test('null id means isNew', () {
      final plan = WorkoutPlan(name: 'new', exerciseIds: []);
      expect(plan.isNew, isTrue);

      final saved = WorkoutPlan(id: 5, name: 'saved', exerciseIds: []);
      expect(saved.isNew, isFalse);
    });

    test('id serialized as-is (nullable)', () {
      final withId = WorkoutPlan(id: 42, name: 'a', exerciseIds: []);
      expect(withId.toMap()['id'], 42);

      final withoutId = WorkoutPlan(name: 'b', exerciseIds: []);
      expect(withoutId.toMap()['id'], isNull);
    });
  });

  group('WorkoutPlan.copyWith', () {
    test('preserves createdAt but updates updatedAt', () {
      final now = DateTime(2026, 7, 15);
      final plan = WorkoutPlan(
        id: 1,
        name: 'original',
        exerciseIds: ['001'],
        createdAt: now,
        updatedAt: now,
      );

      final copied = plan.copyWith(name: 'modified');
      expect(copied.id, 1);
      expect(copied.name, 'modified');
      expect(copied.exerciseIds, ['001']);
      expect(copied.createdAt, now);
      expect(copied.updatedAt.isAfter(now), isTrue);
    });

    test('shallow copies exerciseIds list', () {
      final plan = WorkoutPlan(name: 'test', exerciseIds: ['001', '002']);
      final copied = plan.copyWith();
      expect(copied.exerciseIds, ['001', '002']);
      // Verify it's a different list object
      expect(identical(copied.exerciseIds, plan.exerciseIds), isFalse);
    });
  });
}
