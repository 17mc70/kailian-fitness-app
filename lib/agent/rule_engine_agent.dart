import 'dart:math';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../services/exercise_service.dart';
import '../services/exercise_retriever.dart';
import '../utils/exercise_labels.dart';
import 'fitness_agent.dart';

/// Pure-Dart rule engine that uses exercise metadata to provide intelligent
/// fitness recommendations — zero external dependencies, always available.
class RuleEngineAgent implements FitnessAgent {
  final Random _random = Random();

  @override
  String get name => '开练教练';

  @override
  String get description => '基于 1324 个练习数据的规则引擎，离线可用';

  @override
  bool get isAvailable => true;

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

    final equipment = request.availableEquipment;
    final goal = request.goal;
    final expLevel = request.experienceLevel;
    final focusMuscles = request.focusMuscles;

    // Determine rep ranges based on goal
    final (int baseSets, int minReps, int maxReps) = _repRange(goal, expLevel);

    // Determine split from days per week
    final days = _buildSplitDays(
      daysPerWeek: request.daysPerWeek,
      allExercises: allExercises,
      equipment: equipment,
      goal: goal,
      baseSets: baseSets,
      minReps: minReps,
      maxReps: maxReps,
      focusMuscles: focusMuscles,
    );

    final goalLabel = _goalLabel(goal);
    final expLabel = _expLabel(expLevel);

