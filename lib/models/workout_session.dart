import 'dart:convert';
import 'package:flutter/foundation.dart';

class ExerciseSet {
  final int setNumber;
  final int reps;
  final double weight;
  final bool isCompleted;

  const ExerciseSet({
    required this.setNumber,
    this.reps = 0,
    this.weight = 0,
    this.isCompleted = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseSet &&
          runtimeType == other.runtimeType &&
          setNumber == other.setNumber &&
          reps == other.reps &&
          weight == other.weight &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode =>
      Object.hash(setNumber, reps, weight, isCompleted);

  /// Estimated 1RM using Epley formula: weight × (1 + reps/30)
  /// Returns 0 if weight or reps is 0.
  double get estimatedOneRM {
    if (weight <= 0 || reps <= 0) return 0;
    return weight * (1 + reps / 30);
  }

  ExerciseSet copyWith({
    int? setNumber,
    int? reps,
    double? weight,
    bool? isCompleted,
  }) =>
      ExerciseSet(
        setNumber: setNumber ?? this.setNumber,
        reps: reps ?? this.reps,
        weight: weight ?? this.weight,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  Map<String, dynamic> toMap() => {
        'set_number': setNumber,
        'reps': reps,
        'weight': weight,
        'is_completed': isCompleted ? 1 : 0,
      };

  factory ExerciseSet.fromMap(Map<String, dynamic> map) => ExerciseSet(
        setNumber: map['set_number'] as int? ?? 1,
        reps: map['reps'] as int? ?? 0,
        weight: (map['weight'] as num?)?.toDouble() ?? 0,
        isCompleted: (map['is_completed'] as int?) == 1,
      );
}

class ExerciseLogEntry {
  final int? id;
  final int sessionId;
  final String exerciseId;
  final String exerciseName;
  final List<ExerciseSet> sets;
  final String? notes;

  bool get isNew => id == null;

  ExerciseLogEntry({
    this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.notes,
  });

  ExerciseLogEntry copyWith({
    int? id,
    int? sessionId,
    String? exerciseId,
    String? exerciseName,
    List<ExerciseSet>? sets,
    String? notes,
  }) =>
      ExerciseLogEntry(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        exerciseId: exerciseId ?? this.exerciseId,
        exerciseName: exerciseName ?? this.exerciseName,
        sets: sets ?? this.sets,
        notes: notes ?? this.notes,
      );

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);
  double get totalVolume =>
      sets.fold(0.0, (sum, s) => sum + (s.reps * s.weight));

  /// Best estimated 1RM across all sets in this exercise.
  double get maxOneRM {
    if (sets.isEmpty) return 0;
    return sets
        .map((s) => s.estimatedOneRM)
        .fold(0.0, (a, b) => a > b ? a : b);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'sets_data':
            jsonEncode(sets.map((s) => s.toMap()).toList()),
        'notes': notes ?? '',
      };

  factory ExerciseLogEntry.fromMap(Map<String, dynamic> map) {
    List<ExerciseSet> parsedSets = [];
    try {
      final decoded = jsonDecode(map['sets_data'] as String? ?? '[]') as List;
      parsedSets = decoded
          .map((s) => ExerciseSet.fromMap(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ExerciseLogEntry.fromMap: failed to parse sets_data: $e');
    }

    return ExerciseLogEntry(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int? ?? 0,
      exerciseId: map['exercise_id'] as String? ?? '',
      exerciseName: map['exercise_name'] as String? ?? '',
      sets: parsedSets,
      notes: map['notes'] as String?,
    );
  }
}

class WorkoutSession {
  final int? id;
  final int? planId;
  final String? planName;
  final DateTime startTime;
  final DateTime? endTime;
  final String? notes;
  final List<ExerciseLogEntry> logs;

  bool get isNew => id == null;

  WorkoutSession({
    this.id,
    this.planId,
    this.planName,
    required this.startTime,
    this.endTime,
    this.notes,
    this.logs = const [],
  });

  Duration get duration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }

  int get totalSets =>
      logs.fold(0, (sum, log) => sum + log.sets.where((s) => s.isCompleted).length);

  double get totalVolume =>
      logs.fold(0.0, (sum, log) => sum + log.totalVolume);

  Map<String, dynamic> toMap() => {
        'id': id,
        'plan_id': planId,
        'plan_name': planName ?? '',
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'notes': notes ?? '',
      };

  factory WorkoutSession.fromMap(Map<String, dynamic> map) => WorkoutSession(
        id: map['id'] as int?,
        planId: map['plan_id'] as int?,
        planName: map['plan_name'] as String?,
        startTime:
            DateTime.tryParse(map['start_time'] as String? ?? '') ?? DateTime.now(),
        endTime: map['end_time'] != null
            ? DateTime.tryParse(map['end_time'] as String)
            : null,
        notes: map['notes'] as String?,
      );
}
