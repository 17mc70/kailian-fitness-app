import 'package:flutter_test/flutter_test.dart';
import 'package:kailian/models/exercise.dart';

void main() {
  group('Exercise.fromJson', () {
    test('parses minimal JSON with defaults', () {
      final e = Exercise.fromJson({'id': '001', 'name': 'test'});
      expect(e.id, '001');
      expect(e.name, 'test');
      expect(e.category, '');
      expect(e.bodyPart, '');
      expect(e.equipment, '');
      expect(e.muscleGroup, '');
      expect(e.secondaryMuscles, isEmpty);
      expect(e.target, '');
      expect(e.image, 'assets/');
      expect(e.gifUrl, 'assets/');
      expect(e.mediaId, '');
      expect(e.instructions, isEmpty);
      expect(e.instructionSteps, isEmpty);
    });

    test('prepends assets/ prefix to image path', () {
      final e = Exercise.fromJson({'image': 'images/foo.jpg'});
      expect(e.image, 'assets/images/foo.jpg');
    });

    test('does not double-prepend assets/ prefix', () {
      final e = Exercise.fromJson({'image': 'assets/images/foo.jpg'});
      expect(e.image, 'assets/images/foo.jpg');
    });

    test('handles empty image path', () {
      final e = Exercise.fromJson({'image': ''});
      expect(e.image, 'assets/');
    });

    test('reads gif_url (snake_case) and prepends assets/', () {
      final e = Exercise.fromJson({'gif_url': 'videos/demo.gif'});
      expect(e.gifUrl, 'assets/videos/demo.gif');
    });

    test('falls back to gifUrl (camelCase)', () {
      final e = Exercise.fromJson({'gifUrl': 'videos/demo.gif'});
      expect(e.gifUrl, 'assets/videos/demo.gif');
    });

    test('reads body_part (snake_case)', () {
      final e = Exercise.fromJson({'body_part': 'chest'});
      expect(e.bodyPart, 'chest');
    });

    test('falls back to bodyPart (camelCase)', () {
      final e = Exercise.fromJson({'bodyPart': 'chest'});
      expect(e.bodyPart, 'chest');
    });

    test('snake_case takes priority over camelCase for bodyPart', () {
      final e = Exercise.fromJson({'body_part': 'back', 'bodyPart': 'chest'});
      expect(e.bodyPart, 'back');
    });

    test('parses secondary_muscles as list', () {
      final e = Exercise.fromJson({'secondary_muscles': ['biceps', 'forearms']});
      expect(e.secondaryMuscles, ['biceps', 'forearms']);
    });

    test('secondary_muscles non-list defaults to empty', () {
      final e = Exercise.fromJson({'secondary_muscles': 'oops'});
      expect(e.secondaryMuscles, isEmpty);
    });

    test('parses instruction_steps as map of lang to list', () {
      final e = Exercise.fromJson({
        'instruction_steps': {
          'zh': ['步骤一', '步骤二'],
          'en': ['step1', 'step2'],
        },
      });
      expect(e.instructionSteps['zh'], ['步骤一', '步骤二']);
      expect(e.instructionSteps['en'], ['step1', 'step2']);
    });

    test('instruction_steps non-map defaults to empty', () {
      final e = Exercise.fromJson({'instruction_steps': 'not a map'});
      expect(e.instructionSteps, isEmpty);
    });

    test('skips non-list values in instruction_steps', () {
      final e = Exercise.fromJson({
        'instruction_steps': {
          'zh': 'not a list',
        },
      });
      expect(e.instructionSteps, isEmpty);
    });

    test('parses instructions as map of strings', () {
      final e = Exercise.fromJson({
        'instructions': {
          'zh': '中文说明',
          'en': 'english instruction',
        },
      });
      expect(e.instructions['zh'], '中文说明');
      expect(e.instructions['en'], 'english instruction');
    });

    test('instructions non-map defaults to empty', () {
      final e = Exercise.fromJson({'instructions': 'not a map'});
      expect(e.instructions, isEmpty);
    });

    test('handles numeric id', () {
      final e = Exercise.fromJson({'id': 123});
      expect(e.id, '123');
    });

    test('handles media_id (snake_case) and mediaId (camelCase)', () {
      final e1 = Exercise.fromJson({'media_id': 'abc'});
      expect(e1.mediaId, 'abc');

      final e2 = Exercise.fromJson({'mediaId': 'def'});
      expect(e2.mediaId, 'def');
    });
  });

  group('Exercise.getInstruction', () {
    test('returns exact lang when available', () {
      final e = Exercise.fromJson({
        'instructions': {'zh': '中文', 'en': 'english'},
      });
      expect(e.getInstruction('en'), 'english');
    });

    test('falls back to zh when lang not found', () {
      final e = Exercise.fromJson({
        'instructions': {'zh': '中文'},
      });
      expect(e.getInstruction('fr'), '中文');
    });

    test('falls back to en when zh not found', () {
      final e = Exercise.fromJson({
        'instructions': {'en': 'english'},
      });
      expect(e.getInstruction('fr'), 'english');
    });

    test('returns empty string when nothing found', () {
      final e = Exercise.fromJson({'instructions': {}});
      expect(e.getInstruction('fr'), '');
    });
  });

  group('Exercise.getSteps', () {
    test('returns exact lang when available', () {
      final e = Exercise.fromJson({
        'instruction_steps': {'en': ['step1']},
      });
      expect(e.getSteps('en'), ['step1']);
    });

    test('falls back to zh when lang not found', () {
      final e = Exercise.fromJson({
        'instruction_steps': {'zh': ['步骤一']},
      });
      expect(e.getSteps('fr'), ['步骤一']);
    });

    test('falls back to en when zh not found', () => () {
      final e = Exercise.fromJson({
        'instruction_steps': {'en': ['step1']},
      });
      expect(e.getSteps('fr'), ['step1']);
    });

    test('returns empty list when nothing found', () {
      final e = Exercise.fromJson({});
      expect(e.getSteps('fr'), isEmpty);
    });
  });

  group('Exercise.toJson', () {
    test('roundtrip preserves all fields', () {
      final json = {
        'id': '001',
        'name': 'Push Up',
        'category': 'strength',
        'body_part': 'chest',
        'equipment': 'body weight',
        'muscle_group': 'pectorals',
        'secondary_muscles': ['triceps', 'shoulders'],
        'target': 'upper body',
        'image': 'assets/images/pushup.jpg',
        'gif_url': 'assets/videos/pushup.gif',
        'media_id': 'abc123',
        'instructions': {'zh': '中文'},
        'instruction_steps': {'zh': ['步骤一']},
      };
      final e = Exercise.fromJson(json);
      final output = e.toJson();
      expect(output, json);
    });
  });
}
