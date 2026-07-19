class WorkoutPlan {
  final int? id;
  final String name;
  final String? description;
  final List<String> exerciseIds; // ordered list of exercise IDs
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isNew => id == null;

  WorkoutPlan({
    this.id,
    required this.name,
    this.description,
    required this.exerciseIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description ?? '',
    'exercise_ids': exerciseIds.join(','),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory WorkoutPlan.fromMap(Map<String, dynamic> map) => WorkoutPlan(
    id: map['id'] as int?,
    name: map['name'] as String? ?? '',
    description: map['description'] as String?,
    exerciseIds:
        (map['exercise_ids'] as String?)
            ?.split(',')
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList() ??
        [],
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
  );

  WorkoutPlan copyWith({
    int? id,
    String? name,
    String? description,
    List<String>? exerciseIds,
  }) => WorkoutPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    exerciseIds: exerciseIds ?? List.from(this.exerciseIds),
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
