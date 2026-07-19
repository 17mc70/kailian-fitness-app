import 'package:flutter_test/flutter_test.dart';

import 'package:kailian/agent/fitness_agent.dart';
import 'package:kailian/agent/fitness_agent_tools.dart';
import 'package:kailian/services/exercise_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tool schemas expose the read-only Agent capabilities', () {
    final names = FitnessAgentTools.schemas
        .map((schema) => (schema['function'] as Map)['name'])
        .toSet();

    expect(names, contains('search_exercises'));
    expect(names, contains('get_exercise_detail'));
    expect(names, contains('get_workout_history'));
    expect(names, contains('get_workout_plans'));
  });

  test('unknown tools return a safe result', () async {
    final result = await FitnessAgentTools.execute('unknown', {});

    expect(result.content, contains('未知工具'));
    expect(result.relatedExerciseIds, isEmpty);
  });

  test('exercise detail returns a related exercise id', () async {
    await ExerciseService.loadExercises();
    final exercise = ExerciseService.all.first;

    final result = await FitnessAgentTools.execute('get_exercise_detail', {
      'id': exercise.id,
    });

    expect(result.content, contains(exercise.name));
    expect(result.relatedExerciseIds, contains(exercise.id));
  });

  test('agent actions map common intents to explicit UI actions', () {
    expect(
      suggestAgentActions('帮我生成一份训练计划').single.kind,
      AgentActionKind.createPlan,
    );
    expect(
      suggestAgentActions('分析我的训练表现').single.kind,
      AgentActionKind.openProgress,
    );
    expect(
      suggestAgentActions('开始今天的训练').single.kind,
      AgentActionKind.startQuickWorkout,
    );
  });
}
