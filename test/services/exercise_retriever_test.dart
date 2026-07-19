import 'package:flutter_test/flutter_test.dart';
import 'package:kailian/models/exercise.dart';
import 'package:kailian/services/exercise_retriever.dart';

/// Minimal fixture set covering distinct categories/equipment/targets.
final _fixtures = <Exercise>[
  Exercise.fromJson({
    'id': '001', 'name': 'cable row',
    'category': 'back', 'equipment': 'cable', 'target': 'lats',
  }),
  Exercise.fromJson({
    'id': '002', 'name': 'barbell bench press',
    'category': 'chest', 'equipment': 'barbell', 'target': 'pectorals',
  }),
  Exercise.fromJson({
    'id': '003', 'name': 'dumbbell biceps curl',
    'category': 'upper arms', 'equipment': 'dumbbell', 'target': 'biceps',
  }),
  Exercise.fromJson({
    'id': '004', 'name': 'pull-up',
    'category': 'back', 'equipment': 'body weight', 'target': 'lats',
  }),
];

void main() {
  group('ExerciseRetriever.retrieve', () {
    test('empty query returns empty', () {
      expect(ExerciseRetriever.retrieve('', source: _fixtures), isEmpty);
    });

    test('Chinese "绳索练背" recalls cable + back exercise on top', () {
      final r = ExerciseRetriever.retrieve('绳索练背', source: _fixtures);
      expect(r, isNotEmpty);
      // The cable+back exercise must outrank everything else.
      expect(r.first.id, '001');
    });

    test('Chinese "背" recalls both back exercises, excludes chest', () {
      final r = ExerciseRetriever.retrieve('背', source: _fixtures);
      final ids = r.map((e) => e.id).toSet();
      expect(ids, containsAll(['001', '004']));
      expect(ids, isNot(contains('002')));
    });

    test('Chinese "哑铃" filters to dumbbell equipment', () {
      final r = ExerciseRetriever.retrieve('哑铃', source: _fixtures);
      expect(r.map((e) => e.id), contains('003'));
      expect(r.map((e) => e.id), isNot(contains('001')));
    });

    test('English substring query still matches by name', () {
      final r = ExerciseRetriever.retrieve('bench', source: _fixtures);
      expect(r.first.id, '002');
    });

    test('respects the limit', () {
      final r = ExerciseRetriever.retrieve('背', source: _fixtures, limit: 1);
      expect(r.length, 1);
    });
  });
}
