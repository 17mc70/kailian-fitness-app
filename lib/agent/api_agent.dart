import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../services/exercise_service.dart';
import '../services/exercise_retriever.dart';
import '../services/database_service.dart';
import '../utils/exercise_labels.dart';
import 'fitness_agent_tools.dart';
import 'fitness_agent.dart';

/// An OpenAI-compatible API adapter that implements the [FitnessAgent]
/// interface. When enabled, delegates plan generation, analysis, and Q&A
/// to a remote LLM. Falls back to rule-engine-style responses on error.
class ApiAgent implements FitnessAgent {
  ApiAgentConfig config;

  ApiAgent(this.config);

  @override
  String get name => 'AI 教练 (API)';

  @override
  String get description => '接入外部 LLM 的 AI 教练，需要配置 API';

  @override
  bool get isAvailable => config.enabled && config.apiKey.isNotEmpty;

  /// The system prompt injected into every chat completion.
  String _systemPrompt(List<Exercise> exercises) {
    // Summarize available exercise categories for the LLM
    final catCounts = <String, int>{};
    final eqCounts = <String, int>{};
    for (final e in exercises) {
      catCounts[e.category] = (catCounts[e.category] ?? 0) + 1;
      eqCounts[e.equipment] = (eqCounts[e.equipment] ?? 0) + 1;
    }

    final catSummary = catCounts.entries
        .map(
          (e) =>
              '  - ${ExerciseLabels.category(e.key)} (${e.key}): ${e.value} 个',
        )
        .join('\n');
    final eqSummary = eqCounts.entries
        .map(
          (e) =>
              '  - ${ExerciseLabels.equipment(e.key)} (${e.key}): ${e.value} 个',
        )
        .join('\n');

    return '''你是一个专业的健身教练助手，你的名字是「开练教练」。你的知识库中有 ${exercises.length} 个练习动作的详细信息。

可用的练习类别：
$catSummary

可用器材：
$eqSummary

你可以帮助用户：
1. 根据目标（增肌/减脂/力量/耐力/塑形）、可用器材、经验水平生成训练计划
2. 分析训练进度数据，给出改进建议
3. 回答关于某个动作怎么做、练哪里、有什么注意事项
4. 提供锻炼小贴士、饮食建议等

回复时请用中文，语气友好专业，适当使用 emoji。回答要基于提供的练习数据，不要推荐数据库中不存在的动作。''';
  }

  @override
  Future<AgentPlanResult> generatePlan(PlanRequest request) async {
    final allExercises = ExerciseService.all;
    if (allExercises.isEmpty) {
      return const AgentPlanResult(
        title: '暂无数据',
        description: '请先加载练习数据',
        days: [],
      );
    }

    final goalLabel = _goalLabel(request.goal);
    final expLabel = _expLabel(request.experienceLevel);

    final userPrompt =
        '''
请为以下用户生成一份训练计划：
- 目标：$goalLabel (${request.goal})
- 经验水平：$expLabel (${request.experienceLevel})
- 每周训练天数：${request.daysPerWeek}
- 可用器材：${request.availableEquipment.join(', ')}

请以 JSON 格式回复，格式如下：
{
  "title": "计划标题",
  "description": "计划描述",
  "days": [
    {
      "dayName": "第1天 — 部位",
      "exercises": [
        {
          "exerciseId": "练习ID",
          "exerciseName": "练习名称",
          "sets": 3,
          "minReps": 8,
          "maxReps": 12,
          "restSeconds": "60-90s",
          "note": "注意事项"
        }
      ]
    }
  ]
}

请从可用练习数据中选取合适的 exerciseId。不要编造不存在的练习ID。
如果无法确定具体ID，可以在 exerciseId 中写 "unknown"。''';

    try {
      final jsonStr = await _chatCompletion(userPrompt);
      final result = _parsePlanResult(jsonStr, goalLabel, expLabel);
      return result;
    } catch (e) {
      debugPrint('ApiAgent.generatePlan error: $e');
      // Fallback — return a minimal result
      return AgentPlanResult(
        title: '$goalLabel · ${request.daysPerWeek}天/周',
        description: _planDescription(
          request.goal,
          request.daysPerWeek,
          request.experienceLevel,
        ),
        days: [],
        explanation: '（AI 计划生成暂时不可用，请使用内置规则引擎）',
      );
    }
  }

