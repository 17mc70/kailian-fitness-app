import '../models/exercise.dart';
import '../models/workout_session.dart';

/// Unified interface for all Fitness Agent backends.
///
/// Every backend (rule engine, API, local LLM) implements this same contract
/// so the UI layer never needs to know which backend is active.
abstract class FitnessAgent {
  String get name;
  String get description;
  bool get isAvailable;

  /// Generate a structured workout plan.
  Future<AgentPlanResult> generatePlan(PlanRequest request);

  /// Analyze past workout sessions and return insights.
  Future<AgentAnalysis> analyzeProgress(List<WorkoutSession> sessions);

  /// Answer a free-form natural language query.
  ///
  /// [history] carries prior conversation turns for multi-turn context.
  /// Backends that don't support it (rule engine) simply ignore it.
  Future<AgentAnswer> answerQuery(
    String query, {
    List<Exercise>? contextExercises,
    List<ChatTurn>? history,
  });

  /// Get detailed tips / form guidance for a specific exercise.
  Future<String> getExerciseTip(Exercise exercise);
}

// ── Request / Result types ────────────────────────────────────────────────

class PlanRequest {
  final String goal; // strength | hypertrophy | endurance | fat_loss
  final List<String> availableEquipment; // e.g. ['barbell', 'dumbbell']
  final String experienceLevel; // beginner | intermediate | advanced
  final int daysPerWeek;
  final List<String>? focusMuscles; // optional muscle group focus

  const PlanRequest({
    required this.goal,
    required this.availableEquipment,
    required this.experienceLevel,
    required this.daysPerWeek,
    this.focusMuscles,
  });
}

class AgentPlanResult {
  final String title;
  final String description;
  final List<WorkoutPlanDay> days;
  final String? explanation;

  const AgentPlanResult({
    required this.title,
    required this.description,
    required this.days,
    this.explanation,
  });
}

class WorkoutPlanDay {
  final String dayName; // e.g. "Day 1 — 胸部 + 三头"
  final List<PlannedExercise> exercises;

  const WorkoutPlanDay({required this.dayName, required this.exercises});
}

class PlannedExercise {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int minReps;
  final int maxReps;
  final String? restSeconds; // e.g. "60-90s"
  final String? note; // e.g. "Focus on the stretch at the bottom"

  const PlannedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    this.restSeconds,
    this.note,
  });
}

class AgentAnalysis {
  final List<String> insights; // e.g. "Your bench press volume increased 15%"
  final List<String> suggestions; // e.g. "Consider adding a deload week"
  final String? plateauWarning;
  final Map<String, double>? muscleBalance;

  const AgentAnalysis({
    this.insights = const [],
    this.suggestions = const [],
    this.plateauWarning,
    this.muscleBalance,
  });
}

class AgentAnswer {
  final String answer;
  final bool usedApi; // true if backed by an LLM call
  final List<String>? relatedExerciseIds;
  final List<AgentAction> actions;

  const AgentAnswer({
    required this.answer,
    this.usedApi = false,
    this.relatedExerciseIds,
    this.actions = const [],
  });
}

enum AgentActionKind {
  openExercise,
  openPlans,
  openProgress,
  startQuickWorkout,
  createPlan,
}

/// A safe, user-triggered action suggested by the Agent.
class AgentAction {
  final AgentActionKind kind;
  final String label;
  final String? exerciseId;

  const AgentAction({required this.kind, required this.label, this.exerciseId});
}

List<AgentAction> suggestAgentActions(String query) {
  final q = query.toLowerCase();
  if (q.contains('计划') || q.contains('推荐') || q.contains('今天练')) {
    return const [
      AgentAction(kind: AgentActionKind.createPlan, label: '生成训练计划'),
    ];
  }
  if (q.contains('进度') || q.contains('分析') || q.contains('表现')) {
    return const [
      AgentAction(kind: AgentActionKind.openProgress, label: '查看训练进度'),
    ];
  }
  if (q.contains('开始') || q.contains('开练')) {
    return const [
      AgentAction(kind: AgentActionKind.startQuickWorkout, label: '开始自由训练'),
    ];
  }
  return const [];
}

/// A single prior turn in a conversation, used to give the LLM multi-turn
/// context. [role] is 'user' or 'assistant'.
class ChatTurn {
  final String role;
  final String content;

  const ChatTurn({required this.role, required this.content});
}

/// Configuration for the API agent backend.
class ApiAgentConfig {
  final String endpoint;
  final String apiKey;
  final String model;
  final bool enabled;

  const ApiAgentConfig({
    this.endpoint = 'https://api.deepseek.com/chat/completions',
    this.apiKey = '',
    this.model = 'deepseek-v4-flash',
    this.enabled = false,
  });

  ApiAgentConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? model,
    bool? enabled,
  }) => ApiAgentConfig(
    endpoint: endpoint ?? this.endpoint,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'apiKey': apiKey,
    'model': model,
    'enabled': enabled,
  };

  static const _defaultEndpoint = 'https://api.deepseek.com/chat/completions';
  static const _defaultModel = 'deepseek-v4-flash';

  factory ApiAgentConfig.fromJson(Map<String, dynamic> json) => ApiAgentConfig(
    endpoint: json['endpoint'] as String? ?? _defaultEndpoint,
    apiKey: json['apiKey'] as String? ?? '',
    model: json['model'] as String? ?? _defaultModel,
    enabled: json['enabled'] as bool? ?? false,
  );
}
