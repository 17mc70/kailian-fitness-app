import '../utils/exercise_labels.dart';

class Exercise {
  final String id;
  final String name;
  final String category;
  final String bodyPart;
  final String equipment;
  final String muscleGroup;
  final List<String> secondaryMuscles;
  final String target;
  final String image;
  final String gifUrl;
  final String mediaId;
  final Map<String, String> instructions;
  final Map<String, List<String>> instructionSteps;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.bodyPart,
    required this.equipment,
    required this.muscleGroup,
    required this.secondaryMuscles,
    required this.target,
    required this.image,
    required this.gifUrl,
    required this.mediaId,
    required this.instructions,
    required this.instructionSteps,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    // Parse instruction_steps - could be list or dict
    Map<String, List<String>> steps = {};
    if (json['instruction_steps'] is Map) {
      final rawSteps = json['instruction_steps'] as Map<String, dynamic>;
      for (final lang in rawSteps.keys) {
        final list = rawSteps[lang];
        if (list is List) {
          steps[lang] = list.map((e) => e.toString()).toList();
        }
      }
    }

    // Parse instructions - could be nested dict
    Map<String, String> instr = {};
    if (json['instructions'] is Map) {
      final rawInstr = json['instructions'] as Map;
      for (final lang in rawInstr.keys) {
        instr[lang.toString()] = rawInstr[lang]?.toString() ?? '';
      }
    }

    return Exercise(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      bodyPart: json['body_part']?.toString() ?? json['bodyPart']?.toString() ?? '',
      equipment: json['equipment']?.toString() ?? '',
      muscleGroup: json['muscle_group']?.toString() ?? json['muscleGroup']?.toString() ?? '',
      secondaryMuscles: json['secondary_muscles'] is List
              ? (json['secondary_muscles'] as List)
                  .map((e) => e.toString())
                  .toList()
              : [],
      target: json['target']?.toString() ?? '',
      image: _assetPath(json['image']?.toString() ?? ''),
      gifUrl: _assetPath(json['gif_url']?.toString() ?? json['gifUrl']?.toString() ?? ''),
      mediaId: json['media_id']?.toString() ?? json['mediaId']?.toString() ?? '',
      instructions: instr,
      instructionSteps: steps,
    );
  }

  /// Get instruction content in Chinese, falling back to English
  String getInstruction(String lang) {
    if (instructions.containsKey(lang)) return instructions[lang]!;
    if (instructions.containsKey('zh')) return instructions['zh']!;
    return instructions['en'] ?? '';
  }

  /// Get instruction steps in Chinese, falling back to English
  List<String> getSteps(String lang) {
    if (instructionSteps.containsKey(lang)) return instructionSteps[lang]!;
    if (instructionSteps.containsKey('zh')) return instructionSteps['zh']!;
    return instructionSteps['en'] ?? [];
  }

  /// Ensure path has correct assets/ prefix for Flutter
  static String _assetPath(String path) {
    if (path.startsWith('assets/')) return path;
    return 'assets/$path';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'body_part': bodyPart,
        'equipment': equipment,
        'muscle_group': muscleGroup,
        'secondary_muscles': secondaryMuscles,
        'target': target,
        'image': image,
        'gif_url': gifUrl,
        'media_id': mediaId,
        'instructions': instructions,
        'instruction_steps': instructionSteps,
      };

  static List<String> get categories => [
        '全部',
        '背部',
        '有氧',
        '胸部',
        '前臂',
        '小腿',
        '颈部',
        '肩部',
        '上臂',
        '大腿',
        '腰部',
      ];

  static String categoryLabel(String en) => ExerciseLabels.category(en);
  static String equipmentLabel(String en) => ExerciseLabels.equipment(en);
}