  @override
  Future<AgentAnalysis> analyzeProgress(List<WorkoutSession> sessions) async {
    if (sessions.isEmpty) {
      return const AgentAnalysis(
        insights: ['还没有训练记录，开始你的第一次训练吧！'],
        suggestions: ['尝试使用「AI 推荐计划」生成一份训练计划'],
      );
    }

    final recentSessions = sessions.take(10).toList();
    final sb = StringBuffer();
    sb.writeln('以下是最近 ${recentSessions.length} 次训练记录：');
    for (var i = 0; i < recentSessions.length; i++) {
      final s = recentSessions[i];
      sb.writeln('训练 ${i + 1}: ${s.startTime.toString().substring(0, 10)}');
      sb.writeln('  总容量: ${s.totalVolume.toStringAsFixed(0)} kg');
      sb.writeln('  完成组数: ${s.totalSets}');
      sb.writeln('  动作:');
      for (final log in s.logs) {
        final setsStr = log.sets
            .where((s) => s.isCompleted)
            .map((s) => '${s.reps}次×${s.weight}kg')
            .join(', ');
        sb.writeln('    - ${log.exerciseName}: $setsStr');
      }
    }
    sb.writeln('\n请分析这份训练数据，给出 3-5 条具体的建议。');

    try {
      final response = await _chatCompletion(sb.toString());
      return AgentAnalysis(insights: [response], suggestions: []);
    } catch (e) {
      debugPrint('ApiAgent.analyzeProgress error: $e');
      return const AgentAnalysis(
        insights: ['AI 分析暂时不可用，请查看「进度」页面的统计数据'],
        suggestions: [],
      );
    }
  }