    return AgentPlanResult(
      title: '$goalLabel · ${request.daysPerWeek}天/周 ($expLabel)',
      description: _planDescription(goal, request.daysPerWeek, expLevel),
      days: days,
    );
  }

  @override
  Future<AgentAnalysis> analyzeProgress(List<WorkoutSession> sessions) async {
    if (sessions.isEmpty) {
      return const AgentAnalysis(
        insights: ['还没有训练记录，开始你的第一次训练吧！'],
        suggestions: ['尝试使用「AI 推荐计划」生成一份训练计划'],
      );
    }

    final insights = <String>[];
    final suggestions = <String>[];
    final muscleVolumes = <String, List<double>>{};
    final exerciseProgress = <String, List<double>>{};

    // Analyze recent sessions (last 30 days)
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recentSessions = sessions
        .where((s) => s.startTime.isAfter(cutoff))
        .toList();

    if (recentSessions.isEmpty) {
      insights.add('过去30天没有训练记录，该活动活动了！');
    } else {
      insights.add('过去30天完成了 ${recentSessions.length} 次训练');

      // Total volume
      final totalVol = recentSessions.fold(
        0.0,
        (sum, s) => sum + s.totalVolume,
      );
      insights.add('总训练量 ${totalVol.toStringAsFixed(0)} kg');

      // Per-exercise volume tracking
      for (final session in recentSessions) {
        for (final log in session.logs) {
          for (final set in log.sets) {
            if (set.isCompleted && set.weight > 0) {
              final volume = set.reps * set.weight;
              muscleVolumes.putIfAbsent(log.exerciseName, () => []).add(volume);

              exerciseProgress
                  .putIfAbsent(log.exerciseName, () => [])
                  .add(set.estimatedOneRM);
            }
          }
        }
      }

      // Plateau detection
      for (final entry in exerciseProgress.entries) {
        if (entry.value.length >= 3) {
          final recent = entry.value.sublist(entry.value.length - 3);
          // If no improvement in last 3 instances
          final max1 = recent[0];
          final max2 = recent[recent.length - 1];
          if (max1 > 0 && max2 > 0 && (max2 - max1).abs() / max1 < 0.02) {
            suggestions.add('${entry.key} 似乎遇到了平台期，建议尝试 deload 或换变式');
          }
        }
      }
    }

    return AgentAnalysis(insights: insights, suggestions: suggestions);
  }

  @override
  Future<AgentAnswer> answerQuery(
    String query, {
    List<Exercise>? contextExercises,
    List<ChatTurn>? history, // rule engine is stateless; ignored
  }) async {
    final allExercises = contextExercises ?? ExerciseService.all;
    if (allExercises.isEmpty) {
      return const AgentAnswer(answer: '还没有加载练习数据，请稍后再试');
    }

    final q = query.toLowerCase();

    // Chinese keyword → English category mapping
    const catMap = {
      '胸': 'chest',
      '背': 'back',
      '肩': 'shoulders',
      '腿': 'upper legs',
      '大腿': 'upper legs',
      '小腿': 'lower legs',
      '手臂': 'upper arms',
      '胳膊': 'upper arms',
      '前臂': 'lower arms',
      '腰': 'waist',
      '腹': 'waist',
      '核心': 'waist',
      '有氧': 'cardio',
      '颈部': 'neck',
    };

    const eqMap = {
      '自重': 'body weight',
      '哑铃': 'dumbbell',
      '杠铃': 'barbell',
      '壶铃': 'kettlebell',
      '弹力带': 'band',
      '绳索': 'cable',
      '药球': 'medicine ball',
    };

    // Detect intent
    String? targetCat;
    for (final entry in catMap.entries) {
      if (q.contains(entry.key)) {
        targetCat = entry.value;
        break;
      }
    }

    String? targetEq;
    for (final entry in eqMap.entries) {
      if (q.contains(entry.key)) {
        targetEq = entry.value;
        break;
      }
    }

    // Check for "推荐" / "计划" / "训练" → plan generation intent
    if (q.contains('推荐') || q.contains('计划') || q.contains('今天练')) {
      return AgentAnswer(
        answer:
            '我可以为你生成一份训练计划！请告诉我：\n'
            '1️⃣ 训练目标（增肌/减脂/力量/耐力）\n'
            '2️⃣ 每周训练天数\n'
            '3️⃣ 你有哪些器材\n'
            '4️⃣ 你的经验水平（新手/中级/高级）',
        usedApi: false,
        actions: suggestAgentActions(query),
      );
    }

    // Check for progress / analysis intent
    if (q.contains('进度') || q.contains('分析') || q.contains('表现')) {
      return AgentAnswer(
        answer:
            '想看看你的训练进度？前往「进度」页面可以查看：\n'
            '📊 训练量趋势\n'
            '💪 力量增长\n'
            '📅 训练频率\n'
            '也可以让我分析最近的数据，告诉我「分析我的训练」',
        usedApi: false,
        actions: suggestAgentActions(query),
      );
    }

    // Filter exercises by detected criteria
    var matches = allExercises;
    if (targetCat != null) {
      matches = matches.where((e) => e.category == targetCat).toList();
    }
    if (targetEq != null) {
      matches = matches.where((e) => e.equipment == targetEq).toList();
    }

    // If no Chinese keywords matched, use scored retrieval (handles mixed
    // Chinese/English queries better than plain substring search).
    if (targetCat == null && targetEq == null) {
      matches = ExerciseRetriever.retrieve(query, limit: 20);
    }

    if (matches.isEmpty) {
      return AgentAnswer(
        answer: '没有找到匹配「$query」的练习，试试其他关键词？',
        usedApi: false,
        actions: suggestAgentActions(query),
      );
    }

    // Show top matches
    final topMatches = matches.take(5).toList();
    final names = topMatches
        .map(
          (e) =>
              '• ${e.name} — ${ExerciseLabels.category(e.category)} | ${ExerciseLabels.equipment(e.equipment)}',
        )
        .join('\n');

    final catLabel = targetCat != null
        ? ExerciseLabels.category(targetCat)
        : '';
    final eqLabel = targetEq != null ? ExerciseLabels.equipment(targetEq) : '';
    final filters = [
      if (catLabel.isNotEmpty) catLabel,
      if (eqLabel.isNotEmpty) eqLabel,
    ].join(' + ');

    return AgentAnswer(
      answer:
          '找到 ${matches.length} 个${filters.isNotEmpty ? ' $filters' : ''}练习：\n$names',
      usedApi: false,
      relatedExerciseIds: matches.map((e) => e.id).take(10).toList(),
      actions: suggestAgentActions(query),
    );
  }

  @override
  Future<String> getExerciseTip(Exercise exercise) async {
    final steps = exercise.getSteps('zh');
    final target = ExerciseLabels.target(exercise.target);
    final muscleGroup = ExerciseLabels.muscleGroup(exercise.muscleGroup);
    final equipment = ExerciseLabels.equipment(exercise.equipment);

    final buffer = StringBuffer();
    buffer.writeln('🎯 **${exercise.name}**');
    buffer.writeln('  目标肌群：$target');
    buffer.writeln('  辅助肌群：$muscleGroup');
    buffer.writeln('  器材：$equipment');
    buffer.writeln('');

    if (steps.isNotEmpty) {
      buffer.writeln('📋 **步骤说明**：');
      for (var i = 0; i < steps.length; i++) {
        buffer.writeln('  ${i + 1}. ${steps[i]}');
      }
    }

    // Common form tips based on exercise type
    final tips = _commonTips(exercise);
    if (tips.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('💡 **小贴士**：');
      for (final tip in tips) {
        buffer.writeln('  ✅ $tip');
      }
    }

    return buffer.toString().trim();
  }

  // ── Private helpers ────────────────────────────────────────────────────

  (int, int, int) _repRange(String goal, String expLevel) {
    switch (goal) {
      case 'strength':
        return expLevel == 'beginner' ? (3, 5, 8) : (4, 3, 6);
      case 'hypertrophy':
        return (3, 8, 12);
      case 'endurance':
        return (2, 15, 20);
      case 'fat_loss':
        return (3, 12, 15);
      default:
        return (3, 8, 12); // hypertrophy default
    }
  }

  List<WorkoutPlanDay> _buildSplitDays({
    required int daysPerWeek,
    required List<Exercise> allExercises,
    required List<String> equipment,
    required String goal,
    required int baseSets,
    required int minReps,
    required int maxReps,
    List<String>? focusMuscles,
  }) {
    if (daysPerWeek <= 0) daysPerWeek = 3;

    // Pick split pattern
    final splits = _selectSplit(daysPerWeek, goal);
    final days = <WorkoutPlanDay>[];

    for (var i = 0; i < splits.length && i < daysPerWeek; i++) {
      final split = splits[i];
      final exercises = _pickExercises(
        allExercises: allExercises,
        targetMuscles: split.muscles,
        equipment: equipment,
        count: split.exerciseCount,
        focusMuscles: focusMuscles,
      );

      if (exercises.isNotEmpty) {
        days.add(
          WorkoutPlanDay(
            dayName: '第${i + 1}天 — ${split.name}',
            exercises: exercises
                .map(
                  (e) => PlannedExercise(
                    exerciseId: e.id,
                    exerciseName: e.name,
                    sets: baseSets,
                    minReps: minReps,
                    maxReps: maxReps,
                    restSeconds: _restTime(goal),
                  ),
                )
                .toList(),
          ),
        );
      }
    }

    return days;
  }

  List<_SplitDef> _selectSplit(int daysPerWeek, String goal) {
    // Define standard splits
    const fullBody = _SplitDef('全身训练', [
      'chest',
      'back',
      'upper legs',
      'shoulders',
    ], 6);
    const push = _SplitDef('推力（胸+肩+三头）', [
      'chest',
      'shoulders',
      'upper arms',
    ], 5);
    const pull = _SplitDef('拉力（背+二头）', ['back', 'upper arms'], 5);
    const legs = _SplitDef('腿部', ['upper legs', 'lower legs'], 5);
    const upper = _SplitDef('上肢', [
      'chest',
      'back',
      'shoulders',
      'upper arms',
      'lower arms',
    ], 6);
    const lower = _SplitDef('下肢', ['upper legs', 'lower legs', 'waist'], 5);
    const chestTri = _SplitDef('胸+三头', ['chest', 'upper arms'], 5);
    const backBi = _SplitDef('背+二头', ['back', 'upper arms'], 5);

    const shoulderArms = _SplitDef('肩+手臂', [
      'shoulders',
      'upper arms',
      'lower arms',
    ], 5);

    switch (daysPerWeek) {
      case 1:
        return [fullBody];
      case 2:
        return [upper, lower];
      case 3:
        return [push, pull, legs];
      case 4:
        return [upper, lower, upper, lower];
      case 5:
        return [chestTri, backBi, legs, push, pull];
      case 6:
        return [
          chestTri,
          backBi,
          legs,
          push,
          pull,
          const _SplitDef('肩+手臂', ['shoulders', 'upper arms', 'lower arms'], 5),
        ];
      case 7:
        return [fullBody, push, pull, legs, upper, lower, shoulderArms];
      default:
        return [fullBody];
    }
  }

  List<Exercise> _pickExercises({
    required List<Exercise> allExercises,
    required List<String> targetMuscles,
    required List<String> equipment,
    required int count,
    List<String>? focusMuscles,
  }) {
    // Filter by equipment availability
    var candidates = allExercises.where((e) {
      if (equipment.isEmpty) return true; // no filter
      return equipment.any(
        (eq) => e.equipment.toLowerCase() == eq.toLowerCase(),
      );
    }).toList();

    if (candidates.isEmpty) {
      // Fallback: use all exercises
      candidates = allExercises;
    }

    // Filter by target muscle categories
    var selected = <Exercise>[];
    final categorySet = targetMuscles.map((m) => m.toLowerCase()).toSet();

    // Prioritize compound exercises first (those with broader muscle groups)
    final compoundExercises = _prioritizeFocus(
      candidates
          .where(
            (e) =>
                categorySet.contains(e.category.toLowerCase()) &&
                _isCompound(e),
          )
          .toList(),
      focusMuscles,
    );

    // Then isolation exercises
    final isolationExercises = _prioritizeFocus(
      candidates
          .where(
            (e) =>
                categorySet.contains(e.category.toLowerCase()) &&
                !_isCompound(e),
          )
          .toList(),
      focusMuscles,
    );

    // Pick up to `count` exercises, preferring compound
    selected.addAll(compoundExercises.take((count * 0.6).ceil()));
    selected.addAll(isolationExercises.take(count - selected.length));

    // Ensure variety: no duplicate exercises
    final seen = <String>{};
    selected.retainWhere((e) => seen.add(e.id));

    // If still not enough, add any remaining from candidates
    if (selected.length < count) {
      final remaining = candidates
          .where(
            (e) =>
                !seen.contains(e.id) &&
                categorySet.contains(e.category.toLowerCase()),
          )
          .toList();
      remaining.shuffle(_random);
      selected.addAll(remaining.take(count - selected.length));
    }

    return selected;
  }

  List<Exercise> _prioritizeFocus(
    List<Exercise> exercises,
    List<String>? focusMuscles,
  ) {
    final focus =
        focusMuscles
            ?.map((muscle) => muscle.toLowerCase())
            .where((muscle) => muscle.isNotEmpty)
            .toSet() ??
        const <String>{};
    if (focus.isEmpty) {
      exercises.shuffle(_random);
      return exercises;
    }

    bool matches(Exercise exercise) =>
        focus.contains(exercise.category.toLowerCase()) ||
        focus.contains(exercise.target.toLowerCase()) ||
        focus.contains(exercise.muscleGroup.toLowerCase());

    final focused = exercises.where(matches).toList()..shuffle(_random);
    final remaining = exercises.where((exercise) => !matches(exercise)).toList()
      ..shuffle(_random);
    return [...focused, ...remaining];
  }

  /// Heuristic: exercises targeting larger/primary muscle groups are "compound"
  bool _isCompound(Exercise e) {
    const compoundTargets = {
      'chest',
      'back',
      'shoulders',
      'upper legs',
      'quadriceps',
      'hamstrings',
      'glutes',
      'lats',
    };
    return compoundTargets.contains(e.target.toLowerCase()) ||
        compoundTargets.contains(e.category.toLowerCase());
  }

  String _restTime(String goal) {
    switch (goal) {
      case 'strength':
        return '2-3 min';
      case 'hypertrophy':
        return '60-90s';
      case 'endurance':
        return '30-45s';
      case 'fat_loss':
        return '30-60s';
      default:
        return '60-90s';
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
    return '为你定制的 $goalLabel 训练计划（$expLabel · 每周 $days 天）。'
        '复合动作在前，孤立动作在后，确保训练效率。';
  }

  List<String> _commonTips(Exercise exercise) {
    final tips = <String>[];
    final cat = exercise.category.toLowerCase();
    final name = exercise.name.toLowerCase();

    // Push exercises
    if (cat == 'chest' ||
        name.contains('push') ||
        name.contains('press') ||
        name.contains('俯卧撑') ||
        name.contains('卧推')) {
      tips.add('保持核心收紧，肩胛骨下沉后收');
      tips.add('下落时手肘与身体呈 45-75°，避免过度外展');
      tips.add('在底部停顿 1 秒，充分拉伸胸肌');
    }

    // Pull exercises
    if (cat == 'back' ||
        name.contains('row') ||
        name.contains('拉') ||
        name.contains('引体')) {
      tips.add('启动时先沉肩，用背部发力而不是手臂');
      tips.add('想象手肘在向后下方拉，而不是向上');
      tips.add('顶峰收缩 1 秒，感受背肌挤压');
    }

    // Leg exercises
    if (cat == 'upper legs' ||
        name.contains('squat') ||
        name.contains('蹲') ||
        name.contains('lunge') ||
        name.contains('弓步')) {
      tips.add('膝盖方向与脚尖一致，不要内扣');
      tips.add('保持胸部挺起，核心全程收紧');
      tips.add('下蹲时吸气，起身时呼气');
    }

    // Deadlift
    if (name.contains('deadlift') || name.contains('硬拉')) {
      tips.add('杠铃紧贴小腿，背部保持挺直');
      tips.add('用髋部发力站起来，而不是下背部');
      tips.add('每次放下时控制节奏，不要砸地');
    }

    // Core
    if (cat == 'waist' ||
        name.contains('crunch') ||
        name.contains('卷腹') ||
        name.contains('plank') ||
        name.contains('平板')) {
      tips.add('不要用脖子发力，想象下巴夹一个鸡蛋');
      tips.add('动作放慢，感受腹肌的持续张力');
      tips.add('吐气时收缩腹部，吸气时保持张力');
    }

    // Shoulders
    if (cat == 'shoulders' ||
        name.contains('press') ||
        name.contains('推举') ||
        name.contains('fly') ||
        name.contains('飞鸟')) {
      tips.add('避免耸肩，保持肩胛骨下沉');
      tips.add('重量不要过大，优先保证动作质量');
      tips.add('在顶部不要锁定手肘，保持肌肉张力');
    }

    return tips;
  }
}

/// Internal split definition.
class _SplitDef {
  final String name;
  final List<String> muscles;
  final int exerciseCount;

  const _SplitDef(this.name, this.muscles, this.exerciseCount);
}
