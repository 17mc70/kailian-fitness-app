import '../services/database_service.dart';
import '../services/exercise_retriever.dart';
import '../services/exercise_service.dart';
import '../utils/exercise_labels.dart';

/// Read-only tools shared by online and offline Agent implementations.
///
/// The Agent may inspect app data, but writes remain explicit UI actions.
class FitnessAgentTools {
  FitnessAgentTools._();

  static const schemas = <Map<String, dynamic>>[
    {
      'type': 'function',
      'function': {
        'name': 'search_exercises',
        'description': '按中文或英文关键词搜索动作库，返回最相关的动作。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '例如：哑铃练肩、绳索练背'},
            'limit': {'type': 'integer', 'description': '返回数量，1 到 20'},
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_exercise_detail',
        'description': '按动作 ID 获取动作步骤和目标肌群。',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'description': '动作 ID'},
          },
          'required': ['id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_workout_history',
        'description': '读取用户最近的训练记录，用于分析训练量和训练频率。',
        'parameters': {
          'type': 'object',
          'properties': {
            'days': {'type': 'integer', 'description': '回溯天数，1 到 365'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_workout_plans',
        'description': '读取用户已经保存的训练计划。',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
  ];

  static Future<AgentToolResult> execute(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'search_exercises':
        return _searchExercises(args);
      case 'get_exercise_detail':
        return _getExerciseDetail(args);
      case 'get_workout_history':
        return _getWorkoutHistory(args);
      case 'get_workout_plans':
        return _getWorkoutPlans();
      default:
        return AgentToolResult(content: '未知工具：$name');
    }
  }

  static AgentToolResult _searchExercises(Map<String, dynamic> args) {
    final query = args['query'] as String? ?? '';
    final rawLimit = (args['limit'] as num?)?.toInt() ?? 10;
    final limit = rawLimit.clamp(1, 20);
    final results = ExerciseRetriever.retrieve(query, limit: limit);
    if (results.isEmpty) {
      return AgentToolResult(content: '没有找到匹配「$query」的动作。');
    }

    return AgentToolResult(
      content: results
          .map(
            (e) =>
                '- ID:${e.id} | ${e.name} | '
                '${ExerciseLabels.category(e.category)} | '
                '${ExerciseLabels.equipment(e.equipment)} | '
                '目标：${ExerciseLabels.target(e.target)}',
          )
          .join('\n'),
      relatedExerciseIds: results.map((e) => e.id).toList(),
    );
  }

  static AgentToolResult _getExerciseDetail(Map<String, dynamic> args) {
    final id = args['id'] as String? ?? '';
    final exercise = ExerciseService.findById(id);
    if (exercise == null) {
      return AgentToolResult(content: '没有找到 ID 为 $id 的动作。');
    }

    final steps = exercise.getSteps('zh');
    final stepText = steps.isEmpty
        ? '暂无步骤数据'
        : steps
              .asMap()
              .entries
              .map((e) => '${e.key + 1}. ${e.value}')
              .join('\n');

    return AgentToolResult(
      content:
          '${exercise.name}\n'
          '目标肌群：${ExerciseLabels.target(exercise.target)} | '
          '器材：${ExerciseLabels.equipment(exercise.equipment)}\n'
          '步骤：\n$stepText',
      relatedExerciseIds: [exercise.id],
    );
  }

  static Future<AgentToolResult> _getWorkoutHistory(
    Map<String, dynamic> args,
  ) async {
    final rawDays = (args['days'] as num?)?.toInt() ?? 30;
    final days = rawDays.clamp(1, 365);
    final sessions = await DatabaseService.getSessions(limit: 50);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = sessions.where((s) => s.startTime.isAfter(cutoff)).toList();

    if (recent.isEmpty) {
      return AgentToolResult(content: '过去 $days 天没有训练记录。');
    }

    final buffer = StringBuffer('过去 $days 天共完成 ${recent.length} 次训练：\n');
    for (final session in recent) {
      buffer.writeln(
        '- ${session.startTime.toString().substring(0, 10)}：'
        '${session.logs.length} 个动作，总容量 '
        '${session.totalVolume.toStringAsFixed(0)} kg',
      );
    }
    return AgentToolResult(content: buffer.toString().trim());
  }

  static Future<AgentToolResult> _getWorkoutPlans() async {
    final plans = await DatabaseService.getPlans();
    if (plans.isEmpty) {
      return const AgentToolResult(content: '还没有保存的训练计划。');
    }

    return AgentToolResult(
      content: plans
          .map((plan) => '- ${plan.name}：${plan.exerciseIds.length} 个动作')
          .join('\n'),
    );
  }
}

class AgentToolResult {
  final String content;
  final List<String> relatedExerciseIds;

  const AgentToolResult({
    required this.content,
    this.relatedExerciseIds = const [],
  });
}