  @override
  Future<AgentAnswer> answerQuery(
    String query, {
    List<Exercise>? contextExercises,
    List<ChatTurn>? history,
  }) async {
    final allExercises = ExerciseService.all;
    if (allExercises.isEmpty) {
      return const AgentAnswer(answer: '还没有加载练习数据，请稍后再试', usedApi: true);
    }

    // Build the message stack: system + prior turns + current question.
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(allExercises)},
      for (final turn in history ?? const <ChatTurn>[])
        {'role': turn.role, 'content': turn.content},
      {'role': 'user', 'content': query},
    ];

    try {
      final (answer, ids) = await _agenticChat(messages);
      return AgentAnswer(
        answer: answer,
        usedApi: true,
        relatedExerciseIds: ids.toList(),
        actions: suggestAgentActions(query),
      );
    } catch (e) {
      debugPrint('ApiAgent.answerQuery error: $e');
      final msg = e.toString();
      return AgentAnswer(
        answer:
            'AI 服务暂时不可用（${msg.length > 80 ? msg.substring(0, 80) : msg}），请稍后再试或使用离线教练',
        usedApi: true,
        actions: suggestAgentActions(query),
      );
    }
  }

  @override
  Future<String> getExerciseTip(Exercise exercise) async {
    final steps = exercise.getSteps('zh');
    final target = ExerciseLabels.target(exercise.target);

    final userPrompt =
        '''
请为动作「${exercise.name}」(目标肌群: $target) 提供详细的训练指导。

步骤说明：
${steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

请补充：
1. 常见的错误动作
2. 如何避免受伤
3. 进阶/退阶变式
4. 呼吸技巧''';

    try {
      return await _chatCompletion(userPrompt);
    } catch (e) {
      debugPrint('ApiAgent.getExerciseTip error: $e');
      // Return the built-in steps as fallback
      if (steps.isEmpty) return '暂无动作指导数据';
      return steps
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value}')
          .join('\n');
    }
  }

  // ── Agentic tool-calling ─────────────────────────────────────────────────

  /// OpenAI function-calling tool schemas. The LLM decides when to call these;
  /// results are fed back so the model can ground its answer in real data.
  static const List<Map<String, dynamic>> _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'search_exercises',
        'description': '按自然语言（支持中文，如"绳索练背"）检索练习动作库，返回最相关的动作。回答"推荐动作/练某部位"时使用。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '检索关键词，如"哑铃 肩" "俯卧撑"'},
            'limit': {'type': 'integer', 'description': '返回数量，默认 10'},
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_exercise_detail',
        'description':
            '按练习 ID 获取详细步骤说明。回答"某动作怎么做/技巧"时，先用 search_exercises 找到 ID 再调用它。',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'description': '练习 ID，如 "0001"'},
          },
          'required': ['id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_workout_history',
        'description':
            '获取用户最近的训练记录（训练量/动作/组数）。回答与"我的进度/最近练得怎样/该练什么"相关的个性化问题时使用。',
        'parameters': {
          'type': 'object',
          'properties': {
            'days': {'type': 'integer', 'description': '回溯天数，默认 30'},
          },
        },
      },
    },
  ];

  // ── API call ───────────────────────────────────────────────────────────

  /// Send a chat completion request and return the response text.
  Future<String> _chatCompletion(String userMessage) async {
    final allExercises = ExerciseService.all;

    final body = jsonEncode({
      'model': config.model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt(allExercises)},
        {'role': 'user', 'content': userMessage},
      ],
      'temperature': 0.7,
      'max_tokens': 1500,
    });

    final uri = Uri.parse(config.endpoint);
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('API 请求失败 (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('API 返回空结果');
    }

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('API 返回空内容');
    }

    return content;
  }

  /// Run a tool-calling loop: send [messages] with [_tools], execute any tool
  /// calls the model requests, feed results back, and repeat until the model
  /// returns a plain answer. Returns the final text plus every exercise ID that
  /// surfaced through tool calls (for rendering cards).
  Future<(String, Set<String>)> _agenticChat(
    List<Map<String, dynamic>> messages,
  ) async {
    final collectedIds = <String>{};
    const maxRounds = 5;

    for (var round = 0; round < maxRounds; round++) {
      final msg = await _postChat(messages, withTools: true);
      final toolCalls = msg['tool_calls'] as List?;

      if (toolCalls == null || toolCalls.isEmpty) {
        final content = msg['content'] as String? ?? '';
        return (content, collectedIds);
      }

      // Record the assistant turn that requested the tools, then answer each.
      messages.add(msg);
      for (final call in toolCalls) {
        final fn = (call as Map)['function'] as Map<String, dynamic>?;
        final name = fn?['name'] as String? ?? '';
        Map<String, dynamic> args = {};
        try {
          args =
              jsonDecode(fn?['arguments'] as String? ?? '{}')
                  as Map<String, dynamic>;
        } catch (_) {}
        final result = await _executeTool(name, args, collectedIds);
        messages.add({
          'role': 'tool',
          'tool_call_id': call['id'],
          'content': result,
        });
      }
    }

    // Hit the round cap — ask once more without tools for a final answer.
    final msg = await _postChat(messages, withTools: false);
    return (msg['content'] as String? ?? '（AI 未能给出回答）', collectedIds);
  }

  /// POST [messages] and return the assistant message object (which may carry
  /// tool_calls). Shared by the agentic loop.
  Future<Map<String, dynamic>> _postChat(
    List<Map<String, dynamic>> messages, {
    required bool withTools,
  }) async {
    assert(_tools.isNotEmpty);
    final body = jsonEncode({
      'model': config.model,
      'messages': messages,
      if (withTools) 'tools': FitnessAgentTools.schemas,
      'temperature': 0.7,
      'max_tokens': 1500,
    });

    final response = await http.post(
      Uri.parse(config.endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('API 请求失败 (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) throw Exception('API 返回空结果');
    return choices[0]['message'] as Map<String, dynamic>;
  }

  /// Execute a tool call locally and return a compact string result the LLM
  /// can read. Side effect: adds any surfaced exercise IDs to [collectedIds].
  Future<String> _executeTool(
    String name,
    Map<String, dynamic> args,
    Set<String> collectedIds,
  ) async {
    final delegated = await FitnessAgentTools.execute(name, args);
    if (name != '__legacy_tool__') {
      collectedIds.addAll(delegated.relatedExerciseIds);
      return delegated.content;
    }

    switch (name) {
      case 'search_exercises':
        final query = args['query'] as String? ?? '';
        final limit = (args['limit'] as num?)?.toInt() ?? 10;
        final results = ExerciseRetriever.retrieve(query, limit: limit);
        if (results.isEmpty) return '没有找到匹配「$query」的动作。';
        for (final e in results) {
          collectedIds.add(e.id);
        }
        return results
            .map(
              (e) =>
                  '- ID:${e.id} | ${e.name} | ${ExerciseLabels.category(e.category)} | ${ExerciseLabels.equipment(e.equipment)} | 目标:${ExerciseLabels.target(e.target)}',
            )
            .join('\n');

      case 'get_exercise_detail':
        final id = args['id'] as String? ?? '';
        final e = ExerciseService.findById(id);
        if (e == null) return '未找到 ID 为 $id 的动作。';
        collectedIds.add(e.id);
        final steps = e.getSteps('zh');
        final stepStr = steps.isEmpty
            ? '（无步骤数据）'
            : steps
                  .asMap()
                  .entries
                  .map((s) => '${s.key + 1}. ${s.value}')
                  .join('\n');
        return '${e.name}\n目标肌群:${ExerciseLabels.target(e.target)} | 器材:${ExerciseLabels.equipment(e.equipment)}\n步骤:\n$stepStr';

      case 'get_workout_history':
        final days = (args['days'] as num?)?.toInt() ?? 30;
        final sessions = await DatabaseService.getSessions(limit: 20);
        final cutoff = DateTime.now().subtract(Duration(days: days));
        final recent = sessions
            .where((s) => s.startTime.isAfter(cutoff))
            .toList();
        if (recent.isEmpty) return '过去 $days 天没有训练记录。';
        final sb = StringBuffer('过去 $days 天共 ${recent.length} 次训练：\n');
        for (final s in recent) {
          sb.writeln(
            '- ${s.startTime.toString().substring(0, 10)}：${s.logs.length} 个动作，总容量 ${s.totalVolume.toStringAsFixed(0)}kg',
          );
        }
        return sb.toString().trim();

      default:
        return '未知工具：$name';
    }
  }

  /// Attempt to parse a JSON plan from an LLM response.
  AgentPlanResult _parsePlanResult(
    String jsonStr,
    String goalLabel,
    String expLabel,
  ) {
    // Try to extract JSON from markdown code blocks
    final codeBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
    ).firstMatch(jsonStr);
    final cleanJson = codeBlockMatch?.group(1) ?? jsonStr;

    try {
      final map = jsonDecode(cleanJson) as Map<String, dynamic>;
      final title = map['title'] as String? ?? '$goalLabel · 训练计划';
      final description = map['description'] as String? ?? '';
      final daysList = map['days'] as List? ?? [];

      final days = daysList.map((d) {
        final dayMap = d as Map<String, dynamic>;
        final exercises = (dayMap['exercises'] as List? ?? []).map((e) {
          final em = e as Map<String, dynamic>;
          return PlannedExercise(
            exerciseId: em['exerciseId'] as String? ?? '',
            exerciseName: em['exerciseName'] as String? ?? '',
            sets: em['sets'] as int? ?? 3,
            minReps: em['minReps'] as int? ?? 8,
            maxReps: em['maxReps'] as int? ?? 12,
            restSeconds: em['restSeconds'] as String?,
            note: em['note'] as String?,
          );
        }).toList();

        return WorkoutPlanDay(
          dayName: dayMap['dayName'] as String? ?? '',
          exercises: exercises,
        );
      }).toList();

      return AgentPlanResult(
        title: title,
        description: description,
        days: days,
      );
    } catch (e) {
      debugPrint('ApiAgent._parsePlanResult: failed to parse JSON: $e');
      return AgentPlanResult(
        title: '$goalLabel · 训练计划',
        description: jsonStr.length > 200 ? jsonStr.substring(0, 200) : jsonStr,
        days: [],
      );
    }
  }

  String _goalLabel(String goal) {
    switch (goal) {
      case 'strength':
        return '力量';
      case 'hypertrophy':
        return '增肌';
      case 'endurance':
        return '耐力';
      case 'fat_loss':
        return '减脂';
      default:
        return '综合';
    }
  }

  String _expLabel(String exp) {
    switch (exp) {
      case 'beginner':
        return '新手';
      case 'intermediate':
        return '中级';
      case 'advanced':
        return '高级';
      default:
        return '中级';
    }
  }

  String _planDescription(String goal, int days, String exp) {
    final goalLabel = _goalLabel(goal);
    final expLabel = _expLabel(exp);
    return 'AI 生成的 $goalLabel 训练计划（$expLabel · 每周 $days 天）';
  }
}
